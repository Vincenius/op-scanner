import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'auth/auth_controller.dart';
import 'local/database.dart';

class CollectionSyncState {
  const CollectionSyncState({this.running = false, this.error});
  final bool running;
  final Object? error;
}

/// Drives collection sync (flush queued mutations + pull authoritative state).
final collectionSyncControllerProvider =
    NotifierProvider<CollectionSyncController, CollectionSyncState>(
  CollectionSyncController.new,
);

class CollectionSyncController extends Notifier<CollectionSyncState> {
  bool _again = false;

  @override
  CollectionSyncState build() => const CollectionSyncState();

  Future<void> sync() async {
    if (!ref.read(authControllerProvider).isAuthenticated) return;
    // A mutation made while a flush is in flight re-arms the loop so it isn't
    // lost until the next manual trigger.
    if (state.running) {
      _again = true;
      return;
    }
    state = const CollectionSyncState(running: true);
    try {
      do {
        _again = false;
        await ref.read(collectionSyncServiceProvider).flush();
      } while (_again);
      state = const CollectionSyncState();
    } catch (err) {
      // Offline / transient — mutations stay queued for the next flush.
      state = CollectionSyncState(error: err);
    }
  }
}

/// Collection mutations: write locally, then flush in the background.
final collectionActionsProvider = Provider<CollectionActions>(
  (ref) => CollectionActions(ref),
);

class CollectionActions {
  CollectionActions(this._ref);
  final Ref _ref;

  Future<void> add(String variantId, {String condition = 'NM', bool isFoil = false}) async {
    await _ref.read(collectionRepositoryProvider).addOne(variantId, condition: condition, isFoil: isFoil);
    _flush();
  }

  /// Add a scanned card and apply the active scan tag (if any).
  Future<void> addScanned(String variantId, {String? tagClientUuid, String condition = 'NM'}) async {
    final repo = _ref.read(collectionRepositoryProvider);
    final itemUuid = await repo.addOne(variantId, condition: condition);
    if (tagClientUuid != null) {
      final current = await repo.liveTagUuidsFor(itemUuid);
      if (!current.contains(tagClientUuid)) {
        await repo.setItemTags(itemUuid, [...current, tagClientUuid]);
      }
    }
    _flush();
  }

  Future<void> setQuantity(CollectionItemRow item, int quantity) async {
    await _ref.read(collectionRepositoryProvider).setQuantity(item, quantity);
    _flush();
  }

  Future<void> setCondition(CollectionItemRow item, String condition) async {
    await _ref.read(collectionRepositoryProvider).setCondition(item, condition);
    _flush();
  }

  Future<void> remove(CollectionItemRow item) async {
    await _ref.read(collectionRepositoryProvider).remove(item);
    _flush();
  }

  /// Set the tags assigned to a collection entry.
  Future<void> setItemTags(String itemClientUuid, List<String> tagClientUuids) async {
    await _ref.read(collectionRepositoryProvider).setItemTags(itemClientUuid, tagClientUuids);
    _flush();
  }

  // --- Tags ---
  Future<String> createTag(String name, {String? color}) async {
    final clientUuid = await _ref.read(tagRepositoryProvider).create(name, color: color);
    _flush();
    return clientUuid;
  }

  Future<void> renameTag(TagRow tag, String name) async {
    await _ref.read(tagRepositoryProvider).rename(tag, name);
    _flush();
  }

  Future<void> deleteTag(TagRow tag) async {
    await _ref.read(tagRepositoryProvider).delete(tag);
    _flush();
  }

  void _flush() {
    // Fire-and-forget; failures keep the entry queued.
    Future.microtask(() => _ref.read(collectionSyncControllerProvider.notifier).sync());
  }
}
