import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// Local mirror of the catalog (filled from GET /catalog/sync). The current
// price is denormalised onto the variant row for easy sort/filter/display.
// `phash` is reserved for Phase 3 (on-device recognition) and stays null for now.

@DataClassName('CardSet')
class Sets extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  DateTimeColumn get releaseDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CatalogCard')
class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get cardCode => text()();
  TextColumn get name => text()();
  TextColumn get colors => text()(); // comma-joined, e.g. "Red,Green"
  TextColumn get type => text()();
  IntColumn get cost => integer().nullable()();
  IntColumn get power => integer().nullable()();
  IntColumn get counter => integer().nullable()();
  TextColumn get attribute => text().nullable()();
  TextColumn get family => text().nullable()();
  TextColumn get abilityText => text().nullable()();
  TextColumn get triggerText => text().nullable()();
  TextColumn get setId => text()();
  TextColumn get setCode => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CatalogVariant')
class Variants extends Table {
  TextColumn get variantId => text()();
  TextColumn get cardId => text()();
  TextColumn get rarity => text().nullable()();
  BoolColumn get isAltArt => boolean().withDefault(const Constant(false))();
  TextColumn get variantLabel => text().nullable()();
  TextColumn get thumbUrl => text()(); // server-relative proxy path
  TextColumn get fullUrl => text()();
  RealColumn get marketPrice => real().nullable()();
  RealColumn get lowPrice => real().nullable()();
  TextColumn get priceCurrency => text().nullable()();
  DateTimeColumn get priceCapturedAt => dateTime().nullable()();
  TextColumn get phash => text().nullable()(); // Phase 3

  @override
  Set<Column> get primaryKey => {variantId};
}

@DataClassName('SyncMetaRow')
class SyncMeta extends Table {
  IntColumn get id => integer()(); // singleton row, always 1
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Sets, Cards, Variants, SyncMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() => driftDatabase(
        name: 'op_scanner',
        // Web needs the wasm engine + worker (assets live in app/web/).
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      );

  Future<DateTime?> lastSyncAt() async {
    final row = await (select(syncMeta)..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    return row?.lastSyncAt;
  }

  Future<void> setLastSyncAt(DateTime when) async {
    await into(syncMeta).insertOnConflictUpdate(
      SyncMetaCompanion.insert(id: const Value(1), lastSyncAt: Value(when)),
    );
  }

  Future<int> variantCount() async {
    final count = countAll();
    final row = await (selectOnly(variants)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }
}
