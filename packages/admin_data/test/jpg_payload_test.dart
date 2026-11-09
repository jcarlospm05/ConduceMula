import 'dart:convert';

import 'package:admin_data/admin_data.dart';
import 'package:test/test.dart';

import 'fixtures.dart' as fixtures;

Map<String, dynamic> jpgPacket() {
  final packet = fixtures.packet();
  packet.remove('pdf');
  final tables = packet['tables'] as Map<String, dynamic>;
  final report = (tables['reports'] as List).single as Map;
  final revision = (tables['revisions'] as List).single as Map;
  final ticket = (tables['tickets'] as List).single as Map;
  final id = ticket['id'] as String;
  const name = 'ficha_inicio_2026-11-07_r1_000362_revision-e1.jpg';
  final path = 'artifacts/revision-e1/cards/$name';
  final jpg = [0xff, 0xd8, 0xff, 0xd9];
  packet['files'] = {
    path: {'bytes': base64Encode(jpg), 'sha256': digest(jpg)},
  };
  packet['delivery'] = {
    'version': 2,
    'stage': report['stage'],
    'date': report['operational_date'],
    'revision_id': revision['id'],
    'revision_number': revision['number'],
    'supervisor': 'Supervisor A',
    'cards': [
      {
        'ticket_id': id,
        'path': path,
        'name': name,
        'sha256': digest(jpg),
      },
    ],
  };
  return packet;
}

void main() {
  test('Etapa 5: recibe v2 JPG sin inventar PDF', () {
    final data = jpgPacket();
    final report = JpgReceivedReport.parse(data);
    expect(report.id, 'revision-e1');
    expect(report.reportId, 'report-e');
    expect(report.supervisor, 'Supervisor A');
    expect(report.cards, hasLength(1));
    expect(report.files, hasLength(1));
    expect(report.snapshot['delivery']['version'], 2);
    expect(() => ReceivedReport.parse(data), throwsFormatException);
  });

  test('Etapa 5: mismos originales producen misma huella de cierre', () {
    final a = JpgReceivedReport.parse(jpgPacket());
    final b = JpgReceivedReport.parse(jpgPacket());
    expect(a.fingerprint, b.fingerprint);
  });

  test('Etapa 5: fotos JPG manipuladas o sobrantes se rechazan', () {
    final bad = jpgPacket();
    final files = bad['files'] as Map<String, dynamic>;
    final path = files.keys.single;
    (files[path] as Map)['bytes'] = base64Encode([0, 0, 0, 0]);
    expect(() => JpgReceivedReport.parse(bad), throwsFormatException);

    final orphan = jpgPacket();
    (orphan['files'] as Map)['artifacts/unexpected.jpg'] = {
      'bytes': base64Encode([0xff, 0xd8, 0xff, 0xd9]),
      'sha256': digest([0xff, 0xd8, 0xff, 0xd9]),
    };
    expect(() => JpgReceivedReport.parse(orphan), throwsFormatException);
  });

  test('Etapa 5: identidad, etapa, revisión y duplicados se comprueban', () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (p) => (p['delivery'] as Map)['revision_number'] = 99,
      (p) => (p['delivery'] as Map)['stage'] = 'exit',
      (p) => (p['delivery'] as Map)['supervisor'] = '',
      (p) => ((p['delivery'] as Map)['cards'] as List).add(
        Map.from(((p['delivery'] as Map)['cards'] as List).first as Map),
      ),
      (p) => (p['delivery'] as Map)['cards'] = [],
    ]) {
      final data = jpgPacket();
      change(data);
      expect(() => JpgReceivedReport.parse(data), throwsFormatException);
    }
  });

  test('Etapa 5: contrato PDF histórico permanece legible', () {
    final legacy = ReceivedReport.parse(fixtures.packet());
    expect(legacy.pdfPath, contains('.pdf'));
    expect(legacy.tickets, hasLength(1));
  });
}
