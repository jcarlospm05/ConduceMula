import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mule_data/mule_data.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../cards/jpg_card_files.dart';
import '../public_reports.dart';
import '../report_filename.dart';
import '../services.dart';

/// Immutable reference to one completed delivery. Never contains a PDF.
class MuleDeliveryBundle {
  const MuleDeliveryBundle({
    required this.packagePath,
    required this.packageSha256,
    required this.cards,
    required this.createdAt,
  });
  final String packagePath;
  final String packageSha256;
  final List<JpgTicketArtifact> cards;
  final String createdAt;

  Map<String, dynamic> toJson() => {
    'version': 2,
    'package_path': packagePath,
    'package_sha256': packageSha256,
    'created_at': createdAt,
    'cards': cards.map((c) => c.toJson()).toList(),
  };

  factory MuleDeliveryBundle.fromJson(Map<String, dynamic> raw) {
    if (raw['version'] != 2 ||
        raw['package_path'] is! String ||
        raw['package_sha256'] is! String ||
        raw['created_at'] is! String ||
        raw['cards'] is! List) {
      throw const FormatException('El manifiesto de fichas no es válido.');
    }
    final cards = <JpgTicketArtifact>[];
    for (final item in raw['cards'] as List) {
      if (item is! Map ||
          item['ticket_id'] is! String ||
          item['name'] is! String ||
          item['path'] is! String ||
          item['sha256'] is! String) {
        throw const FormatException('Ficha del manifiesto inválida.');
      }
      cards.add(JpgTicketArtifact(
        ticketId: item['ticket_id'] as String,
        name: item['name'] as String,
        path: item['path'] as String,
        sha256: item['sha256'] as String,
      ));
    }
    if (cards.isEmpty || cards.map((c) => c.ticketId).toSet().length != cards.length) {
      throw const FormatException('Las fichas del manifiesto están duplicadas o vacías.');
    }
    return MuleDeliveryBundle(
      packagePath: raw['package_path'] as String,
      packageSha256: raw['package_sha256'] as String,
      cards: cards,
      createdAt: raw['created_at'] as String,
    );
  }

  List<String> get privatePaths => [
    packagePath,
    ...cards.map((c) => c.path),
  ];
}

/// Fichas JPG + archivo .mule cifrado. Se utiliza solo en la app unificada.
/// La implementación histórica de OperatorServices sigue disponible para
/// leer/restaurar los cierres antiguos sin crear PDF en los cierres nuevos.
class MuleDelivery {
  MuleDelivery(this.storage);
  final OperatorServices storage;
  CaptureRepository get repo => storage.repo;

  static String recordKey(CaptureSession s) => 'delivery_v2_${s.id}';
  static String copyKey(CaptureSession s) => 'public_copy_v2_${s.id}';

  Future<Map<String, Object?>> _closedRevision(CaptureSession session) async {
    final rows = await repo.db.query('revisions',
        where: 'id=? AND status=?', whereArgs: [session.id, 'closed']);
    if (rows.length != 1) throw StateError('Primero cierra la jornada.');
    return rows.single;
  }

