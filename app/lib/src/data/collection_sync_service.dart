import 'package:drift/drift.dart';

import 'local/database.dart';
import 'remote/api_client.dart';

/// Flushes queued local mutations to the server and applies the authoritative
/// response. LWW + idempotency live on the server; the client only needs to
/// send its dirty entries and reconcile what comes back.
class CollectionSyncService {
  CollectionSyncService(this._db, this._api);
  final AppDatabase _db;
  final ApiClient _api;

  Future<void> flush() async {
    // 1) Snapshot the pending set (clientUuid -> queuedAt).
    final queued = await _db.select(_db.syncQueue).get();
    final queuedAt = {for (final q in queued) q.clientUuid: q.queuedAt};

    // 2) Build mutations from the current state of those entries.
    final mutations = <Map<String, dynamic>>[];
    if (queued.isNotEmpty) {
      final ids = queuedAt.keys.toList();
      final items = await (_db.select(_db.collectionItems)
            ..where((t) => t.clientUuid.isIn(ids)))
          .get();
      for (final it in items) {
        mutations.add(_toMutation(it));
      }
    }

    // 3) Sync (server applies + returns authoritative items since `since`).
    final since = await _db.collectionLastSyncAt();
    final resp = await _api.collectionSync(since, mutations);
    final serverTime = DateTime.parse(resp['serverTime'] as String);
    final items = (resp['items'] as List).cast<Map<String, dynamic>>();

    // 4) Reconcile.
    await _db.transaction(() async {
      // Clear flushed entries from the queue — but only if they weren't
      // re-dirtied during the request (queuedAt unchanged).
      for (final entry in queuedAt.entries) {
        await (_db.delete(_db.syncQueue)
              ..where((t) =>
                  t.clientUuid.equals(entry.key) &
                  t.queuedAt.equals(entry.value)))
            .go();
      }
      final stillQueued = {
        for (final q in await _db.select(_db.syncQueue).get()) q.clientUuid
      };

      // Apply authoritative items, except ones with newer local pending edits.
      for (final i in items) {
        final clientUuid = i['clientUuid'] as String;
        if (stillQueued.contains(clientUuid)) continue;
        await _db.into(_db.collectionItems).insertOnConflictUpdate(
              CollectionItemRow(
                clientUuid: clientUuid,
                variantId: i['variantId'] as String,
                quantity: i['quantity'] as int,
                condition: i['condition'] as String,
                isFoil: i['isFoil'] as bool,
                notes: i['notes'] as String?,
                addedAt: DateTime.parse(i['addedAt'] as String),
                updatedAt: DateTime.parse(i['updatedAt'] as String),
                deletedAt: i['deletedAt'] != null
                    ? DateTime.parse(i['deletedAt'] as String)
                    : null,
              ),
            );
      }

      await _db.setCollectionLastSyncAt(serverTime);
    });
  }

  Map<String, dynamic> _toMutation(CollectionItemRow it) => {
        'clientUuid': it.clientUuid,
        'variantId': it.variantId,
        'quantity': it.quantity,
        'condition': it.condition,
        'isFoil': it.isFoil,
        'notes': it.notes,
        'updatedAt': it.updatedAt.toUtc().toIso8601String(),
        'deleted': it.deletedAt != null,
      };
}
