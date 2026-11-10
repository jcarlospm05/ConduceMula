import 'dart:io';
import 'dart:typed_data';

import 'package:administrador/stage5_services.dart';
import 'package:administrador/services.dart';
import 'package:admin_data/admin_data.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_codec;
import 'package:mule_data/mule_data.dart';
import 'package:mule_profiles/mule_profiles.dart';
import 'package:muleagent/application/unified_capture_services.dart';

import 'support.dart';
import '../../../packages/admin_data/test/fixtures.dart' as fixtures;

Future<CaptureSession> sampleClosed(TestInstallation source) async {
  final capture = source.bundle.capture;
  final session = await capture.start(Stage.exit, '2026-11-09');
  await capture.addTicket(session);
  for (final value in ['000362', 'Proveedor A', '19:16', '111421.9']) {
    final draft = (await capture.draft(session))!;
    await capture.saveValue(draft, value);
    await capture.move(draft, draft.step + 1);
  }
  final original = Uint8List.fromList(
    image_codec.encodePng(image_codec.Image(width: 60, height: 18)),
  );
  const relative = 'media/foto_horometro.png';
  await source.bundle.services.writeAtomic(relative, original);
  final draft = (await capture.draft(session))!;
  await capture.attachPhoto(
    draft, relative, sha256.convert(original).toString(), 'camera',
  );
  await capture.complete(session, (await capture.draft(session))!);
  await capture.closeRevision(session);
  return session;
}

