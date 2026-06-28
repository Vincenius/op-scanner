import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:op_scanner/src/data/collection_repository.dart';
import 'package:op_scanner/src/data/local/database.dart';

/// Validates the offline-first collection logic (local write + enqueue) against
/// the real drift schema.
void main() {
  late AppDatabase db;
  late CollectionRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CollectionRepository(db);
    await db.batch((b) {
      b.insert(db.sets, SetsCompanion.insert(id: 's1', code: 'OP01', name: 'ROMANCE DAWN'));
      b.insert(db.cards, CardsCompanion.insert(
        id: 'c1', cardCode: 'OP01-016', name: 'Nami', colors: 'Red', type: 'CHARACTER', setId: 's1', setCode: 'OP01',
      ));
      b.insert(db.variants, VariantsCompanion.insert(
        variantId: 'OP01-016', cardId: 'c1', thumbUrl: '/t', fullUrl: '/f',
        marketPrice: const Value(3.59),
      ));
    });
  });

  tearDown(() => db.close());

  Future<List<CollectionEntry>> entries() => repo.watch(const CollectionFilter()).first;
  Future<int> queueLen() async => (await db.select(db.syncQueue).get()).length;

  test('adding twice increments one entry and enqueues it', () async {
    await repo.addOne('OP01-016');
    await repo.addOne('OP01-016');
    final list = await entries();
    expect(list, hasLength(1));
    expect(list.single.item.quantity, 2);
    expect(list.single.card.name, 'Nami');
    expect(await queueLen(), 1); // coalesced to one pending entry
  });

  test('setting quantity to 0 tombstones the entry (hidden from watch)', () async {
    await repo.addOne('OP01-016');
    final item = (await entries()).single.item;
    await repo.setQuantity(item, 0);
    expect(await entries(), isEmpty);

    // Tombstone row still exists with deletedAt set (for sync propagation).
    final raw = await (db.select(db.collectionItems)
          ..where((t) => t.clientUuid.equals(item.clientUuid)))
        .getSingle();
    expect(raw.deletedAt, isNotNull);
  });

  test('stats reflect quantity and value', () async {
    await repo.addOne('OP01-016');
    await repo.addOne('OP01-016');
    final stats = await repo.watchStats().first;
    expect(stats.count, 1);
    expect(stats.copies, 2);
    expect(stats.value, closeTo(7.18, 0.001)); // 3.59 * 2
  });
}
