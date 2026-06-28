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
  DateTimeColumn get lastSyncAt => dateTime().nullable()(); // catalog sync
  DateTimeColumn get collectionLastSyncAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// User collection (offline-first). Source of truth for the UI; edits write here
// immediately and enqueue the clientUuid in SyncQueue for the next flush.
@DataClassName('CollectionItemRow')
class CollectionItems extends Table {
  TextColumn get clientUuid => text()();
  TextColumn get variantId => text()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get condition => text().withDefault(const Constant('NM'))();
  BoolColumn get isFoil => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()(); // client logical version (LWW)
  DateTimeColumn get deletedAt => dateTime().nullable()(); // tombstone

  @override
  Set<Column> get primaryKey => {clientUuid};
}

// Coalesced pending-mutation set (one row per dirty collection entry).
@DataClassName('SyncQueueRow')
class SyncQueue extends Table {
  TextColumn get clientUuid => text()();
  DateTimeColumn get queuedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

@DriftDatabase(tables: [Sets, Cards, Variants, SyncMeta, CollectionItems, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(collectionItems);
            await m.createTable(syncQueue);
            await m.addColumn(syncMeta, syncMeta.collectionLastSyncAt);
          }
        },
      );

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

  Future<DateTime?> collectionLastSyncAt() async {
    final row = await (select(syncMeta)..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    return row?.collectionLastSyncAt;
  }

  Future<void> setCollectionLastSyncAt(DateTime when) async {
    await into(syncMeta).insertOnConflictUpdate(
      SyncMetaCompanion.insert(id: const Value(1), collectionLastSyncAt: Value(when)),
    );
  }

  Future<int> variantCount() async {
    final count = countAll();
    final row = await (selectOnly(variants)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Wipe local collection state (used on logout / account switch).
  Future<void> clearCollection() async {
    await transaction(() async {
      await delete(collectionItems).go();
      await delete(syncQueue).go();
      await (update(syncMeta)..where((t) => t.id.equals(1)))
          .write(const SyncMetaCompanion(collectionLastSyncAt: Value(null)));
    });
  }
}
