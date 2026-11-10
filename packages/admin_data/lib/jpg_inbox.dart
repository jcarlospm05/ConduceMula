import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import 'jpg_payload.dart';
import 'payload.dart';

/// Independent v2 inbox. The immutable legacy schema requires pdf_path NOT
/// NULL; adding JPG revisions there would fabricate a non-existent PDF.
Future<void> ensureJpgInboxSchema(Database db) => db.transaction((tx) async {
  await tx.execute(
    'CREATE TABLE IF NOT EXISTS mule_feature_versions('
    'name TEXT PRIMARY KEY, version INTEGER NOT NULL)',
  );
  final version = await tx.query(
    'mule_feature_versions',
    where: 'name=?',
    whereArgs: ['administration_jpg'],
  );
  final existing = await tx.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' "
    "AND name IN ('admin_jpg_revisions','admin_jpg_files')",
  );
  if (version.isNotEmpty) {
    if (version.single['version'] != 1 || existing.length != 2) {
      throw StateError(
        'El almacenamiento de fichas JPG está incompleto o es incompatible.',
      );
    }
    return;
  }
  if (existing.isNotEmpty) {
    throw StateError(
      'Ya existe un almacenamiento JPG sin versión registrada. '
      'Se conservaron los datos para su revisión.',
    );
  }
  await tx.execute('''
    CREATE TABLE admin_jpg_revisions(
      id TEXT PRIMARY KEY,
      report_id TEXT NOT NULL,
      number INTEGER NOT NULL,
      date TEXT NOT NULL,
      stage TEXT NOT NULL CHECK(stage IN ('entry','exit')),
      device TEXT NOT NULL,
      supervisor TEXT NOT NULL,
      source TEXT NOT NULL CHECK(source IN ('received','own')),
      fingerprint TEXT NOT NULL,
      snapshot TEXT NOT NULL,
      package_path TEXT NOT NULL,
      received_at TEXT NOT NULL,
      UNIQUE(report_id,number)
    )''');
  await tx.execute(
    'CREATE INDEX admin_jpg_dates ON '
    'admin_jpg_revisions(date,stage,report_id,number)',
  );
  await tx.execute('''
    CREATE TABLE admin_jpg_files(
      revision_id TEXT NOT NULL REFERENCES admin_jpg_revisions(id),
      original_path TEXT NOT NULL,
      local_path TEXT NOT NULL,
      sha256 TEXT NOT NULL,
      PRIMARY KEY(revision_id,original_path)
    )''');
  for (final table in ['admin_jpg_revisions', 'admin_jpg_files']) {
    for (final action in ['UPDATE', 'DELETE']) {
      await tx.execute(
        'CREATE TRIGGER ${table}_immutable_${action.toLowerCase()} '
        'BEFORE $action ON $table BEGIN '
        "SELECT RAISE(ABORT,'Los originales JPG son de solo lectura'); END",
      );
    }
  }
  await tx.insert('mule_feature_versions', {
    'name': 'administration_jpg',
    'version': 1,
  });
});

class JpgInboxResult {
  const JpgInboxResult({required this.duplicate});
  final bool duplicate;
}

/// Stage-5 storage for immutable JPG revisions, independent from PDF history.
/// File writes and crypto verification occur in AdminServices before import.
class JpgInboxRepository {
  JpgInboxRepository(this.db);
  final Database db;

