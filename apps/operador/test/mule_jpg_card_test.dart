import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_codec;
import 'package:mule_data/mule_data.dart';
import 'package:operador/cards/jpg_card_files.dart';
import 'package:operador/cards/mule_jpg_card.dart';
import 'package:operador/storage/private_file_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets('Una ficha JPG por mula; fotografía original y nombre permanecen intactos', (tester) async {
    final result = await tester.runAsync(() async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          singleInstance: false,
          version: schemaVersion,
          onConfigure: configureDatabase,
          onCreate: createSchema,
        ),
      );
      final root = await Directory.systemTemp.createTemp('mule_stage4_');
      try {
        final repo = CaptureRepository(db, deviceId: 'dispositivo-supervisor');
        repo.operatorName = 'Supervisor A';
        final store = PrivateFileStore(root);
        final session = await repo.start(Stage.exit, '2026-11-09');
        await repo.addTicket(session);
        for (final value in ['000362', 'Proveedor A', '19:16', '111421.9']) {
          final draft = (await repo.draft(session))!;
          await repo.saveValue(draft, value);
          await repo.move(draft, draft.step + 1);
        }
        final original = Uint8List.fromList(
          image_codec.encodePng(image_codec.Image(width: 30, height: 10)),
        );
        const originalPath = 'media/foto_original.png';
        await store.writeAtomic(originalPath, original);
        final draft = (await repo.draft(session))!;
        await repo.attachPhoto(
          draft,
          originalPath,
          sha256.convert(original).toString(),
          'camera',
        );
        await repo.complete(session, (await repo.draft(session))!);
        await repo.closeRevision(session);

        final generator = JpgCardFiles(repo, store);
        final logo = Uint8List.fromList(
          image_codec.encodePng(image_codec.Image(width: 15, height: 15)),
        );
        final cards = await generator.ensureCards(session, officialLogo: logo);
        final jpg = await store.file(cards.single.path).readAsBytes();
        final repeat = await generator.ensureCards(session, officialLogo: logo);
        final unchangedOriginal = await store.file(originalPath).readAsBytes();

        return {
          'count': cards.length,
          'name': cards.single.name,
          'sha': cards.single.sha256,
          'secondSha': repeat.single.sha256,
          'image': jpg,
          'originalPreserved': unchangedOriginal.toString() == original.toString(),
        };
      } finally {
        await db.close();
        await root.delete(recursive: true);
      }
    });
    expect(result, isNotNull);
    final completed = result!;
    expect(completed['count'], 1);
    expect(completed['name'], startsWith('ficha_salida_2026-11-09_r1_000362_'));
    expect(completed['name'], endsWith('.jpg'));
    expect(completed['sha'], completed['secondSha']);
    expect(completed['originalPreserved'], isTrue);
    final image = image_codec.decodeJpg(completed['image'] as Uint8List);
    expect(image, isNotNull);
    expect(image!.width, 1200);
    expect(image.height, 1740);
  });

  testWidgets('Ficha con omisión documentada sin inventar fotografía', (tester) async {
    final jpg = await tester.runAsync(
      () => renderMuleJpgCard(
        session: CaptureSession('revision-identidad', Stage.entry, '2026-11-09'),
        revisionNumber: 2,
        supervisor: 'Supervisor A',
        ticket: {
          'id': 'ticket-identidad',
          'code': '00123',
          'provider': 'Proveedor B',
          'driver': 'Mulero C',
          'time': '07:04',
          'meter': '12345.6',
          'evidence_state': 'omitted',
          'omission_reason': 'Cristal de horómetro empañado',
        },
      ),
    );
    expect(jpg, isNotNull);
    final img = image_codec.decodeJpg(jpg!);
    expect(img, isNotNull);
    expect(img!.height, 1740);
  });

  testWidgets('Ficha incompleta no produce JPG', (tester) async {
    await expectLater(
      renderMuleJpgCard(
        session: CaptureSession('revision', Stage.exit, '2026-11-09'),
        revisionNumber: 1,
        supervisor: 'Supervisor',
        ticket: {
          'id': 'ticket',
          'code': '00123',
          'provider': 'Proveedor',
          'time': '10:00',
          'meter': '1.0',
          'evidence_state': 'photo',
        },
      ),
      throwsA(isA<StateError>()),
    );
  });
}