Stage5AdminServices service(TestInstallation i) =>
    Stage5AdminServices(
      i.bundle.admin, i.bundle.capture, i.bundle.services,
      access: i.bundle.profiles,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Recibe paquete .mule JPG v2, consolida y excluye sin duplicarlo',
      (tester) async {
    final result = await tester.runAsync(() async {
      final source = await TestInstallation.create(role: AppRole.administrator);
      final admin = await TestInstallation.create(role: AppRole.administrator);
      try {
        final session = await sampleClosed(source);
        final sourceServices = source.bundle.services as UnifiedCaptureServices;
        final bundle = await sourceServices.delivery.ensureBundle(session);
        final bytes = await sourceServices.file(bundle.packagePath).readAsBytes();
        final inbox = service(admin);
        final first = await inbox.importBytes(
          bytes, await sourceServices.password(),
        );
        final again = await inbox.importBytes(
          bytes, await sourceServices.password(),
        );
        final rows = await inbox.cards('2026-11-09', stage: 'exit');
        final notes = await inbox.warnings('2026-11-09');
        final pdf = await inbox.pdf('2026-11-09', 'exit');
        await inbox.setIncluded(rows.single, false);
        final excluded = (await inbox.cards('2026-11-09', stage: 'exit')).single;
        await inbox.setIncluded(excluded, true);
        final restored = (await inbox.cards('2026-11-09', stage: 'exit')).single;
        return {
          'format': first.format,
          'first': first.duplicate,
          'again': again.duplicate,
          'count': rows.length,
          'supervisor': rows.single['supervisor'],
          'includedAfterExclusion': excluded['included'],
          'includedAfterUndo': restored['included'],
          'warnings': notes,
          'pdfHeader': String.fromCharCodes(pdf.take(4)),
          'oldPdfCount': (await admin.db.query('admin_revisions')).length,
          'newCount': (await admin.db.query('admin_jpg_revisions')).length,
        };
      } finally {
        await source.close();
        await admin.close();
      }
    });
    expect(result, isNotNull);
    final data = result!;
    expect(data['format'], 'JPG');
    expect(data['first'], isFalse);
    expect(data['again'], isTrue);
    expect(data['count'], 1);
    expect(data['supervisor'], 'Julio');
    expect(data['includedAfterExclusion'], isFalse);
    expect(data['includedAfterUndo'], isTrue);
    expect(data['pdfHeader'], '%PDF');
    expect(data['oldPdfCount'], 0);
    expect(data['newCount'], 1);
    expect((data['warnings'] as List).join(' '), contains('entrada'));
  });

  testWidgets('Conserva JPG independiente en anexo y respalda/restaura todos los archivos',
      (tester) async {
    final result = await tester.runAsync(() async {
      final source = await TestInstallation.create(role: AppRole.administrator);
      final admin = await TestInstallation.create(role: AppRole.administrator);
      final restored = await TestInstallation.create(role: AppRole.administrator);
      try {
        final session = await sampleClosed(source);
        final generator = source.bundle.services as UnifiedCaptureServices;
        final bundle = await generator.delivery.ensureBundle(session);
        final packet = await generator.file(bundle.packagePath).readAsBytes();
        final svc = service(admin);
        await svc.importBytes(packet, await generator.password());
        final looseFile = File('${admin.root.path}/imagen_recibida.jpg');
        await looseFile.writeAsBytes(
          image_codec.encodeJpg(image_codec.Image(width: 30, height: 15)),
        );
        final fresh = await svc.importLooseJpg(
          path: looseFile.path,
          date: '2026-11-09',
          stage: 'exit',
          source: 'Supervisor B',
        );
        final duplicate = await svc.importLooseJpg(
          path: looseFile.path,
          date: '2026-11-09',
          stage: 'exit',
          source: 'Supervisor B',
        );
        final backup = await svc.backupPayload();
        final dest = service(restored);
        final ok = await dest.restorePayload(backup);
        final rows = await dest.cards('2026-11-09', stage: 'exit');
        final loose = await dest.management.looseImages(
          '2026-11-09', stage: 'exit',
        );
        final pdf = await dest.pdf('2026-11-09', 'exit');
        return {
          'fresh': fresh,
          'duplicate': duplicate,
          'ok': ok,
          'cards': rows.length,
          'loose': loose.length,
          'pdf': String.fromCharCodes(pdf.take(4)),
          'filesBacked': (backup['files'] as Map).length >= 4,
          'stage5': backup['stage5'] is Map,
        };
      } finally {
        await source.close();
        await admin.close();
        await restored.close();
      }
    });
    expect(result, isNotNull);
    expect(result!['fresh'], isTrue);
    expect(result['duplicate'], isFalse);
    expect(result['ok'], isTrue);
    expect(result['cards'], 1);
    expect(result['loose'], 1);
    expect(result['pdf'], '%PDF');
    expect(result['filesBacked'], isTrue);
    expect(result['stage5'], isTrue);
  });

  testWidgets('Supervisor no puede importar reportes administrativos',
      (tester) async {
    final denied = await tester.runAsync(() async {
      final supervisor = await TestInstallation.create(role: AppRole.supervisor);
      try {
        await service(supervisor).reports(date: '2026-11-09');
        return false;
      } on StateError {
        return true;
      } finally {
        await supervisor.close();
      }
    });
    expect(denied, isTrue);
  });
  testWidgets(
    'Etapa 6: avisa diferencias de cantidades y respeta las exclusiones',
    (tester) async {
      final result = await tester.runAsync(() async {
        final installation = await TestInstallation.create(
          role: AppRole.administrator,
        );
        try {
          final legacy = AdminServices(
            installation.bundle.admin,
            installation.bundle.capture,
            installation.bundle.services,
            access: installation.bundle.profiles,
          );
          final cases = [
            fixtures.packet(
              stage: 'entry',
              report: 'report-entry-6',
              revision: 'revision-entry-6',
            ),
            fixtures.packet(
              stage: 'exit',
              report: 'report-exit-6a',
              revision: 'revision-exit-6a',
            ),
            fixtures.packet(
              stage: 'exit',
              report: 'report-exit-6b',
              revision: 'revision-exit-6b',
              code: '000363',
            ),
          ];
          for (final packet in cases) {
            await legacy.saveReport(
              ReceivedReport.parse(packet),
              source: 'received',
            );
          }
          final admin = service(installation);
          final before = await admin.warnings('2026-11-07');
          final exits = await admin.cards('2026-11-07', stage: 'exit');
          await admin.setIncluded(exits.last, false);
          final after = await admin.warnings('2026-11-07');
          final excluded = (await admin.cards(
            '2026-11-07',
            stage: 'exit',
          )).where((card) => card['included'] == false).single;
          await admin.setIncluded(excluded, true);
          final restored = await admin.warnings('2026-11-07');
          return {
            'before': before.join(' '),
            'after': after.join(' '),
            'restored': restored.join(' '),
          };
        } finally {
          await installation.close();
        }
      });
      expect(result, isNotNull);
      expect(result!['before'], contains('diferencia 1'));
      expect(result['after'], isNot(contains('Jornada incompleta')));
      expect(result['after'], contains('1 fichas excluidas'));
      expect(result['restored'], contains('diferencia 1'));
    },
  );

}
