import 'dart:convert';
import 'dart:typed_data';

import 'package:mule_data/mule_data.dart';

import 'payload.dart';

/// Etapa 5: contrato de recepción para .mule de etapa 4 (JPG sin PDF).
///
/// Es independiente de ReceivedReport (v1 con PDF). Un paquete v2 no debe
/// inventar un PDF para entrar en el esquema histórico del Administrador.
class JpgReceivedReport {
  JpgReceivedReport._(
    this.report,
    this.revision,
    this.tickets,
    this.evidence,
    this.events,
    this.cards,
    this.files,
    this.supervisor,
  );

  final Map<String, dynamic> report;
  final Map<String, dynamic> revision;
  final List<Map<String, dynamic>> tickets;
  final List<Map<String, dynamic>> evidence;
  final List<Map<String, dynamic>> events;
  final List<Map<String, String>> cards;
  final Map<String, Uint8List> files;
  final String supervisor;

  String get id => revision['id'] as String;
  String get reportId => report['id'] as String;
  String get date => report['operational_date'] as String;
  String get stage => report['stage'] as String;
  int get number => revision['number'] as int;
  String get device => report['device_id'] as String;

  /// Los reenvíos del mismo cierre son idempotentes aun cuando cambie la
  /// envoltura cifrada. Los hashes originales son parte de la identidad.
  String get fingerprint => digest(utf8.encode(canonical({
    'report': report,
    'revision': revision,
    'tickets': tickets,
    'evidence': evidence,
    'cards': cards,
    'files': {for (final p in files.keys) p: digest(files[p]!)},
  })));

  Map<String, dynamic> get snapshot => {
    'report': report,
    'revision': revision,
    'tickets': tickets,
    'evidence': evidence,
    'audit_events': events,
    'delivery': {
      'version': 2,
      'supervisor': supervisor,
      'cards': cards,
    },
  };

