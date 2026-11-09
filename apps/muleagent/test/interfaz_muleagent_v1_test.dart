import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mule_data/mule_data.dart';
import 'package:mule_profiles/mule_profiles.dart';
import 'package:muleagent/main.dart';
import 'package:operador/design/mule_tokens.dart';
import 'package:operador/main.dart';

import 'support.dart';

Future<void> settleMule(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

void main() {
  testWidgets('Estilo Mule theme persists and departure is orange', (tester) async {
    final installation = (await tester.runAsync(
      () => TestInstallation.create(role: AppRole.supervisor),
    ))!;
    addTearDown(() => tester.runAsync(installation.close));
    await tester.pumpWidget(MuleAgentApp(bundle: installation.bundle));
    await settleMule(tester);
    expect(find.byTooltip('Cambiar tema'), findsOneWidget);
    expect(find.text('Salida de mula'), findsOneWidget);
    final departure = find.ancestor(
      of: find.text('Salida de mula'),
      matching: find.byType(FilledButton),
    );
    expect(
      tester.widget<FilledButton>(departure).style!.backgroundColor!.resolve({}),
      MulePalette.orange,
    );
    await tester.tap(find.byTooltip('Cambiar tema'));
    await settleMule(tester);
    expect(
      Theme.of(tester.element(find.byType(OperatorScreen))).brightness,
      Brightness.dark,
    );
    expect(
      await tester.runAsync(
        () => installation.bundle.capture.setting('mule_theme_v1'),
      ),
      'dark',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MuleAgentApp(bundle: installation.bundle));
    await settleMule(tester);
    expect(
      Theme.of(tester.element(find.byType(OperatorScreen))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Open entry resumes and time uses two numeric fields', (tester) async {
    final installation = (await tester.runAsync(
      () => TestInstallation.create(role: AppRole.supervisor),
    ))!;
    addTearDown(() => tester.runAsync(installation.close));
    final repo = installation.bundle.capture;
    await tester.runAsync(() async {
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final session = await repo.start(Stage.entry, date);
      await repo.addTicket(session);
    });
    await tester.pumpWidget(MuleAgentApp(bundle: installation.bundle));
    await settleMule(tester);
    expect(find.text('Entrada en proceso'), findsOneWidget);
    expect(find.text('Continuar entrada'), findsOneWidget);
    await tester.tap(find.text('Continuar entrada'));
    await settleMule(tester);
    expect(find.text('Entrada · 1 de 6'), findsOneWidget);
    for (final value in ['Julio', '000362', 'Proveedor A']) {
      await tester.enterText(find.byType(TextField).first, value);
      await tester.tap(find.text('Siguiente'));
      await settleMule(tester);
    }
    expect(find.byKey(const Key('mule-hour')), findsOneWidget);
    expect(find.byKey(const Key('mule-minute')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('mule-hour')), '7');
    await tester.enterText(find.byKey(const Key('mule-minute')), '4');
    await tester.tap(find.text('Siguiente'));
    await settleMule(tester);
    final stored = await tester.runAsync(() async {
      final session = (await repo.resume())!;
      return (await repo.draft(session))!.values['time'];
    });
    expect(stored, '07:04');
    expect(tester.takeException(), isNull);
  });
}
