import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_codec;
import 'package:mule_data/mule_data.dart';

import '../storage/private_file_store.dart';
import 'mule_jpg_card.dart';

/// A completed JPG ficha with an immutable ticket identity.
class JpgTicketArtifact {
  const JpgTicketArtifact({
    required this.ticketId,
    required this.name,
    required this.path,
    required this.sha256,
  });

  final String ticketId;
  final String name;
  final String path;
  final String sha256;

  Map<String, String> toJson() => {
    'ticket_id': ticketId,
    'name': name,
    'path': path,
    'sha256': sha256,
  };
}

/// Prepares JPG cards privately, one per completed ticket.
/// It never edits source photos, existing PDFs or the encrypted .mule contract.
class JpgCardFiles {
  JpgCardFiles(this.repository, this.storage);
  final CaptureRepository repository;
  final PrivateFileStore storage;

  Future<List<JpgTicketArtifact>> ensureCards(
    CaptureSession session, {
    Uint8List? officialLogo,
  }) async {
    final revisions = await repository.db.query(
      'revisions',
      where: 'id=?',
      whereArgs: [session.id],
    );
    if (revisions.length != 1 || revisions.single['status'] != 'closed') {
      throw StateError('Primero cierra la jornada antes de preparar fichas.');
    }
    final number = revisions.single['number'] as int;
    final tickets = await repository.tickets(session);
    if (tickets.isEmpty) throw StateError('No hay fichas en esta jornada.');

    final result = <JpgTicketArtifact>[];
    Uint8List? logo = officialLogo;
    for (final row in tickets) {
      if (row['completed'] != 1) {
        throw StateError('No se puede generar un JPG de una ficha incompleta.');
      }
      final ticketId = row['id'] as String;
      final code = (row['code'] as String).replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      final phase = session.stage == Stage.entry ? 'inicio' : 'salida';
      final name =
          'ficha_${phase}_${session.date}_r${number}_${code}_${ticketId.substring(0, 8)}.jpg';
      final relative = 'artifacts/${session.id}/cards/$name';
      final target = storage.file(relative);

      if (!await target.exists()) {
        Uint8List? photo;
        if (row['evidence_state'] == 'photo') {
          final path = row['private_path'] as String;
          photo = await storage.file(path).readAsBytes();
          final expected = row['sha256'] as String;
          if (sha256.convert(photo).toString() != expected) {
            throw StateError('La foto original de la ficha $code no coincide con su huella.');
          }
        }
        logo ??= (await rootBundle.load(
          'packages/operador/assets/LOGO_MULEAGENT_V1.png',
        )).buffer.asUint8List();
        final jpg = await renderMuleJpgCard(
          session: session,
          ticket: row,
          revisionNumber: number,
          supervisor: repository.operatorName,
          originalPhoto: photo,
          officialLogo: logo,
        );
        await storage.writeAtomic(relative, jpg);
      }
      final bytes = await target.readAsBytes();
      final decoded = image_codec.decodeJpg(bytes);
      if (decoded == null || decoded.width != 1200 || decoded.height != 1740) {
        throw StateError('La ficha JPG guardada está dañada. Restaura sus originales.');
      }
      result.add(JpgTicketArtifact(
        ticketId: ticketId,
        name: name,
        path: relative,
        sha256: sha256.convert(bytes).toString(),
      ));
    }
    return result;
  }
}
