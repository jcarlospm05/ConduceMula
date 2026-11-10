import 'dart:convert';

import 'package:admin_data/admin_data.dart';
import 'package:mule_data/mule_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

import 'fixtures.dart' as fixtures;

Map<String, dynamic> jpgPacket({
  String reportId = 'report-jpg',
  String revisionId = 'revision-jpg',
  String code = '000362',
  int number = 1,
  String device = 'device-01',
  String supervisor = 'Supervisor A',
}) {
  final payload = fixtures.packet(
    report: reportId,
    revision: revisionId,
    number: number,
    code: code,
  );
  payload.remove('pdf');
  final tables = payload['tables'] as Map;
  final reports = tables['reports'] as List;
  (reports.single as Map)['device_id'] = device;
  final ticket = (tables['tickets'] as List).single as Map;
  final name = 'ficha_inicio_2026-11-07_r${number}_${code}_$revisionId.jpg';
  final path = 'artifacts/$revisionId/cards/$name';
  final jpg = [0xff, 0xd8, 0xff, 0xd9];
  payload['files'] = {
    path: {'bytes': base64Encode(jpg), 'sha256': digest(jpg)},
  };
  payload['delivery'] = {
    'version': 2,
    'stage': 'entry',
    'date': '2026-11-07',
    'revision_id': revisionId,
    'revision_number': number,
    'supervisor': supervisor,
    'cards': [
      {
        'ticket_id': ticket['id'],
        'path': path,
        'name': name,
        'sha256': digest(jpg),
      },
    ],
  };
  return payload;
}

void main() {
  sqfliteFfiInit();
  late Database db;
  late JpgInboxRepository inbox;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: 1,
        onConfigure: configureDatabase,
        onCreate: (db, _) async {
          await createSchema(db, schemaVersion);
          await createAdminSchema(db);
        },
      ),
    );
    await ensureAdminSchema(db);
    await ensureJpgInboxSchema(db);
    inbox = JpgInboxRepository(db);
  });
  tearDown(() => db.close());

  Future<JpgInboxResult> importJpg(Map<String, dynamic> payload) async {
    final report = JpgReceivedReport.parse(payload);
    return inbox.importReport(
      report,
      {
        for (final name in report.files.keys)
          name: 'artifacts/imports/${report.id}/${name.split('/').last}',
      },
      packagePath: 'artifacts/imports/${report.id}/original.mule',
      source: 'received',
    );
  }

  test('migración independiente: conserva el archivo PDF histórico', () async {
    final existing = ReceivedReport.parse(fixtures.packet());
    final repository = AdminRepository(db, device: 'admin', actor: 'Carlos');
    await repository.importReport(
      existing,
      fixtures.paths(existing),
      source: 'received',
    );
    await ensureJpgInboxSchema(db);
    await importJpg(jpgPacket());

    expect(await repository.reports(), hasLength(1));
    expect((await repository.reports()).single['pdf_path'], isNotNull);
    expect(await inbox.reports(), hasLength(1));
    expect((await db.query('mule_feature_versions')), hasLength(2));
  });

  test('reenvío idéntico no duplica y cambio de originales crea conflicto', () async {
    expect((await importJpg(jpgPacket())).duplicate, isFalse);
    expect((await importJpg(jpgPacket())).duplicate, isTrue);
    await expectLater(
      importJpg(jpgPacket(code: '000363')),
      throwsStateError,
    );
    expect(await inbox.reports(), hasLength(1));
    expect(await db.query('admin_jpg_files'), hasLength(1));
  });

  test('dos supervisores, una fecha, fichas diferenciadas', () async {
    await importJpg(jpgPacket());
    await importJpg(jpgPacket(
      reportId: 'report-02',
      revisionId: 'revision-02',
      device: 'device-02',
      supervisor: 'Supervisor B',
      code: '001024',
    ));
    final rows = await inbox.tickets('2026-11-07');
    expect(rows, hasLength(2));
    expect(rows.map((e) => e['supervisor']).toSet(), {
      'Supervisor A',
      'Supervisor B',
    });
    expect(rows.every((e) => e['jpg_path'] != null), isTrue);
    expect(rows.map((e) => e['code']).toSet(), {'000362', '001024'});
  });

  test('registros JPG importados y archivos son inmutables', () async {
    await importJpg(jpgPacket());
    await expectLater(
      db.update(
        'admin_jpg_revisions',
        {'supervisor': 'Alterado'},
        where: 'id=?',
        whereArgs: ['revision-jpg'],
      ),
      throwsA(anything),
    );
    await expectLater(
      db.delete('admin_jpg_files'),
      throwsA(anything),
    );
    expect(await inbox.reports(), hasLength(1));
  });

  test('no se acepta colisión entre revisión JPG y PDF previo', () async {
    final old = fixtures.packet(report: 'report-jpg', revision: 'revision-jpg');
    final received = ReceivedReport.parse(old);
    await AdminRepository(db, device: 'admin', actor: 'Carlos')
        .importReport(received, fixtures.paths(received), source: 'received');
    await expectLater(importJpg(jpgPacket()), throwsStateError);
    expect(await inbox.reports(), isEmpty);
  });
}
