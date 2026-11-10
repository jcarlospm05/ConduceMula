import 'dart:convert';
import 'dart:io';

import 'package:admin_data/admin_data.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_codec;
import 'package:mule_data/mule_data.dart';
import 'package:mule_profiles/mule_profiles.dart';
import 'package:operador/delivery/mule_delivery.dart';
import 'package:operador/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'services.dart';

class Stage5Receipt {
  const Stage5Receipt({
    required this.duplicate,
    required this.count,
    required this.date,
    required this.stage,
    required this.format,
  });
  final bool duplicate;
  final int count;
  final String date, stage, format;
}

/// The only new administration workflow. Legacy PDF imports remain readable
/// through AdminServices; the unified UI never invokes its cruces/Excel menus.
class Stage5AdminServices {
  Stage5AdminServices(
    this.repo,
    this.capture,
    this.storage, {
    required this.access,
  }) : old = AdminServices(repo, capture, storage, access: access);

  final AdministrativeAccess access;
  final AdminRepository repo;
  final CaptureRepository capture;
  final OperatorServices storage;
  final AdminServices old;

  JpgInboxRepository get inbox => JpgInboxRepository(repo.db);
  Stage5ManagementRepository get management => Stage5ManagementRepository(
    repo.db,
    actor: repo.actor,
    device: repo.device,
  );

  Future<void> _ready() async {
    await access.requireAdministrator();
    await ensureJpgInboxSchema(repo.db);
    await ensureStage5ManagementSchema(repo.db);
  }

  Future<Stage5Receipt?> receive({String? key}) async {
    await _ready();
    final selected = await FilePicker.platform.pickFiles(type: FileType.any);
    if (selected == null) return null;
    final path = selected.files.single.path;
    if (path == null) throw StateError('No se pudo leer el archivo recibido.');
    return importPath(path, key ?? await storage.password());
  }

  Future<Stage5Receipt> importPath(String path, String key) async {
    await _ready();
    final file = File(path);
    if (p.extension(path).toLowerCase() != '.mule') {
      throw const FormatException('Selecciona un paquete .mule.');
    }
    if (await file.length() > PackageCodec.maxBytes * 2) {
      throw StateError('El archivo supera el tamaño permitido.');
    }
    return importBytes(await file.readAsBytes(), key);
  }

  Future<Stage5Receipt> importBytes(Uint8List bytes, String key) async {
    await _ready();
    final payload = await compute(decryptPayload, {
      'bytes': bytes,
      'password': key,
    });
    if (payload['delivery'] is Map &&
        (payload['delivery'] as Map)['version'] == 2) {
      final report = await compute(JpgReceivedReport.parse, payload);
      return _saveJpg(report, bytes, source: 'received');
    }
    final result = await old.importBytes(bytes, key);
    return Stage5Receipt(
      duplicate: result.result.duplicate,
      count: result.report.tickets.length,
      date: result.report.date,
      stage: result.report.stage,
      format: 'PDF histórico',
    );
  }

