import 'package:admin_data/admin_data.dart';
import 'package:mule_data/mule_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late Stage5ManagementRepository manager;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false, version: 1,
        onConfigure: configureDatabase,
        onCreate: (d, _) async {
          await createSchema(d, schemaVersion);
          await createAdminSchema(d);
        },
      ),
    );
    await ensureAdminSchema(db);
    await ensureJpgInboxSchema(db);
    await ensureStage5ManagementSchema(db);
    manager = Stage5ManagementRepository(
      db, actor: 'Admin', device: 'device-adm',
    );
  });
  tearDown(() => db.close());

  test('exclusión reversible registra eventos auditables', () async {
    await manager.setIncluded(
      reportId: 'rep1', logicalId: 'logical1',
      date: '2026-11-09', stage: 'entry', included: false,
    );
    expect((await manager.exclusions('2026-11-09'))['rep1:logical1'], true);
    await manager.setIncluded(
      reportId: 'rep1', logicalId: 'logical1',
      date: '2026-11-09', stage: 'entry', included: true,
    );
    expect(await manager.exclusions('2026-11-09'), isEmpty);
    final event = await db.query('admin_events', orderBy: 'occurred_at');
    expect(event.map((e) => e['action']).toSet(),
      {'card_excluded','card_reincluded'});
    expect(await db.query('admin_stage5_exclusions'), hasLength(1));
  });

  test('JPG sueltos con fuente declarada son idempotentes e inmutables', () async {
    final data = {
      'date':'2026-11-09', 'stage':'exit',
      'source':'Supervisor B', 'name':'foto.jpg',
      'sha256':'a' * 64,
      'localPath':'artifacts/admin_stage5/loose/${'a' * 64}.jpg',
    };
    expect(await manager.importLoose(
      date:data['date']!, stage:data['stage']!, source:data['source']!,
      name:data['name']!, sha256:data['sha256']!,
      localPath:data['localPath']!,
    ), true);
    expect(await manager.importLoose(
      date:data['date']!, stage:data['stage']!, source:data['source']!,
      name:data['name']!, sha256:data['sha256']!,
      localPath:data['localPath']!,
    ), false);
    expect(await manager.looseImages('2026-11-09',stage:'exit'),hasLength(1));
    await expectLater(
      db.delete('admin_stage5_images'),
      throwsA(anything),
    );
  });

  test('no se admiten imágenes sin origen, etapa o fecha válida', () async {
    await expectLater(
      manager.importLoose(date:'2026-11-31', stage:'entry',source:'',
        name:'a.jpg',sha256:'0'*64,
        localPath:'artifacts/admin_stage5/loose/test.jpg'),
      throwsFormatException,
    );
  });
}
