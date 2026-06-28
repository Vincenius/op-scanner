import 'package:drift/drift.dart';

import '../features/catalog/catalog_filter.dart';
import 'local/database.dart';

/// A browsable catalog entry: one card_variant joined with its card.
class CatalogItem {
  const CatalogItem(this.variant, this.card);
  final CatalogVariant variant;
  final CatalogCard card;

  List<String> get colors =>
      card.colors.isEmpty ? const [] : card.colors.split(',');
  String get displayName => card.name;
  bool get hasPrice => variant.marketPrice != null;
}

class CatalogRepository {
  CatalogRepository(this._db);
  final AppDatabase _db;

  Stream<List<CatalogItem>> watch(CatalogFilter f) {
    final q = _db.select(_db.variants).join([
      innerJoin(_db.cards, _db.cards.id.equalsExp(_db.variants.cardId)),
    ]);

    final preds = <Expression<bool>>[];
    if (f.setCode != null) preds.add(_db.cards.setCode.equals(f.setCode!));
    if (f.type != null) preds.add(_db.cards.type.equals(f.type!));
    if (f.rarity != null) preds.add(_db.variants.rarity.equals(f.rarity!));
    if (f.color != null) preds.add(_db.cards.colors.like('%${f.color}%'));
    if (f.altArtOnly) preds.add(_db.variants.isAltArt.equals(true));
    final query = f.query.trim();
    if (query.isNotEmpty) {
      final like = '%$query%';
      preds.add(_db.cards.name.like(like) |
          _db.cards.cardCode.like(like) |
          _db.variants.variantId.like(like));
    }
    if (preds.isNotEmpty) {
      q.where(preds.reduce((a, b) => a & b));
    }

    switch (f.sort) {
      case CatalogSort.codeAsc:
        q.orderBy([OrderingTerm.asc(_db.variants.variantId)]);
      case CatalogSort.nameAsc:
        q.orderBy([
          OrderingTerm.asc(_db.cards.name),
          OrderingTerm.asc(_db.variants.variantId),
        ]);
      case CatalogSort.priceDesc:
        q.orderBy([
          OrderingTerm(
            expression: _db.variants.marketPrice,
            mode: OrderingMode.desc,
            nulls: NullsOrder.last,
          ),
        ]);
      case CatalogSort.priceAsc:
        q.orderBy([
          OrderingTerm(
            expression: _db.variants.marketPrice,
            mode: OrderingMode.asc,
            nulls: NullsOrder.last,
          ),
        ]);
    }

    return q.watch().map((rows) => rows
        .map((r) =>
            CatalogItem(r.readTable(_db.variants), r.readTable(_db.cards)))
        .toList());
  }

  /// All variants of a card (for the detail screen), base printing first.
  Stream<List<CatalogVariant>> watchVariantsForCard(String cardId) {
    final q = _db.select(_db.variants)
      ..where((v) => v.cardId.equals(cardId))
      ..orderBy([(v) => OrderingTerm.asc(v.variantId)]);
    return q.watch();
  }

  Future<CatalogCard?> cardById(String cardId) =>
      (_db.select(_db.cards)..where((c) => c.id.equals(cardId)))
          .getSingleOrNull();

  Future<List<String>> _distinct(String sql) async {
    final rows = await _db.customSelect(sql).get();
    return rows.map((r) => r.read<String>('v')).toList();
  }

  Future<List<String>> setCodes() =>
      _distinct("SELECT DISTINCT set_code AS v FROM cards WHERE set_code != '' ORDER BY v");
  Future<List<String>> rarities() => _distinct(
      "SELECT DISTINCT rarity AS v FROM variants WHERE rarity IS NOT NULL AND rarity != '' ORDER BY v");
  Future<List<String>> types() =>
      _distinct("SELECT DISTINCT type AS v FROM cards ORDER BY v");

  /// Colors are comma-joined on the card row, so split client-side.
  Future<List<String>> colors() async {
    final rows = await _db
        .customSelect("SELECT DISTINCT colors FROM cards WHERE colors != ''")
        .get();
    final set = <String>{};
    for (final r in rows) {
      set.addAll(r.read<String>('colors').split(','));
    }
    final list = set.toList()..sort();
    return list;
  }
}