  Future<Stage5Receipt> _saveJpg(
    JpgReceivedReport report,
    Uint8List encrypted, {
    required String source,
  }) async {
    await _ready();
    final existing = await repo.db.query(
      'admin_jpg_revisions',
      where: 'id=? OR (report_id=? AND number=?)',
      whereArgs: [report.id, report.reportId, report.number],
    );
    if (existing.isNotEmpty) {
      if (existing.length != 1 ||
          existing.single['id'] != report.id ||
          existing.single['fingerprint'] != report.fingerprint) {
        throw StateError('Conflicto: la misma revisión contiene fichas distintas.');
      }
      return Stage5Receipt(
        duplicate: true,
        count: report.tickets.length,
        date: report.date,
        stage: report.stage,
        format: 'JPG',
      );
    }
    final paths = <String, String>{};
    final created = <File>[];
    try {
      for (final entry in report.files.entries) {
        final base = entry.key.startsWith('media/') ? 'media' : 'artifacts';
        final ext = p.extension(entry.key).replaceAll(
          RegExp(r'[^a-zA-Z0-9.]'), '',
        );
        final local = '$base/imports/${report.id}/${digest(utf8.encode(entry.key))}$ext';
        await _writeVerified(local, entry.value, created);
        paths[entry.key] = local;
      }
      final packagePath = 'artifacts/imports/${report.id}/original_jpg.mule';
      await _writeVerified(packagePath, encrypted, created);
      final result = await inbox.importReport(
        report, paths,
        packagePath: packagePath,
        source: source,
      );
      await repo.event('jpg_report_imported',
        date: report.date,
        details: {
          'revision': report.id,
          'supervisor': report.supervisor,
          'duplicate': result.duplicate,
        },
      );
      return Stage5Receipt(
        duplicate: result.duplicate,
        count: report.tickets.length,
        date: report.date,
        stage: report.stage,
        format: 'JPG',
      );
    } catch (_) {
      for (final file in created) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }

  Future<void> _writeVerified(String path, Uint8List bytes,
      List<File> created) async {
    final target = storage.file(path);
    if (await target.exists()) {
      if (digest(await target.readAsBytes()) != digest(bytes)) {
        throw StateError('Un original ya guardado contiene datos distintos.');
      }
      return;
    }
    await storage.writeAtomic(path, bytes);
    created.add(target);
  }

  Future<void> syncOwn() async {
    await _ready();
    await old.syncOwn();
    final delivery = MuleDelivery(storage);
    for (final row in await capture.sessions(closed: true)) {
      final session = await capture.sessionById(row['id'] as String);
      if (!await storage.hasNewDelivery(session)) continue;
      if ((await repo.db.query('admin_jpg_revisions',
          where: 'id=?', whereArgs: [session.id])).isNotEmpty) {
        continue;
      }
      final bundle = await delivery.ensureBundle(session);
      final encrypted = await storage.file(bundle.packagePath).readAsBytes();
      final payload = await compute(decryptPayload, {
        'bytes': encrypted,
        'password': await storage.password(),
      });
      final report = JpgReceivedReport.parse(payload);
      await _saveJpg(report, encrypted, source: 'own');
    }
  }

  /// JPGs imported manually are not presumed to match any mule or ticket.
  Future<bool> importLooseJpg({
    required String path,
    required String date,
    required String stage,
    required String source,
  }) async {
    await _ready();
    if (!Stage5ManagementRepository.validDate(date) ||
        !['entry', 'exit'].contains(stage) ||
        source.trim().isEmpty) {
      throw const FormatException('Indica fecha, etapa y supervisor de origen.');
    }
    if (p.extension(path).toLowerCase() != '.jpg' &&
        p.extension(path).toLowerCase() != '.jpeg') {
      throw const FormatException('Selecciona una imagen JPG.');
    }
    final input = File(path);
    if (await input.length() > 20 * 1024 * 1024) {
      throw StateError('La imagen supera 20 MB.');
    }
    final bytes = await input.readAsBytes();
    final decoded = image_codec.decodeJpg(bytes);
    if (decoded == null || decoded.width < 1 || decoded.height < 1) {
      throw const FormatException('La imagen JPG está dañada.');
    }
    final hash = digest(bytes);
    final local = 'artifacts/admin_stage5/loose/$hash.jpg';
    final created = <File>[];
    try {
      await _writeVerified(local, bytes, created);
      return await management.importLoose(
        date: date,
        stage: stage,
        source: source.trim(),
        name: p.basename(path),
        sha256: hash,
        localPath: local,
      );
    } catch (_) {
      for (final file in created) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }

  Future<bool?> chooseLooseJpg({
    required String date,
    required String stage,
    required String source,
  }) async {
    await _ready();
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg'],
    );
    if (selected == null) return null;
    final path = selected.files.single.path;
    if (path == null) throw StateError('No se pudo leer la fotografía.');
    return importLooseJpg(
      path: path,
      date: date,
      stage: stage,
      source: source,
    );
  }

  Future<List<Map<String, Object?>>> reports({String? date}) async {
    await _ready();
    final v1 = await repo.reports(date: date);
    final v2 = await inbox.reports(date: date);
    final results = <Map<String, Object?>>[
      for (final row in v1) {
        ...row,
        'format': 'PDF histórico',
        'supervisor': row['device'],
      },
      for (final row in v2) {...row, 'format': 'JPG'},
    ];
    results.sort((a, b) =>
      (b['date'] as String).compareTo(a['date'] as String));
    return results;
  }

  /// Combine the latest revision across both storage generations. A code
  /// repeated by two supervisors is flagged, never silently discarded.
  Future<List<Map<String, Object?>>> cards(String date, {String? stage}) async {
    await _ready();
    final all = <Map<String, Object?>>[
      ...await repo.tickets(date, stage: stage),
      ...await inbox.tickets(date, stage: stage),
    ];
    final latest = <String, int>{};
    for (final t in all) {
      final report = t['report_id'] as String;
      final n = t['revision_number'] as int;
      if ((latest[report] ?? 0) < n) latest[report] = n;
    }
    final result = all.where(
      (t) => t['revision_number'] == latest[t['report_id']],
    ).toList();
    final exclusion = await management.exclusions(date);
    final counts = <String, int>{};
    for (final t in result) {
      final key = '${t['stage']}:${t['code'].toString().trim().toUpperCase()}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final mapped = <Map<String, Object?>>[
      for (final t in result) {
        ...t,
        'supervisor': t['supervisor'] ?? t['device'] ?? 'Sin identificar',
        'included': exclusion['${t['report_id']}:${t['logical_id']}'] != true,
        'possible_duplicate': (counts[
          '${t['stage']}:${t['code'].toString().trim().toUpperCase()}'
        ] ?? 0) > 1,
      },
    ];
    mapped.sort((a, b) =>
      (a['stage'] as String).compareTo(b['stage'] as String));
    return mapped;
  }

  Future<void> setIncluded(Map<String, Object?> card, bool included) async {
    await _ready();
    final date = card['date'] as String;
    final active = await cards(date, stage: card['stage'] as String);
    if (!active.any((x) => x['id'] == card['id'] &&
        x['report_id'] == card['report_id'] &&
        x['logical_id'] == card['logical_id'])) {
      throw StateError('La ficha ya no pertenece a la revisión vigente.');
    }
    await management.setIncluded(
      reportId: card['report_id'] as String,
      logicalId: card['logical_id'] as String,
      date: date,
      stage: card['stage'] as String,
      included: included,
    );
  }

  Future<List<String>> warnings(String date) async {
    final all = await cards(date);
    final notices = <String>[];
    if (!all.any((x) => x['stage'] == 'entry')) {
      notices.add('No hay reportes de entrada recibidos para esta fecha.');
    }
    if (!all.any((x) => x['stage'] == 'exit')) {
      notices.add('No hay reportes de salida recibidos para esta fecha.');
    }
    final duplicated = all.where(
      (x) => x['possible_duplicate'] == true,
    ).length;
    if (duplicated > 0) {
      notices.add('$duplicated fichas tienen códigos repetidos entre reportes. Revisar antes de emitir.');
    }
    final excluded = all.where((x) => x['included'] == false).length;
    if (excluded > 0) notices.add('$excluded fichas excluidas del consolidado.');
    final loose = await management.looseImages(date);
    if (loose.isNotEmpty) {
      notices.add('${loose.length} imágenes JPG sin ficha asociada; aparecen como anexos separados.');
    }
    return notices;
  }

  Future<Uint8List> pdf(String date, String stage) async {
    await _ready();
    if (!['entry', 'exit'].contains(stage) ||
        !Stage5ManagementRepository.validDate(date)) {
      throw const FormatException('Selecciona fecha y entrada o salida.');
    }
    final selection = (await cards(date, stage: stage))
        .where((row) => row['included'] == true).toList();
    final loose = await management.looseImages(date, stage: stage);
    if (selection.isEmpty && loose.isEmpty) {
      throw StateError('No hay fichas seleccionadas ni imágenes para este PDF.');
    }
    if (selection.length + loose.length > 500) {
      throw StateError('Más de 500 páginas. Divide el informe por fecha o etapa.');
    }
    await old.checkExportPhotos(selection);
    final doc = pw.Document();
    final stageLabel = stage == 'entry' ? 'Entrada' : 'Salida';
    for (final row in selection) {
      final original = row['photo_path'];
      final photo = original is String
          ? await storage.file(original).readAsBytes() : null;
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('MuleAgent · $stageLabel · $date',
              style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Ficha: ${row['code']}',
              style: pw.TextStyle(
                fontSize: 19, fontWeight: pw.FontWeight.bold)),
            if (row['driver'] != null)
              pw.Text('Mulero: ${row['driver']}'),
            pw.Text('Proveedor: ${row['provider']}'),
            pw.Text('Hora: ${row['time']}  ·  Horómetro: ${row['meter']} h'),
            pw.Text('Supervisor/origen: ${row['supervisor']}'),
            pw.Text('Equipo: ${row['device']} · Revisión ${row['revision_number']}'),
            if (row['possible_duplicate'] == true)
              pw.Text('Atención: código repetido en los reportes recibidos.'),
            pw.SizedBox(height: 15),
            if (photo != null)
              pw.Image(pw.MemoryImage(photo), height: 340,
                fit: pw.BoxFit.contain)
            else
              pw.Text('Fotografía omitida: ${row['omission_reason'] ?? 'No disponible'}'),
            pw.Spacer(),
            pw.Text('ID de ficha: ${row['id']}',
              style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ));
    }
    for (final looseJpg in loose) {
      final bytes = await storage.file(
        looseJpg['local_path'] as String,
      ).readAsBytes();
      if (digest(bytes) != looseJpg['sha256']) {
        throw StateError('La imagen sin asociar cambió de contenido.');
      }
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('MuleAgent · $stageLabel · $date',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Anexo: imagen sin ficha asociada'),
            pw.Text('Origen declarado: ${looseJpg['source']}'),
            pw.SizedBox(height: 15),
            pw.Image(pw.MemoryImage(bytes), height: 470,
              fit: pw.BoxFit.contain),
            pw.Text('Archivo: ${looseJpg['name']}',
              style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ));
    }
    final bytes = await doc.save();
    await repo.event('stage5_pdf_generated', date: date,
      details: {
        'stage': stage,
        'cards': selection.length,
        'unlinked_images': loose.length,
      });
    return bytes;
  }

