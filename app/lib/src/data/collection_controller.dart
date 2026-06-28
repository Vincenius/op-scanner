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
  @override
  CollectionSyncState build() => const CollectionSyncState();

  Future<void> sync() async {
    if (state.running) return;
    if (!ref.read(authControllerProvider).isAuthenticated) return;
    state = const CollectionSyncState(running: true);
    try {
      await ref.read(collectionSyncServiceProvider).flush();
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

  void _flush() {
    // Fire-and-forget; failures keep the entry queued.
    Future.microtask(() => _ref.read(collectionSyncControllerProvider.notifier).sync());
  }
}
