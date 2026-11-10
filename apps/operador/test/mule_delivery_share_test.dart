import 'package:flutter_test/flutter_test.dart';
import 'package:mule_data/mule_data.dart';
import 'package:operador/cards/jpg_card_files.dart';
import 'package:operador/delivery/mule_delivery.dart';

void main() {
  test('Envía JPG y .mule como documentos con nombres originales, nunca solo texto', () {
    final session = CaptureSession('revision-123', Stage.exit, '2026-11-10');
    final bundle = MuleDeliveryBundle(
      createdAt: '2026-11-10T10:11:12.000',
      packagePath: 'private/closure.mule',
      packageSha256: 'a' * 64,
      cards: const [
        JpgTicketArtifact(ticketId: 'ticket-1',
          name: 'ficha_salida_000362.jpg', path: 'private/one.jpg', sha256: 'hash1'),
        JpgTicketArtifact(ticketId: 'ticket-2',
          name: 'ficha_salida_000363.jpg', path: 'private/two.jpg', sha256: 'hash2'),
      ],
    );
    final params = muleDocumentShareParams(
      session: session, bundle: bundle, absolutePath: (path) => '/data/$path');
    expect(params.text, isNull); // WhatsApp must never silently send only EXTRA_TEXT.
    expect(params.files, hasLength(3));
    expect(params.files!.every((file) => file.mimeType == 'application/octet-stream'), isTrue);
    expect(params.files!.map((f) => f.path).toList(), [
      '/data/private/one.jpg', '/data/private/two.jpg', '/data/private/closure.mule']);
    expect(params.fileNameOverrides, [
      'ficha_salida_000362.jpg',
      'ficha_salida_000363.jpg',
      'salida_2026-11-10_10-11-12-000.mule',
    ]);
  });

  test('Rechaza lista sin fichas y nombres de adjuntos duplicados', () {
    final session = CaptureSession('revision-123', Stage.entry, '2026-11-10');
    final withoutCards = MuleDeliveryBundle(
      createdAt: '2026-11-10T10:11:12.000', packagePath: 'a.mule',
      packageSha256: 'a', cards: const [],
    );
    expect(() => muleDocumentShareParams(
      session: session, bundle: withoutCards, absolutePath: (p) => p),
      throwsStateError);
    final duplicateCards = MuleDeliveryBundle(
      createdAt: '2026-11-10T10:11:12.000', packagePath: 'a.mule',
      packageSha256: 'a', cards: const [
        JpgTicketArtifact(ticketId: '1', name: 'same.jpg', path: 'one', sha256: 'a'),
        JpgTicketArtifact(ticketId: '2', name: 'same.jpg', path: 'two', sha256: 'b'),
      ],
    );
    expect(() => muleDocumentShareParams(
      session: session, bundle: duplicateCards, absolutePath: (p) => p),
      throwsStateError);
  });
}
