import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'local/database.dart';

/// A collection entry joined with its variant + card and its (live) tags.
class CollectionEntry {
  const CollectionEntry(this.item, this.variant, this.card, this.tags);
  final CollectionItemRow item;
  final CatalogVariant variant;
  final CatalogCard card;
  final List<TagRow> tags;
}

enum CollectionSort { addedDesc, name, priceDesc, priceAsc, quantityDesc }

class CollectionFilter {
  const CollectionFilter({
    this.query = '',
    this.condition,
    this.tagClientUuid,
    this.sort = CollectionSort.addedDesc,
  });
  final String query;
  final String? condition;
  final String? tagClientUuid;
  final CollectionSort sort;

  CollectionFilter copyWith({
    String? query,
    Object? condition = _s,
    Object? tagClientUuid = _s,
    CollectionSort? sort,
  }) =>
      CollectionFilter(
        query: query ?? this.query,
        condition: condition == _s ? this.condition : condition as String?,
        tagClientUuid: tagClientUuid == _s ? this.tagClientUuid : tagClientUuid as String?,
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
  /// Returns the entry's clientUuid (so a caller can immediately tag it).
  Future<String> addOne(String variantId, {String condition = 'NM', bool isFoil = false}) async {
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
      return existing.clientUuid;
    }
    final clientUuid = _uuid.v4();
    await _write(CollectionItemRow(
      clientUuid: clientUuid,
      variantId: variantId,
      quantity: 1,
      condition: condition,
      isFoil: isFoil,
      notes: null,
      addedAt: now,
      updatedAt: now,
      deletedAt: null,
    ));
    return clientUuid;
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

  /// Replace an entry's tag set; touches updatedAt so the assignment syncs.
  Future<void> setItemTags(String itemClientUuid, List<String> tagClientUuids) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.delete(_db.collectionItemTags)
            ..where((t) => t.itemClientUuid.equals(itemClientUuid)))
          .go();
      for (final tu in tagClientUuids.toSet()) {
        await _db.into(_db.collectionItemTags).insertOnConflictUpdate(
              CollectionItemTagRow(itemClientUuid: itemClientUuid, tagClientUuid: tu),
            );
      }
      await (_db.update(_db.collectionItems)..where((t) => t.clientUuid.equals(itemClientUuid)))
          .write(CollectionItemsCompanion(updatedAt: Value(now)));
      await _db.into(_db.syncQueue).insertOnConflictUpdate(
            SyncQueueRow(clientUuid: itemClientUuid, queuedAt: now),
          );
    });
  }

  /// Non-deleted tag clientUuids linked to an entry (for building sync mutations).
  Future<List<String>> liveTagUuidsFor(String itemClientUuid) async {
    final q = _db.select(_db.collectionItemTags).join([
      innerJoin(
        _db.tags,
        _db.tags.clientUuid.equalsExp(_db.collectionItemTags.tagClientUuid) &
            _db.tags.deletedAt.isNull(),
      ),
    ])
      ..where(_db.collectionItemTags.itemClientUuid.equals(itemClientUuid));
    final rows = await q.get();
    return rows.map((r) => r.readTable(_db.collectionItemTags).tagClientUuid).toList();
  }

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
      leftOuterJoin(_db.collectionItemTags,
          _db.collectionItemTags.itemClientUuid.equalsExp(_db.collectionItems.clientUuid)),
      leftOuterJoin(_db.tags,
          _db.tags.clientUuid.equalsExp(_db.collectionItemTags.tagClientUuid) & _db.tags.deletedAt.isNull()),
    ])
      ..where(_db.collectionItems.deletedAt.isNull());

    if (f.condition != null) q.where(_db.collectionItems.condition.equals(f.condition!));
    final query = f.query.trim();
    if (query.isNotEmpty) {
      final like = '%$query%';
      q.where(_db.cards.name.like(like) |
          _db.cards.cardCode.like(like) |
          _db.collectionItems.variantId.like(like));
    }

    return q.watch().map((rows) {
      // Group the (item × tag) rows back into one entry per item.
      final items = <String, ({CollectionItemRow item, CatalogVariant v, CatalogCard c})>{};
      final tagsByItem = <String, List<TagRow>>{};
      for (final r in rows) {
        final item = r.readTable(_db.collectionItems);
        items.putIfAbsent(item.clientUuid,
            () => (item: item, v: r.readTable(_db.variants), c: r.readTable(_db.cards)));
        tagsByItem.putIfAbsent(item.clientUuid, () => []);
        final tag = r.readTableOrNull(_db.tags);
        if (tag != null) tagsByItem[item.clientUuid]!.add(tag);
      }

      var entries = items.values.map((e) {
        final tags = (tagsByItem[e.item.clientUuid] ?? [])..sort((a, b) => a.name.compareTo(b.name));
        return CollectionEntry(e.item, e.v, e.c, tags);
      }).toList();

      if (f.tagClientUuid != null) {
        entries = entries
            .where((e) => e.tags.any((t) => t.clientUuid == f.tagClientUuid))
            .toList();
      }

      double price(CollectionEntry e) => e.variant.marketPrice ?? -1;
      switch (f.sort) {
        case CollectionSort.addedDesc:
          entries.sort((a, b) => b.item.addedAt.compareTo(a.item.addedAt));
        case CollectionSort.name:
          entries.sort((a, b) => a.card.name.compareTo(b.card.name));
        case CollectionSort.priceDesc:
          entries.sort((a, b) => price(b).compareTo(price(a)));
        case CollectionSort.priceAsc:
          entries.sort((a, b) => price(a).compareTo(price(b)));
        case CollectionSort.quantityDesc:
          entries.sort((a, b) => b.item.quantity.compareTo(a.item.quantity));
      }
      return entries;
    });
  }

  /// Distinct (live) tags across the user's owned entries of a variant.
  /// Powers "this card is in: Green Deck Box, Blue Box" on the card detail.
  Stream<List<TagRow>> watchTagsForVariant(String variantId) {
    final q = _db.select(_db.collectionItems).join([
      innerJoin(_db.collectionItemTags,
          _db.collectionItemTags.itemClientUuid.equalsExp(_db.collectionItems.clientUuid)),
      innerJoin(_db.tags,
          _db.tags.clientUuid.equalsExp(_db.collectionItemTags.tagClientUuid) & _db.tags.deletedAt.isNull()),
    ])
      ..where(_db.collectionItems.variantId.equals(variantId) & _db.collectionItems.deletedAt.isNull());
    return q.watch().map((rows) {
      final seen = <String, TagRow>{};
      for (final r in rows) {
        final t = r.readTable(_db.tags);
        seen[t.clientUuid] = t;
      }
      return seen.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    });
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
