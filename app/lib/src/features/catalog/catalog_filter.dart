import 'package:flutter/foundation.dart';

enum CatalogSort {
  codeAsc('Code'),
  nameAsc('Name'),
  priceDesc('Price ↓'),
  priceAsc('Price ↑');

  const CatalogSort(this.label);
  final String label;
}

@immutable
class CatalogFilter {
  const CatalogFilter({
    this.query = '',
    this.setCode,
    this.color,
    this.type,
    this.rarity,
    this.altArtOnly = false,
    this.sort = CatalogSort.codeAsc,
  });

  final String query;
  final String? setCode;
  final String? color;
  final String? type;
  final String? rarity;
  final bool altArtOnly;
  final CatalogSort sort;

  bool get hasActiveFacets =>
      setCode != null ||
      color != null ||
      type != null ||
      rarity != null ||
      altArtOnly;

  int get activeFacetCount => [
        setCode,
        color,
        type,
        rarity,
        altArtOnly ? 'alt' : null,
      ].where((e) => e != null).length;

  CatalogFilter copyWith({
    String? query,
    Object? setCode = _sentinel,
    Object? color = _sentinel,
    Object? type = _sentinel,
    Object? rarity = _sentinel,
    bool? altArtOnly,
    CatalogSort? sort,
  }) {
    return CatalogFilter(
      query: query ?? this.query,
      setCode: setCode == _sentinel ? this.setCode : setCode as String?,
      color: color == _sentinel ? this.color : color as String?,
      type: type == _sentinel ? this.type : type as String?,
      rarity: rarity == _sentinel ? this.rarity : rarity as String?,
      altArtOnly: altArtOnly ?? this.altArtOnly,
      sort: sort ?? this.sort,
    );
  }

  CatalogFilter clearedFacets() => CatalogFilter(query: query, sort: sort);

  static const Object _sentinel = Object();
}