  Future<void> previewPdf(String date, String stage) async {
    final bytes = await pdf(date, stage);
    await Printing.layoutPdf(onLayout: (_) async => bytes,
      name: 'MuleAgent $date $stage.pdf');
  }

  Future<bool> exportPdf(String date, String stage) async {
    final bytes = await pdf(date, stage);
    return old.save('MuleAgent $date $stage.pdf', bytes);
  }

  /// Compatible administrator backup plus immutable v2/loose sources and
  /// reversible selection metadata. No report v1 schema alteration.
  Future<Map<String, dynamic>> backupPayload() async {
    await _ready();
    final legacy = await old.backupPayload();
    final stage5 = <String, dynamic>{
      'admin_jpg_revisions': await repo.db.query('admin_jpg_revisions'),
      'admin_jpg_files': await repo.db.query('admin_jpg_files'),
      'admin_stage5_images': await repo.db.query('admin_stage5_images'),
      'admin_stage5_exclusions': await repo.db.query('admin_stage5_exclusions'),
    };
    final tables = legacy['tables'] as Map;
    final extras = <String>{
      for (final f in tables['admin_files'] as List)
        (f as Map)['local_path'] as String,
      for (final r in tables['admin_revisions'] as List)
        if ((r as Map)['package_path'] != null)
          r['package_path'] as String,
      for (final r in tables['admin_revisions'] as List)
        (r as Map)['pdf_path'] as String,
      for (final f in stage5['admin_jpg_files'] as List)
        (f as Map)['local_path'] as String,
      for (final r in stage5['admin_jpg_revisions'] as List)
        (r as Map)['package_path'] as String,
      for (final r in stage5['admin_stage5_images'] as List)
        (r as Map)['local_path'] as String,
    };
    final complete = await storage.includeFiles({
      'schema': 1,
      'kind': 'backup',
      'app': 'administrator',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'tables': legacy['tables'],
      'stage5': stage5,
    }, extra: extras.toList());
    for (final f in stage5['admin_jpg_files'] as List) {
      if ((complete['files'] as Map)[f['local_path']]?['sha256'] != f['sha256']) {
        throw StateError('Una ficha importada falta o está alterada.');
      }
    }
    for (final f in stage5['admin_stage5_images'] as List) {
      if ((complete['files'] as Map)[f['local_path']]?['sha256'] != f['sha256']) {
        throw StateError('Una fotografía no asociada falta o está alterada.');
      }
    }
    return complete;
  }

