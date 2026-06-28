import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:op_scanner/src/data/catalog_repository.dart';
import 'package:op_scanner/src/data/local/database.dart';
import 'package:op_scanner/src/features/catalog/catalog_filter.dart';

/// Validates the offline browse/filter logic against the real drift schema
/// (the core of CHECKPOINT 1), using an in-memory database.
void main() {
  late AppDatabase db;
  late CatalogRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CatalogRepository(db);

    await db.batch((b) {
      b.insert(db.sets,
          SetsCompanion.insert(id: 's1', code: 'OP01', name: 'ROMANCE DAWN'));
      b.insert(db.sets,
          SetsCompanion.insert(id: 's2', code: 'ST01', name: 'STRAW HAT CREW'));
      b.insert(
        db.cards,
        CardsCompanion.insert(
          id: 'c1',
          cardCode: 'OP01-016',
          name: 'Nami',
          colors: 'Red',
          type: 'CHARACTER',
          setId: 's1',
          setCode: 'OP01',
        ),
      );
      b.insert(
        db.cards,
        CardsCompanion.insert(
          id: 'c2',
          cardCode: 'ST01-001',
          name: 'Monkey.D.Luffy',
          colors: 'Red',
          type: 'LEADER',
          setId: 's2',
          setCode: 'ST01',
        ),
      );
      // Nami base + parallel with distinct prices (alt-art correctness)
      b.insert(
        db.variants,
        VariantsCompanion.insert(
          variantId: 'OP01-016',
          cardId: 'c1',
          thumbUrl: '/img/variants/OP01-016/thumb',
          fullUrl: '/img/variants/OP01-016/full',
          rarity: const Value('R'),
          marketPrice: const Value(3.59),
        ),
      );
      b.insert(
        db.variants,
        VariantsCompanion.insert(
          variantId: 'OP01-016_p1',
          cardId: 'c1',
          thumbUrl: '/img/variants/OP01-016_p1/thumb',
          fullUrl: '/img/variants/OP01-016_p1/full',
          rarity: const Value('R'),
          isAltArt: const Value(true),
          variantLabel: const Value('Parallel'),
          marketPrice: const Value(377.40),
        ),
      );
      b.insert(
        db.variants,
        VariantsCompanion.insert(
          variantId: 'ST01-001',
          cardId: 'c2',
          thumbUrl: '/img/variants/ST01-001/thumb',
          fullUrl: '/img/variants/ST01-001/full',
          rarity: const Value('L'),
          marketPrice: const Value(2.50),
        ),
      );
    });
  });

  tearDown(() => db.close());

  Future<List<CatalogItem>> first(CatalogFilter f) => repo.watch(f).first;

  test('lists every variant (base + alt-art) by default', () async {
    final items = await first(const CatalogFilter());
    expect(items, hasLength(3));
  });

  test('text search matches name, card code, and variant id', () async {
    expect(await first(const CatalogFilter(query: 'nami')), hasLength(2));
    expect(await first(const CatalogFilter(query: 'ST01')), hasLength(1));
    expect(await first(const CatalogFilter(query: '_p1')), hasLength(1));
  });

  test('facets filter by set, type, rarity, alt-art', () async {
    expect(await first(const CatalogFilter(setCode: 'OP01')), hasLength(2));
    expect(await first(const CatalogFilter(type: 'LEADER')), hasLength(1));
    expect(await first(const CatalogFilter(rarity: 'L')), hasLength(1));
    expect(await first(const CatalogFilter(altArtOnly: true)), hasLength(1));
  });

  test('sort by price desc puts the parallel first', () async {
    final items = await first(const CatalogFilter(sort: CatalogSort.priceDesc));
    expect(items.first.variant.variantId, 'OP01-016_p1');
    expect(items.first.variant.marketPrice, 377.40);
  });

  test('facet option lists are derived from local data', () async {
    expect(await repo.setCodes(), containsAll(['OP01', 'ST01']));
    expect(await repo.types(), containsAll(['CHARACTER', 'LEADER']));
    expect(await repo.rarities(), containsAll(['L', 'R']));
    expect(await repo.colors(), contains('Red'));
  });
}