  factory JpgReceivedReport.parse(Map<String, dynamic> payload) {
    Never fail() => throw const FormatException(
      'El paquete JPG no contiene una jornada válida y completa.',
    );
    if (payload['kind'] != 'report' || payload['schema'] != 1) fail();
    final delivery = payload['delivery'];
    final tables = payload['tables'];
    final rawFiles = payload['files'];
    if (delivery is! Map || delivery['version'] != 2 ||
        tables is! Map || rawFiles is! Map || rawFiles.length > 2002) {
      fail();
    }

    List<Map<String, dynamic>> list(String name) {
      final raw = tables[name];
      if (raw is! List || raw.length > 20000) fail();
      try {
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        fail();
      }
    }

    final reports = list('reports');
    final revisions = list('revisions');
    final tickets = list('tickets');
    final evidence = list('evidence');
    final events = list('audit_events');
    if (reports.length != 1 || revisions.length != 1 ||
        tickets.isEmpty || tickets.length > 1000 ||
        tickets.length != evidence.length) {
      fail();
    }

    final report = reports.single;
    final revision = revisions.single;
    bool validId(Object? id) => id is String &&
        RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id);
    if (!validId(report['id']) || !validId(revision['id']) ||
        !validId(report['device_id']) ||
        revision['report_id'] != report['id'] ||
        revision['status'] != 'closed' ||
        revision['current_ticket_id'] != null ||
        revision['number'] is! int || (revision['number'] as int) < 1 ||
        revision['closed_at'] is! String ||
        report['operational_date'] is! String ||
        !['entry', 'exit'].contains(report['stage'])) {
      fail();
    }
    final date = report['operational_date'] as String;
    final parsed = DateTime.tryParse(date);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != date) {
      fail();
    }
    if (delivery['revision_id'] != revision['id'] ||
        delivery['revision_number'] != revision['number'] ||
        delivery['date'] != date ||
        delivery['stage'] != report['stage'] ||
        delivery['supervisor'] is! String ||
        (delivery['supervisor'] as String).trim().isEmpty ||
        (delivery['supervisor'] as String).length > 120) {
      fail();
    }

    final stage = Stage.values.byName(report['stage'] as String);
    final ticketIds = <String>{}, logicalIds = <String>{};
    for (final ticket in tickets) {
      if (!validId(ticket['id']) || !validId(ticket['logical_id']) ||
          !ticketIds.add(ticket['id'] as String) ||
          !logicalIds.add(ticket['logical_id'] as String) ||
          ticket['revision_id'] != revision['id'] ||
          ticket['completed'] != 1) {
        fail();
      }
      for (final field in CaptureField.forStage(stage)
          .where((f) => f.column != 'omission_reason')) {
        if (ticket[field.column] is! String ||
            field.validate(ticket[field.column] as String) != null) {
          fail();
        }
      }
    }

    final files = <String, Uint8List>{};
    var totalBytes = 0;
    for (final item in rawFiles.entries) {
      final path = item.key;
      if (path is! String ||
          !RegExp(r'^(media|artifacts)/[a-zA-Z0-9._/-]+$').hasMatch(path) ||
          path.split('/').any((s) => s.isEmpty || s == '.' || s == '..')) {
        fail();
      }
      final data = item.value;
      if (data is! Map || data['bytes'] is! String ||
          data['sha256'] is! String) {
        fail();
      }
      Uint8List decoded;
      try {
        decoded = base64Decode(data['bytes'] as String);
      } catch (_) {
        fail();
      }
      totalBytes += decoded.length;
      if (totalBytes > 100 * 1024 * 1024 ||
          digest(decoded) != data['sha256']) {
        fail();
      }
      files[path] = decoded;
    }

    final evidenceIds = <String>{}, evidenceTickets = <String>{};
    final originalPaths = <String>{};
    for (final entry in evidence) {
      if (!validId(entry['id']) ||
          !evidenceIds.add(entry['id'] as String) ||
          !ticketIds.contains(entry['ticket_id']) ||
          !evidenceTickets.add(entry['ticket_id'] as String)) {
        fail();
      }
      if (entry['state'] == 'photo') {
        final path = entry['private_path'];
        if (path is! String || files[path] == null ||
            !path.startsWith('media/') ||
            files[path]!.length > 20 * 1024 * 1024 ||
            digest(files[path]!) != entry['sha256'] ||
            entry['omission_reason'] != null) {
          fail();
        }
        originalPaths.add(path);
      } else if (entry['state'] == 'omitted') {
        if (entry['private_path'] != null ||
            entry['omission_reason'] is! String ||
            (entry['omission_reason'] as String).trim().isEmpty) {
          fail();
        }
      } else {
        fail();
      }
    }

    final rawCards = delivery['cards'];
    if (rawCards is! List || rawCards.length != tickets.length) fail();
    final cardIds = <String>{}, cardPaths = <String>{};
    final cards = <Map<String, String>>[];
    for (final raw in rawCards) {
      if (raw is! Map) fail();
      final id = raw['ticket_id'];
      final path = raw['path'];
      final name = raw['name'];
      final hash = raw['sha256'];
      if (!validId(id) || !ticketIds.contains(id) ||
          !cardIds.add(id as String) ||
          path is! String || !path.startsWith('artifacts/') ||
          !cardPaths.add(path) ||
          name is! String ||
          !RegExp(r'^[a-zA-Z0-9._-]+[.]jpg$').hasMatch(name) ||
          !path.endsWith('/$name') ||
          hash is! String || files[path] == null ||
          digest(files[path]!) != hash) {
        fail();
      }
      final data = files[path]!;
      if (data.length < 4 || data[0] != 0xff || data[1] != 0xd8 ||
          data[data.length - 2] != 0xff ||
          data[data.length - 1] != 0xd9) {
        fail();
      }
      cards.add({
        'ticket_id': id,
        'path': path,
        'name': name,
        'sha256': hash,
      });
    }
    final expected = {...originalPaths, ...cardPaths};
    if (expected.length != files.length ||
        !files.keys.every(expected.contains)) {
      fail();
    }
    final eventIds = <String>{};
    for (final event in events) {
      if (!validId(event['id']) ||
          !eventIds.add(event['id'] as String) ||
          event['revision_id'] != revision['id'] ||
          (event['ticket_id'] != null &&
              !ticketIds.contains(event['ticket_id'])) ||
          event['occurred_at'] is! String ||
          event['device_id'] is! String ||
          event['action'] is! String) {
        fail();
      }
    }
    tickets.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    evidence.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    events.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    cards.sort((a, b) => a['ticket_id']!.compareTo(b['ticket_id']!));
    return JpgReceivedReport._(
      report,
      revision,
      tickets,
      evidence,
      events,
      cards,
      files,
      delivery['supervisor'] as String,
    );
  }
}