  Future<JpgInboxResult> importReport(
    JpgReceivedReport report,
    Map<String, String> filePaths, {
    required String packagePath,
    required String source,
  }) => db.transaction((tx) async {
    if (!['received', 'own'].contains(source) ||
        packagePath.isEmpty ||
        filePaths.length != report.files.length ||
        !report.files.keys.every(filePaths.containsKey)) {
      throw ArgumentError('Archivos del paquete JPG incompletos.');
    }
    final legacyCollision = await tx.query(
      'admin_revisions',
      columns: ['id'],
      where: 'id=? OR (report_id=? AND number=?)',
      whereArgs: [report.id, report.reportId, report.number],
      limit: 1,
    );
    if (legacyCollision.isNotEmpty) {
      throw StateError(
        'Esta revisión ya existe en el archivo histórico con PDF.',
      );
    }
    final existing = await tx.query(
      'admin_jpg_revisions',
      where: 'id=? OR (report_id=? AND number=?)',
      whereArgs: [report.id, report.reportId, report.number],
    );
    if (existing.isNotEmpty) {
      if (existing.length != 1 ||
          existing.single['id'] != report.id ||
          existing.single['fingerprint'] != report.fingerprint) {
        throw StateError(
          'Conflicto: una revisión JPG ya existe con contenido distinto.',
        );
      }
      return const JpgInboxResult(duplicate: true);
    }
    final previous = await tx.query(
      'admin_jpg_revisions',
      where: 'report_id=?',
      whereArgs: [report.reportId],
      limit: 1,
    );
    if (previous.isNotEmpty &&
        (previous.single['date'] != report.date ||
         previous.single['stage'] != report.stage ||
         previous.single['device'] != report.device)) {
      throw StateError('La identidad de la jornada cambió entre revisiones.');
    }
    await tx.insert('admin_jpg_revisions', {
      'id': report.id,
      'report_id': report.reportId,
      'number': report.number,
      'date': report.date,
      'stage': report.stage,
      'device': report.device,
      'supervisor': report.supervisor,
      'source': source,
      'fingerprint': report.fingerprint,
      'snapshot': canonical(report.snapshot),
      'package_path': packagePath,
      'received_at': DateTime.now().toUtc().toIso8601String(),
    });
    for (final path in report.files.keys) {
      await tx.insert('admin_jpg_files', {
        'revision_id': report.id,
        'original_path': path,
        'local_path': filePaths[path],
        'sha256': digest(report.files[path]!),
      });
    }
    return const JpgInboxResult(duplicate: false);
  });

  Future<List<Map<String, Object?>>> reports({
    String? date,
    bool latest = true,
  }) => db.rawQuery(
    '''SELECT r.* FROM admin_jpg_revisions r
      WHERE (? IS NULL OR r.date=?)
      ${latest ? 'AND r.number=(SELECT max(s.number) FROM admin_jpg_revisions s WHERE s.report_id=r.report_id)' : ''}
      ORDER BY r.date DESC,r.stage,r.received_at DESC''',
    [date, date],
  );

  Future<List<Map<String, Object?>>> files(String revisionId) => db.query(
    'admin_jpg_files',
    where: 'revision_id=?',
    whereArgs: [revisionId],
  );

  Future<List<Map<String, Object?>>> tickets(String date, {String? stage}) async {
    final results = <Map<String, Object?>>[];
    for (final revision in await reports(date: date)) {
      if (stage != null && revision['stage'] != stage) continue;
      final snapshot = jsonDecode(revision['snapshot'] as String) as Map;
      final files = await this.files(revision['id'] as String);
      final evidence = snapshot['evidence'] as List;
      final cards = (snapshot['delivery'] as Map)['cards'] as List;
      for (final raw in snapshot['tickets'] as List) {
        final row = raw as Map;
        final e = evidence.singleWhere((v) => v['ticket_id'] == row['id']) as Map;
        final card = cards.singleWhere((v) => v['ticket_id'] == row['id']) as Map;
        final photoPath = e['state'] == 'photo'
            ? files.singleWhere(
                (f) => f['original_path'] == e['private_path'],
              )['local_path']
            : null;
        final jpgPath = files.singleWhere(
          (f) => f['original_path'] == card['path'],
        )['local_path'];
        results.add({
          ...Map<String, Object?>.from(row),
          'stage': revision['stage'],
          'date': revision['date'],
          'report_id': revision['report_id'],
          'revision_number': revision['number'],
          'device': revision['device'],
          'supervisor': revision['supervisor'],
          'source': revision['source'],
          'photo_path': photoPath,
          'jpg_path': jpgPath,
          'evidence_state': e['state'],
          'omission_reason': e['omission_reason'],
        });
      }
    }
    return results;
  }
}
