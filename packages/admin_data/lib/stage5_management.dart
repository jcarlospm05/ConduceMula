import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid/uuid.dart';

import 'payload.dart';

/// Separate, versioned metadata. Received originals remain immutable.
Future<void> ensureStage5ManagementSchema(Database db) => db.transaction((tx) async {
  await tx.execute('CREATE TABLE IF NOT EXISTS mule_feature_versions('
      'name TEXT PRIMARY KEY, version INTEGER NOT NULL)');
  final version = await tx.query('mule_feature_versions',
      where: 'name=?', whereArgs: ['administration_stage5']);
  final names = (await tx.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name IN "
    "('admin_stage5_images','admin_stage5_exclusions')",
  )).map((x) => x['name']).toSet();
  if (version.isNotEmpty) {
    if (version.single['version'] != 1 || names.length != 2) {
      throw StateError('Versión de selección administrativa incompatible.');
    }
    return;
  }
  if (names.isNotEmpty) {
    throw StateError('El archivo administrativo está incompleto. Se conservaron los datos.');
  }
  await tx.execute('''CREATE TABLE admin_stage5_images(
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,
    stage TEXT NOT NULL CHECK(stage IN ('entry','exit')),
    source TEXT NOT NULL,
    name TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    local_path TEXT NOT NULL,
    received_at TEXT NOT NULL,
    UNIQUE(date,stage,source,sha256)
  )''');
  await tx.execute('''CREATE TABLE admin_stage5_exclusions(
    report_id TEXT NOT NULL,
    logical_id TEXT NOT NULL,
    date TEXT NOT NULL,
    stage TEXT NOT NULL CHECK(stage IN ('entry','exit')),
    excluded INTEGER NOT NULL CHECK(excluded IN (0,1)),
    reason TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY(report_id,logical_id)
  )''');
  for (final action in ['UPDATE', 'DELETE']) {
    await tx.execute(
      'CREATE TRIGGER admin_stage5_images_immutable_${action.toLowerCase()} '
      'BEFORE $action ON admin_stage5_images BEGIN '
      "SELECT RAISE(ABORT,'Las imágenes originales son inmutables'); END",
    );
  }
  await tx.insert('mule_feature_versions', {
    'name': 'administration_stage5',
    'version': 1,
  });
});

class Stage5ManagementRepository {
  Stage5ManagementRepository(this.db, {required this.actor, required this.device});
  final Database db;
  final String actor, device;
  final _uuid = const Uuid();
  String get now => DateTime.now().toUtc().toIso8601String();

  static bool validDate(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed != null &&
        parsed.toIso8601String().substring(0, 10) == value;
  }

  Future<bool> importLoose({
    required String date,
    required String stage,
    required String source,
    required String name,
    required String sha256,
    required String localPath,
  }) => db.transaction((tx) async {
    if (!validDate(date) || !['entry', 'exit'].contains(stage) ||
        source.trim().isEmpty || source.length > 120 ||
        name.trim().isEmpty || name.length > 200 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        !localPath.startsWith('artifacts/admin_stage5/loose/')) {
      throw const FormatException('Datos de la fotografía sin asociar inválidos.');
    }
    final exists = await tx.query('admin_stage5_images',
      where: 'date=? AND stage=? AND source=? AND sha256=?',
      whereArgs: [date, stage, source, sha256]);
    if (exists.isNotEmpty) return false;
    await tx.insert('admin_stage5_images', {
      'id': _uuid.v4(),
      'date': date,
      'stage': stage,
      'source': source.trim(),
      'name': name,
      'sha256': sha256,
      'local_path': localPath,
      'received_at': now,
    });
    await _audit(tx, 'jpg_unlinked_imported', date, {
      'sha256': sha256, 'stage': stage, 'source': source,
    });
    return true;
  });

  Future<List<Map<String, Object?>>> looseImages(String date,
      {String? stage}) async => db.query('admin_stage5_images',
    where: stage == null ? 'date=?' : 'date=? AND stage=?',
    whereArgs: stage == null ? [date] : [date, stage],
    orderBy: 'stage,received_at DESC',
  );

  Future<Map<String, bool>> exclusions(String date) async {
    final rows = await db.query('admin_stage5_exclusions',
      where: 'date=? AND excluded=1', whereArgs: [date]);
    return {for (final r in rows)
      '${r['report_id']}:${r['logical_id']}': true};
  }

  Future<void> setIncluded({
    required String reportId,
    required String logicalId,
    required String date,
    required String stage,
    required bool included,
  }) => db.transaction((tx) async {
    if (reportId.isEmpty || logicalId.isEmpty || !validDate(date) ||
        !['entry','exit'].contains(stage)) {
      throw const FormatException('Identidad de ficha inválida.');
    }
    final previous = await tx.query('admin_stage5_exclusions',
      where: 'report_id=? AND logical_id=?',
      whereArgs: [reportId, logicalId]);
    if (previous.isNotEmpty &&
        (previous.single['date'] != date ||
         previous.single['stage'] != stage)) {
      throw StateError('No coincide la identidad de la ficha con la selección.');
    }
    final newState = included ? 0 : 1;
    if (previous.isNotEmpty && previous.single['excluded'] == newState) return;
    final data = {
      'report_id': reportId,
      'logical_id': logicalId,
      'date': date,
      'stage': stage,
      'excluded': newState,
      'reason': included ? 'Volver a incluir' : 'Exclusión del consolidado',
      'updated_at': now,
    };
    if (previous.isEmpty) {
      await tx.insert('admin_stage5_exclusions', data);
    } else {
      await tx.update('admin_stage5_exclusions', data,
        where: 'report_id=? AND logical_id=?',
        whereArgs: [reportId, logicalId]);
    }
    await _audit(tx, included ? 'card_reincluded' : 'card_excluded',
      date, {'report': reportId, 'logical_id': logicalId, 'stage': stage});
  });

  Future<void> _audit(Transaction tx, String action, String date,
      Map<String, Object?> details) async {
    await tx.insert('admin_events', {
      'id': _uuid.v4(),
      'occurred_at': now,
      'actor': actor,
      'device': device,
      'action': action,
      'date': date,
      'details': jsonEncode(details),
    });
  }
}
