import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/auth/auth_repository.dart';
import 'data/auth/auth_storage.dart';
import 'data/catalog_repository.dart';
import 'data/collection_repository.dart';
import 'data/collection_sync_service.dart';
import 'data/local/database.dart';
import 'data/remote/api_client.dart';
import 'data/sync_service.dart';
import 'features/catalog/catalog_filter.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

final apiClientProvider =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(authStorageProvider)));

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(authStorageProvider)),
);

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => CollectionRepository(ref.watch(databaseProvider)),
);

final collectionSyncServiceProvider = Provider<CollectionSyncService>(
  (ref) => CollectionSyncService(ref.watch(databaseProvider), ref.watch(apiClientProvider)),
);

/// Active collection filter.
final collectionFilterProvider =
    NotifierProvider<CollectionFilterNotifier, CollectionFilter>(CollectionFilterNotifier.new);

class CollectionFilterNotifier extends Notifier<CollectionFilter> {
  @override
  CollectionFilter build() => const CollectionFilter();
  void setQuery(String q) => state = state.copyWith(query: q);
  void setSort(CollectionSort s) => state = state.copyWith(sort: s);
  void setCondition(String? c) => state = state.copyWith(condition: c);
}

final collectionEntriesProvider = StreamProvider<List<CollectionEntry>>((ref) {
  final filter = ref.watch(collectionFilterProvider);
  return ref.watch(collectionRepositoryProvider).watch(filter);
});

final collectionStatsProvider =
    StreamProvider<({int count, int copies, double value})>(
  (ref) => ref.watch(collectionRepositoryProvider).watchStats(),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(databaseProvider)),
);

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(ref.watch(databaseProvider), ref.watch(apiClientProvider)),
);

/// Number of variants currently mirrored locally (drives the "synced?" state).
final localVariantCountProvider = FutureProvider<int>(
  (ref) => ref.watch(databaseProvider).variantCount(),
);

final lastSyncProvider = FutureProvider<DateTime?>(
  (ref) => ref.watch(databaseProvider).lastSyncAt(),
);

/// Active catalog filter.
final filterProvider =
    NotifierProvider<FilterNotifier, CatalogFilter>(FilterNotifier.new);

class FilterNotifier extends Notifier<CatalogFilter> {
  @override
  CatalogFilter build() => const CatalogFilter();

  void setQuery(String q) => state = state.copyWith(query: q);
  void setSort(CatalogSort sort) => state = state.copyWith(sort: sort);
  void setSet(String? code) => state = state.copyWith(setCode: code);
  void setColor(String? color) => state = state.copyWith(color: color);
  void setType(String? type) => state = state.copyWith(type: type);
  void setRarity(String? rarity) => state = state.copyWith(rarity: rarity);
  void setAltArtOnly(bool v) => state = state.copyWith(altArtOnly: v);
  void clearFacets() => state = state.clearedFacets();
}

/// Reactive catalog list — re-queries on filter change and on any DB write
/// (drift `watch`), so it refreshes automatically after a sync.
final catalogItemsProvider = StreamProvider<List<CatalogItem>>((ref) {
  final filter = ref.watch(filterProvider);
  return ref.watch(catalogRepositoryProvider).watch(filter);
});

/// Facet option lists for the filter sheet.
final facetOptionsProvider = FutureProvider<FacetOptions>((ref) async {
  // Recompute when the local data changes.
  ref.watch(catalogItemsProvider);
  final repo = ref.watch(catalogRepositoryProvider);
  final results = await Future.wait([
    repo.setCodes(),
    repo.colors(),
    repo.types(),
    repo.rarities(),
  ]);
  return FacetOptions(
    sets: results[0],
    colors: results[1],
    types: results[2],
    rarities: results[3],
  );
});

class FacetOptions {
  const FacetOptions({
    required this.sets,
    required this.colors,
    required this.types,
    required this.rarities,
  });
  final List<String> sets;
  final List<String> colors;
  final List<String> types;
  final List<String> rarities;
}

/// Sync controller exposing progress for the UI.
final syncControllerProvider =
    NotifierProvider<SyncController, SyncUiState>(SyncController.new);

class SyncUiState {
  const SyncUiState({this.running = false, this.progress, this.error});
  final bool running;
  final SyncProgress? progress;
  final Object? error;
}

class SyncController extends Notifier<SyncUiState> {
  @override
  SyncUiState build() => const SyncUiState();

  Future<void> sync() async {
    if (state.running) return;
    state = const SyncUiState(running: true);
    try {
      await ref.read(syncServiceProvider).sync(
            onProgress: (p) => state = SyncUiState(running: true, progress: p),
          );
      // Refresh derived "synced?" providers.
      ref.invalidate(localVariantCountProvider);
      ref.invalidate(lastSyncProvider);
      state = const SyncUiState();
    } catch (err) {
      state = SyncUiState(error: err);
    }
  }
}
