import 'package:flutter_test/flutter_test.dart';
import 'package:mule_data/mule_data.dart';
import 'package:operador/cards/jpg_card_files.dart';
import 'package:operador/delivery/mule_delivery.dart';
import 'package:operador/delivery/mule_share_documents.dart';
import 'package:operador/report_filename.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Canal Android entrega TODOS los adjuntos sin EXTRA_TEXT', () async {
    final messenger = TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger;
    final session = CaptureSession('revision-123', Stage.entry, '2026-11-10');
    final bundle = MuleDeliveryBundle(
      createdAt: '2026-11-10T08:00:00.000',
      packagePath: 'closure.mule',
      packageSha256: 'test',
      cards: const [
        JpgTicketArtifact(ticketId: 'one', name: 'ficha_1.jpg',
          path: 'cards/ficha_1.jpg', sha256: 'one'),
        JpgTicketArtifact(ticketId: 'two', name: 'ficha_2.jpg',
          path: 'cards/ficha_2.jpg', sha256: 'two'),
      ],
    );
    final params = muleDocumentShareParams(
      session: session, bundle: bundle, absolutePath: (path) => '/private/$path');
    messenger.setMockMethodCallHandler(MuleShareDocuments.channel, (call) async {
      expect(call.method, 'share');
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args.containsKey('text'), isFalse);
      final files = (args['files'] as List)
          .map((element) => Map<String, dynamic>.from(element as Map))
          .toList();
      expect(files, hasLength(3));
      expect(files.map((f) => f['name']).toList(), [
        'ficha_1.jpg',
        'ficha_2.jpg',
        '${reportFilenameBase(session.stage, session.date, DateTime.parse(bundle.createdAt))}.mule',
      ]);
      expect(files.map((f) => f['source']).toList(), [
        '/private/cards/ficha_1.jpg',
        '/private/cards/ficha_2.jpg',
        '/private/closure.mule',
      ]);
      return {'prepared': 3};
    });
    try {
      await MuleShareDocuments.share(params);
    } finally {
      messenger.setMockMethodCallHandler(MuleShareDocuments.channel, null);
    }
  });

  test('Rechaza confirmación incompleta desde Android', () async {
    final messenger = TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger;
    final params = muleDocumentShareParams(
      session: CaptureSession('revision-123', Stage.exit, '2026-11-10'),
      bundle: const MuleDeliveryBundle(
        createdAt: '2026-11-10T08:00:00.000',
        packagePath: 'closure.mule',
        packageSha256: 'test',
        cards: [
          JpgTicketArtifact(ticketId: 'one', name: 'ficha.jpg',
            path: 'ficha.jpg', sha256: 'test'),
        ],
      ),
      absolutePath: (path) => '/private/$path',
    );
    messenger.setMockMethodCallHandler(MuleShareDocuments.channel,
        (call) async => {'prepared': 1});
    try {
      await expectLater(MuleShareDocuments.share(params), throwsStateError);
    } finally {
      messenger.setMockMethodCallHandler(MuleShareDocuments.channel, null);
    }
  });

  test('Envía JPG y .mule como documentos con nombres originales, nunca solo texto', () {
    final session = CaptureSession('revision-123', Stage.exit, '2026-11-10');
    final bundle = MuleDeliveryBundle(
      createdAt: '2026-11-10T10:11:12.000',
      packagePath: 'private/closure.mule',
      packageSha256: 'sha-test',
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
      '${reportFilenameBase(session.stage, session.date, DateTime.parse(bundle.createdAt))}.mule',
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