  Future<bool> backup() async {
    final payload = await backupPayload();
    final bytes = await compute(encryptPayload, {
      'payload': payload,
      'password': await storage.password(),
    });
    return old.save('MuleAgent Administrador respaldo completo.mulebackup',
      bytes);
  }

  Future<bool?> restore({String? key}) async {
    await _ready();
    final chosen = await FilePicker.platform.pickFiles(type: FileType.any);
    if (chosen == null) return null;
    final path = chosen.files.single.path;
    if (path == null) throw StateError('No se pudo abrir el respaldo.');
    if (p.extension(path).toLowerCase() != '.mulebackup') {
      throw const FormatException('Selecciona un respaldo .mulebackup.');
    }
    final file = File(path);
    if (await file.length() > PackageCodec.maxBytes * 2) {
      throw StateError('El respaldo supera el tamaño permitido.');
    }
    final data = await compute(decryptPayload, {
      'bytes': await file.readAsBytes(),
      'password': key ?? await storage.password(),
    });
    return restorePayload(data);
  }

  Future<bool> restorePayload(
    Map<String, dynamic> payload, {
    bool merge = false,
  }) async {
    await _ready();
    if (payload['kind'] != 'backup' || payload['app'] != 'administrator' ||
        payload['schema'] != 1) {
      throw const FormatException('Respaldo administrativo incompatible.');
    }
    final extra = payload['stage5'];
    if (extra == null) return old.restorePayload(payload, merge: merge);
    if (extra is! Map ||
        !['admin_jpg_revisions', 'admin_jpg_files',
          'admin_stage5_images','admin_stage5_exclusions']
            .every((x) => extra[x] is List)) {
      throw const FormatException('Respaldo de fichas JPG incompleto.');
    }
    final files = payload['files'];
    if (files is! Map) throw const FormatException('Respaldo sin archivos.');
    void require(String path, [String? hash]) {
      final file = files[path];
      if (file is! Map || file['bytes'] is! String ||
          file['sha256'] is! String ||
          (hash != null && file['sha256'] != hash) ||
          digest(base64Decode(file['bytes'] as String)) != file['sha256']) {
        throw const FormatException('Archivo de respaldo alterado o faltante.');
      }
    }
    for (final f in extra['admin_jpg_files'] as List) {
      require(f['local_path'] as String, f['sha256'] as String);
    }
    for (final f in extra['admin_jpg_revisions'] as List) {
      require(f['package_path'] as String);
    }
    for (final f in extra['admin_stage5_images'] as List) {
      require(f['local_path'] as String, f['sha256'] as String);
    }
    // The v1 restoration handles base tables and all verified files first.
    // Original tables remain immutable; no overwrite of received reports.
    final restored = await old.restorePayload(payload, merge: merge);
    if (!restored) return false;
    await repo.db.transaction((tx) async {
      for (final table in ['admin_jpg_revisions', 'admin_jpg_files',
          'admin_stage5_images', 'admin_stage5_exclusions']) {
        for (final raw in extra[table] as List) {
          final row = Map<String, Object?>.from(raw as Map);
          final where = switch (table) {
            'admin_jpg_files' => 'revision_id=? AND original_path=?',
            'admin_stage5_exclusions' => 'report_id=? AND logical_id=?',
            _ => 'id=?',
          };
          final args = switch (table) {
            'admin_jpg_files' =>
              [row['revision_id'], row['original_path']],
            'admin_stage5_exclusions' =>
              [row['report_id'], row['logical_id']],
            _ => [row['id']],
          };
          final existing = await tx.query(table,
            where: where, whereArgs: args, limit: 1);
          if (existing.isNotEmpty) {
            if (canonical(existing.single) != canonical(row)) {
              throw StateError('Conflicto al restaurar datos administrativos.');
            }
            continue;
          }
          await tx.insert(table, row);
        }
      }
    });
    return true;
  }
}
