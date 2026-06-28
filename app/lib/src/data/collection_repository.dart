import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'local/database.dart';

/// A collection entry joined with its variant + card for display.
class CollectionEntry {
  const CollectionEntry(this.item, this.variant, this.card);
  final CollectionItemRow item;
  final CatalogVariant variant;
  final CatalogCard card;
}

enum CollectionSort { addedDesc, name, priceDesc, priceAsc, quantityDesc }

class CollectionFilter {
  const CollectionFilter({this.query = '', this.condition, this.sort = CollectionSort.addedDesc});
  final String query;
  final String? condition;
  final CollectionSort sort;

  CollectionFilter copyWith({String? query, Object? condition = _s, CollectionSort? sort}) =>
      CollectionFilter(
        query: query ?? this.query,
        condition: condition == _s ? this.condition : condition as String?,
        sort: sort ?? this.sort,
      );
  static const Object _s = Object();
}

/// Local-first collection store. Writes apply immediately and enqueue the
/// entry's clientUuid for the next sync flush.
class CollectionRepository {
  CollectionRepository(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();
  final AppDatabase _db;
  final Uuid _uuid;

  /// Add one copy of a variant (increments an existing matching entry).
  Future<void> addOne(String variantId, {String condition = 'NM', bool isFoil = false}) async {
    final existing = await (_db.select(_db.collectionItems)
          ..where((t) =>
              t.variantId.equals(variantId) &
              t.condition.equals(condition) &
              t.isFoil.equals(isFoil) &
              t.deletedAt.isNull()))
        .getSingleOrNull();
    final now = DateTime.now().toUtc();
    if (existing != null) {
      await _write(existing.copyWith(quantity: existing.quantity + 1, updatedAt: now));
    } else {
      await _write(CollectionItemRow(
        clientUuid: _uuid.v4(),
        variantId: variantId,
        quantity: 1,
        condition: condition,
        isFoil: isFoil,
        notes: null,
        addedAt: now,
        updatedAt: now,
        deletedAt: null,
      ));
    }
  }

  Future<void> setQuantity(CollectionItemRow item, int quantity) async {
    final now = DateTime.now().toUtc();
    if (quantity <= 0) {
      await _write(item.copyWith(deletedAt: Value(now), updatedAt: now));
    } else {
      await _write(item.copyWith(quantity: quantity, updatedAt: now));
    }
  }

  Future<void> setCondition(CollectionItemRow item, String condition) =>
      _write(item.copyWith(condition: condition, updatedAt: DateTime.now().toUtc()));

  Future<void> remove(CollectionItemRow item) =>
      _write(item.copyWith(deletedAt: Value(DateTime.now().toUtc()), updatedAt: DateTime.now().toUtc()));

  Future<void> _write(CollectionItemRow row) async {
    await _db.transaction(() async {
      await _db.into(_db.collectionItems).insertOnConflictUpdate(row);
      await _db.into(_db.syncQueue).insertOnConflictUpdate(
            SyncQueueRow(clientUuid: row.clientUuid, queuedAt: DateTime.now().toUtc()),
          );
    });
  }

  Stream<List<CollectionEntry>> watch(CollectionFilter f) {
    final q = _db.select(_db.collectionItems).join([
      innerJoin(_db.variants, _db.variants.variantId.equalsExp(_db.collectionItems.variantId)),
      innerJoin(_db.cards, _db.cards.id.equalsExp(_db.variants.cardId)),
    ])
      ..where(_db.collectionItems.deletedAt.isNull());

    if (f.condition != null) {
      q.where(_db.collectionItems.condition.equals(f.condition!));
    }
    final query = f.query.trim();
    if (query.isNotEmpty) {
      final like = '%$query%';
      q.where(_db.cards.name.like(like) |
          _db.cards.cardCode.like(like) |
          _db.collectionItems.variantId.like(like));
    }

    switch (f.sort) {
      case CollectionSort.addedDesc:
        q.orderBy([OrderingTerm.desc(_db.collectionItems.addedAt)]);
      case CollectionSort.name:
        q.orderBy([OrderingTerm.asc(_db.cards.name)]);
      case CollectionSort.priceDesc:
        q.orderBy([OrderingTerm(expression: _db.variants.marketPrice, mode: OrderingMode.desc, nulls: NullsOrder.last)]);
      case CollectionSort.priceAsc:
        q.orderBy([OrderingTerm(expression: _db.variants.marketPrice, mode: OrderingMode.asc, nulls: NullsOrder.last)]);
      case CollectionSort.quantityDesc:
        q.orderBy([OrderingTerm.desc(_db.collectionItems.quantity)]);
    }

    return q.watch().map((rows) => rows
        .map((r) => CollectionEntry(
              r.readTable(_db.collectionItems),
              r.readTable(_db.variants),
              r.readTable(_db.cards),
            ))
        .toList());
  }

  /// Aggregate stats for the collection header.
  Stream<({int count, int copies, double value})> watchStats() {
    final q = _db.select(_db.collectionItems).join([
      innerJoin(_db.variants, _db.variants.variantId.equalsExp(_db.collectionItems.variantId)),
    ])
      ..where(_db.collectionItems.deletedAt.isNull());
    return q.watch().map((rows) {
      var copies = 0;
      var value = 0.0;
      for (final r in rows) {
        final item = r.readTable(_db.collectionItems);
        final v = r.readTable(_db.variants);
        copies += item.quantity;
        value += (v.marketPrice ?? 0) * item.quantity;
      }
      return (count: rows.length, copies: copies, value: value);
    });
  }
}
