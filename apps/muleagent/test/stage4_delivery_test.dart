import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:mule_data/mule_data.dart';
import 'package:muleagent/application/unified_capture_services.dart';
import 'package:operador/public_reports.dart';
import 'package:operador/services.dart';

import 'support.dart';

class PublicDeliveryServices extends UnifiedCaptureServices {
  PublicDeliveryServices(super.repo, super.root, super.profiles, super.admin)
      : super(publicStorageEnabled: true);

  @override
  Future<bool> configured() async => true;

  @override
  Future<String> password() async => 'mule-stage4-key-12345';
}

Future<({CaptureSession session, Uint8List original})> closeSample(
  TestInstallation installation,
) async {
  final repo = installation.bundle.capture;
  final session = await repo.start(Stage.exit, '2026-11-09');
  await repo.addTicket(session);
  for (final value in ['000362', 'Proveedor A', '19:16', '111421.9']) {
    final draft = (await repo.draft(session))!;
    await repo.saveValue(draft, value);
    await repo.move(draft, draft.step + 1);
  }
  final original = Uint8List.fromList(
    image.encodePng(image.Image(width: 50, height: 10)),
  );
  final path = 'media/stage4_original.png';
  await installation.bundle.services.writeAtomic(path, original);
  final draft = (await repo.draft(session))!;
  await repo.attachPhoto(
    draft,
    path,
    sha256.convert(original).toString(),
    'camera',
  );
  await repo.complete(session, (await repo.draft(session))!);
  await repo.closeRevision(session);
  return (session: session, original: original);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  testWidgets('Nuevo cierre: JPG y .mule cifrado sin generar PDF', (tester) async {
    final outcome = await tester.runAsync(() async {
      final installation = await TestInstallation.create();
      try {
        final sample = await closeSample(installation);
        final svc = installation.bundle.services as UnifiedCaptureServices;
        final first = await svc.delivery.ensureBundle(sample.session);
        final second = await svc.delivery.ensureBundle(sample.session);
        final package = await svc.file(first.packagePath).readAsBytes();
        final payload = await decryptPayload({
          'bytes': package,
          'password': await svc.password(),
        });
        final original = await svc.file('media/stage4_original.png').readAsBytes();
        final art = await installation.db.query('artifacts');
        final allFiles = payload['files'] as Map;
        final backup = await svc.includeFiles(
          await installation.bundle.capture.snapshot(),
        );
        return {
          'cards': first.cards.length,
          'name': first.cards.single.name,
          'samePackage': first.packageSha256 == second.packageSha256,
          'pdfCount': art.length,
          'deliveryVersion': (payload['delivery'] as Map)['version'],
          'pdfAbsent': !payload.containsKey('pdf'),
          'containsJpg': allFiles.containsKey(first.cards.single.path),
          'containsOriginal': allFiles.containsKey('media/stage4_original.png'),
          'originalIntact': original.toString() == sample.original.toString(),
          'backupPackage': (backup['files'] as Map).containsKey(first.packagePath),
          'backupCard': (backup['files'] as Map).containsKey(first.cards.single.path),
        };
      } finally {
        await installation.close();
      }
    });
    expect(outcome, isNotNull);
    expect(outcome!['cards'], 1);
    expect(outcome['name'], endsWith('.jpg'));
    expect(outcome['samePackage'], isTrue);
    expect(outcome['pdfCount'], 0);
    expect(outcome['deliveryVersion'], 2);
    expect(outcome['pdfAbsent'], isTrue);
    expect(outcome['containsJpg'], isTrue);
    expect(outcome['containsOriginal'], isTrue);
    expect(outcome['originalIntact'], isTrue);
    expect(outcome['backupPackage'], isTrue);
    expect(outcome['backupCard'], isTrue);
  });

  testWidgets('Descargas: JPG + original + .mule, sin PDF; reintento verificable',
      (tester) async {
    final installation = (await tester.runAsync(
      () => TestInstallation.create(),
    ))!;
    addTearDown(() => tester.runAsync(installation.close));
    final sample = (await tester.runAsync(
      () => closeSample(installation),
    ))!;
    final svc = PublicDeliveryServices(
      installation.bundle.capture,
      installation.root,
      installation.bundle.profiles,
      installation.bundle.admin,
    );
    final plans = <Map<String, dynamic>>[];
    var fail = true;
    messenger.setMockMethodCallHandler(PublicReports.channel, (call) async {
      if (call.method == 'prepare') return null;
      if (call.method != 'publish') throw StateError('Unexpected call');
      if (fail) {
        throw PlatformException(code: 'disk_full', message: 'Sin espacio');
      }
      final args = Map<String, dynamic>.from(call.arguments as Map);
      plans.add(args);
      for (final item in args['files'] as List) {
        final f = Map<String, dynamic>.from(item as Map);
        final bytes = await File(f['source'] as String).readAsBytes();
        expect(sha256.convert(bytes).toString(), f['sha256']);
      }
      return {
        'folder': 'Descargas/${args['directory']}',
        'count': (args['files'] as List).length,
      };
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(PublicReports.channel, null);
    });

    await expectLater(
      tester.runAsync(() => svc.savePublicReport(sample.session)),
      throwsA(isA<StateError>()),
    );
    expect(await tester.runAsync(() => svc.publicFolder(sample.session)), isNull);

    fail = false;
    final saved = await tester.runAsync(
      () => svc.recoverPublicReports(),
    );
    expect(saved, 1);
    expect(await tester.runAsync(() => svc.publicFolder(sample.session)),
        startsWith('Descargas/MuleAgent/2026-11-09/salida/'));

    expect(plans, hasLength(1));
    final names = (plans.single['files'] as List)
        .map((f) => f['name'] as String).toList();
    expect(names.where((n) => n.endsWith('.jpg')), hasLength(1));
    expect(names.where((n) => n.endsWith('.mule')), hasLength(1));
    expect(names.where((n) => n.startsWith('foto_')), hasLength(1));
    expect(names.where((n) => n.endsWith('.pdf')), isEmpty);
    expect(await tester.runAsync(() => svc.recoverPublicReports()), 0);
  });

  testWidgets('Respaldo restaurado conserva las fichas y su paquete',
      (tester) async {
    final result = await tester.runAsync(() async {
      final source = await TestInstallation.create();
      final target = await TestInstallation.create();
      try {
        final sample = await closeSample(source);
        final bundle = await (source.bundle.services as UnifiedCaptureServices)
            .delivery.ensureBundle(sample.session);
        final backup = await source.bundle.services.includeFiles(
          await source.bundle.capture.snapshot(),
        );
        await target.bundle.services.restorePayload(backup);
        final restored = await (target.bundle.services as UnifiedCaptureServices)
            .delivery.savedBundle(sample.session);
        return {
          'found': restored != null,
          'sameHash': restored?.packageSha256 == bundle.packageSha256,
          'cards': restored?.cards.length,
          'original':
              (await target.bundle.services.file('media/stage4_original.png')
                  .readAsBytes()).toString() == sample.original.toString(),
        };
      } finally {
        await source.close();
        await target.close();
      }
    });
    expect(result, isNotNull);
    expect(result!['found'], isTrue);
    expect(result['sameHash'], isTrue);
    expect(result['cards'], 1);
    expect(result['original'], isTrue);
  });
}
