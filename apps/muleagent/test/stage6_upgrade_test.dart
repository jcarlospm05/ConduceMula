import 'dart:io';

import 'package:admin_data/admin_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mule_data/mule_data.dart';
import 'package:mule_profiles/mule_profiles.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('Stage 6 upgrade: older Operator draft and settings survive additive '
      'Administrator schema migration and a real SQLite close/reopen', () async {
    final root = await Directory.systemTemp.createTemp('mule_upgrade_');
    final file = '${root.path}/operador.db';
    final storedProfile = MemoryProfiles();
    final profiles = ProfileRepository(storedProfile);
    try {
      final before = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          singleInstance: false,
          onConfigure: configureDatabase,
          onCreate: createSchema,
        ),
      );
      final operator = CaptureRepository(before, deviceId: 'legacy-operator');
      final session = await operator.start(Stage.entry, '2026-11-10');
      await operator.addTicket(session);
      final draft = (await operator.draft(session))!;
      await operator.saveValue(draft, '000362');
      await operator.setSetting('operator', 'Julio');
      await operator.setSetting('mule_theme_v1', 'dark');
      await profiles.configure(AppRole.administrator);
      final reportRowsBefore = await before.query('reports');
      final evidenceRowsBefore = await before.query('evidence');
      await before.close();

      final upgraded = await databaseFactoryFfi.openDatabase(
        file,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          singleInstance: false,
          onConfigure: configureDatabase,
          onCreate: createSchema,
          onUpgrade: upgradeSchema,
        ),
      );
      try {
        await ensureAdminSchema(upgraded);
        await ensureJpgInboxSchema(upgraded);
        await ensureStage5ManagementSchema(upgraded);
        // Running the migration again must not modify existing rows.
        await ensureAdminSchema(upgraded);
        await ensureJpgInboxSchema(upgraded);
        await ensureStage5ManagementSchema(upgraded);
        final resumed = CaptureRepository(
          upgraded,
          deviceId: 'legacy-operator',
        );
        expect((await resumed.resume())?.id, session.id);
        expect((await resumed.draft(session))?.values['code'], '000362');
        expect(await resumed.setting('operator'), 'Julio');
        expect(await resumed.setting('mule_theme_v1'), 'dark');
        expect(await upgraded.query('reports'), reportRowsBefore);
        expect(await upgraded.query('evidence'), evidenceRowsBefore);
        expect((await upgraded.query('mule_feature_versions')).length, 3);
        expect((await profiles.load())!.installedAs, AppRole.administrator);
        await profiles.switchTo(AppRole.supervisor);
        expect((await profiles.load())!.activeRole, AppRole.supervisor);
        final rebooted = ProfileRepository(storedProfile);
        expect((await rebooted.load())!.canSwitchRoles, isTrue);
        await rebooted.switchTo(AppRole.administrator);
        await rebooted.requireAdministrator();
      } finally {
        await upgraded.close();
      }
    } finally {
      await root.delete(recursive: true);
    }
  });
}