  Future<MuleDeliveryBundle?> savedBundle(CaptureSession session) async {
    final raw = await repo.setting(recordKey(session));
    if (raw == null || raw.isEmpty) return null;
    final bundle = MuleDeliveryBundle.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map));
    for (final path in bundle.privatePaths) {
      final expected = path == bundle.packagePath
          ? bundle.packageSha256
          : bundle.cards.singleWhere((c) => c.path == path).sha256;
      final source = storage.file(path);
      if (!await source.exists() ||
          sha256.convert(await source.readAsBytes()).toString() != expected) {
        throw StateError('Falta un archivo de la revisión o su huella cambió. '
            'Restaura los originales desde un respaldo.');
      }
    }
    return bundle;
  }

  /// Supports old PDF-based .mule packages without changing their bytes.
  Future<MuleDeliveryBundle> ensureBundle(CaptureSession session) async {
    final revision = await _closedRevision(session);
    final saved = await savedBundle(session);
    if (saved != null) return saved;

    final cards = await storage.ensureJpgCards(session);
    final old = await repo.db.query('artifacts',
        where: 'revision_id=?', whereArgs: [session.id]);
    final closedAt = DateTime.parse(revision['closed_at'] as String);
    final base = reportFilenameBase(session.stage, session.date, closedAt);
    final packagePath = old.isNotEmpty
        ? old.single['package_path'] as String
        : 'artifacts/${session.id}/$base.mule';

    if (old.isEmpty) {
      final snapshot = await repo.snapshot(revisionId: session.id);
      final payload = await storage.includeFiles(
        snapshot,
        extra: cards.map((c) => c.path).toList(),
      );
      payload['delivery'] = {
        'version': 2,
        'stage': session.stage.name,
        'date': session.date,
        'revision_id': session.id,
        'revision_number': revision['number'],
        'supervisor': repo.operatorName,
        'cards': cards.map((c) => c.toJson()).toList(),
      };
      final encrypted = await compute(encryptPayload, {
        'payload': payload,
        'password': await storage.password(),
      });
      await storage.writeAtomic(packagePath, encrypted);
    }

    final encryptedFile = storage.file(packagePath);
    if (!await encryptedFile.exists()) {
      throw StateError('No se encontró el paquete cifrado de esta revisión.');
    }
    final bundle = MuleDeliveryBundle(
      packagePath: packagePath,
      packageSha256: sha256.convert(await encryptedFile.readAsBytes()).toString(),
      cards: cards,
      createdAt: closedAt.toUtc().toIso8601String(),
    );
    await repo.setSetting(recordKey(session), jsonEncode(bundle.toJson()));
    return bundle;
  }

  Future<String?> publicFolder(CaptureSession session) async {
    final raw = await repo.setting(copyKey(session));
    if (raw == null || raw.isEmpty) return null;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      if (value['device'] != repo.deviceId) return null;
      return value['folder'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> savePublic(
    CaptureSession session, {
    bool prepared = false,
  }) async {
    final bundle = await ensureBundle(session);
    if (!storage.publicStorageEnabled) return null;

    // Never advertise a public copy until every item has been verified.
    await repo.setSetting(copyKey(session), '');
    try {
      if (!prepared) await PublicReports.prepare();
      final revision = await _closedRevision(session);
      final phase = session.stage == Stage.entry ? 'inicio' : 'salida';
      final base = reportFilenameBase(
        session.stage,
        session.date,
        DateTime.parse(revision['closed_at'] as String),
      ).replaceFirst('entrada_', 'inicio_');
      final folder =
          'MuleAgent/${session.date}/$phase/${base}_r${revision['number']}_${session.id.substring(0, 8)}';

      final files = <Map<String, String>>[];
      final names = <String>{};
      Future<void> attach(
        String path,
        String name,
        String mime, {
        String? sha,
      }) async {
        if (!names.add(name)) throw StateError('Hay archivos duplicados en el cierre.');
        final source = storage.file(path);
        final bytes = await source.readAsBytes();
        final hash = sha256.convert(bytes).toString();
        if (sha != null && sha != hash) {
          throw StateError('Un archivo del cierre no coincide con su huella.');
        }
        files.add({
          'source': source.path,
          'name': name,
          'mime': mime,
          'sha256': hash,
        });
      }

      for (final card in bundle.cards) {
        await attach(card.path, card.name, 'image/jpeg', sha: card.sha256);
      }
      for (final row in await repo.tickets(session)) {
        if (row['evidence_state'] != 'photo') continue;
        final path = row['private_path'] as String;
        final name = 'foto_${(row['code'] as String).replaceAll(
          RegExp(r'[^a-zA-Z0-9_-]'), '_')}_${session.date}_$phase'
          '_${(row['id'] as String).substring(0, 8)}${p.extension(path)}';
        final ext = p.extension(path).toLowerCase();
        await attach(
          path,
          name,
          ext == '.png' ? 'image/png' : 'image/jpeg',
          sha: row['sha256'] as String,
        );
      }
      await attach(
        bundle.packagePath,
        '$base.mule',
        'application/octet-stream',
        sha: bundle.packageSha256,
      );
      final receipt = await PublicReports.publish(folder, files);
      await repo.setSetting(copyKey(session), jsonEncode({
        'device': repo.deviceId,
        'folder': receipt['folder'],
        'count': receipt['count'],
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      }));
      return receipt['folder'] as String;
    } catch (_) {
      throw StateError(
        'Las fichas se conservaron dentro de la app, pero no se completó '
        'la copia en Descargas. En Carpeta de reportes puedes reintentar.',
      );
    }
  }

  Future<int> recoverPublic({bool verifyAll = false}) async {
    if (!storage.publicStorageEnabled) return 0;
    await PublicReports.prepare();
    var count = 0;
    for (final row in await repo.sessions(closed: true)) {
      final session = await repo.sessionById(row['id'] as String);
      if (!verifyAll && await publicFolder(session) != null) continue;
      await savePublic(session, prepared: true);
      count++;
    }
    return count;
  }

  /// Sharing JPGs and the single encrypted packet together. Original photos
  /// are stored in Downloads, not added as redundant WhatsApp attachments.
  Future<void> share(CaptureSession session) async {
    await savePublic(session);
    final bundle = await ensureBundle(session);
    final paths = <XFile>[];
    final names = <String>[];
    for (final card in bundle.cards) {
      paths.add(XFile(storage.file(card.path).path, mimeType: 'image/jpeg'));
      names.add(card.name);
    }
    final base = reportFilenameBase(
      session.stage, session.date, DateTime.parse(bundle.createdAt));
    paths.add(XFile(storage.file(bundle.packagePath).path,
        mimeType: 'application/octet-stream'));
    names.add('$base.mule');
    await repo.recordShare(session);
    await SharePlus.instance.share(ShareParams(
      subject: base,
      text: 'MuleAgent · ${session.stage == Stage.entry ? 'Entrada' : 'Salida'} '
          '· ${session.date}',
      files: paths,
      fileNameOverrides: names,
    ));
  }
}
