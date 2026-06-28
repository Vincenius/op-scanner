import 'package:drift/drift.dart';

import 'local/database.dart';
import 'remote/api_client.dart';

/// Flushes queued tag + collection mutations to the server and applies the
/// authoritative response. LWW + idempotency live on the server.
class CollectionSyncService {
  CollectionSyncService(this._db, this._api);
  final AppDatabase _db;
  final ApiClient _api;

  Future<void> flush() async {
    // --- Snapshot pending tags + items ---
    final tagQueue = await _db.select(_db.tagSyncQueue).get();
    final tagQueuedAt = {for (final q in tagQueue) q.clientUuid: q.queuedAt};
    final tagMutations = <Map<String, dynamic>>[];
    if (tagQueue.isNotEmpty) {
      final rows = await (_db.select(_db.tags)
            ..where((t) => t.clientUuid.isIn(tagQueuedAt.keys.toList())))
          .get();
      for (final t in rows) {
        tagMutations.add({
          'clientUuid': t.clientUuid,
          'name': t.name,
          'color': t.color,
          'updatedAt': t.updatedAt.toUtc().toIso8601String(),
          'deleted': t.deletedAt != null,
        });
      }
    }

    final itemQueue = await _db.select(_db.syncQueue).get();
    final itemQueuedAt = {for (final q in itemQueue) q.clientUuid: q.queuedAt};
    final mutations = <Map<String, dynamic>>[];
    if (itemQueue.isNotEmpty) {
      final items = await (_db.select(_db.collectionItems)
            ..where((t) => t.clientUuid.isIn(itemQueuedAt.keys.toList())))
          .get();
      for (final it in items) {
        mutations.add({
          'clientUuid': it.clientUuid,
          'variantId': it.variantId,
          'quantity': it.quantity,
          'condition': it.condition,
          'isFoil': it.isFoil,
          'notes': it.notes,
          'tagClientUuids': await _liveTagUuids(it.clientUuid),
          'updatedAt': it.updatedAt.toUtc().toIso8601String(),
          'deleted': it.deletedAt != null,
        });
      }
    }

    // --- Sync ---
    final since = await _db.collectionLastSyncAt();
    final resp = await _api.collectionSync(since, tagMutations, mutations);
    final serverTime = DateTime.parse(resp['serverTime'] as String);
    final respTags = (resp['tags'] as List).cast<Map<String, dynamic>>();
    final respItems = (resp['items'] as List).cast<Map<String, dynamic>>();

    // --- Reconcile ---
    await _db.transaction(() async {
      for (final e in tagQueuedAt.entries) {
        await (_db.delete(_db.tagSyncQueue)
              ..where((t) => t.clientUuid.equals(e.key) & t.queuedAt.equals(e.value)))
            .go();
      }
      for (final e in itemQueuedAt.entries) {
        await (_db.delete(_db.syncQueue)
              ..where((t) => t.clientUuid.equals(e.key) & t.queuedAt.equals(e.value)))
            .go();
      }
      final stillQueuedTags = {for (final q in await _db.select(_db.tagSyncQueue).get()) q.clientUuid};
      final stillQueuedItems = {for (final q in await _db.select(_db.syncQueue).get()) q.clientUuid};

      for (final t in respTags) {
        final cu = t['clientUuid'] as String;
        if (stillQueuedTags.contains(cu)) continue;
        final updatedAt = DateTime.parse(t['updatedAt'] as String);
        await _db.into(_db.tags).insertOnConflictUpdate(TagRow(
          clientUuid: cu,
          name: t['name'] as String,
          color: t['color'] as String?,
          createdAt: updatedAt,
          updatedAt: updatedAt,
          deletedAt: t['deletedAt'] != null ? DateTime.parse(t['deletedAt'] as String) : null,
        ));
      }

      for (final i in respItems) {
        final cu = i['clientUuid'] as String;
        if (stillQueuedItems.contains(cu)) continue;
        await _db.into(_db.collectionItems).insertOnConflictUpdate(CollectionItemRow(
          clientUuid: cu,
          variantId: i['variantId'] as String,
          quantity: i['quantity'] as int,
          condition: i['condition'] as String,
          isFoil: i['isFoil'] as bool,
          notes: i['notes'] as String?,
          addedAt: DateTime.parse(i['addedAt'] as String),
          updatedAt: DateTime.parse(i['updatedAt'] as String),
          deletedAt: i['deletedAt'] != null ? DateTime.parse(i['deletedAt'] as String) : null,
        ));
        // Replace local links with the server's authoritative set.
        await (_db.delete(_db.collectionItemTags)..where((t) => t.itemClientUuid.equals(cu))).go();
        for (final tu in (i['tagClientUuids'] as List).cast<String>()) {
          await _db.into(_db.collectionItemTags).insertOnConflictUpdate(
                CollectionItemTagRow(itemClientUuid: cu, tagClientUuid: tu),
              );
        }
      }

      await _db.setCollectionLastSyncAt(serverTime);
    });
  }

  Future<List<String>> _liveTagUuids(String itemClientUuid) async {
    final q = _db.select(_db.collectionItemTags).join([
      innerJoin(_db.tags,
          _db.tags.clientUuid.equalsExp(_db.collectionItemTags.tagClientUuid) & _db.tags.deletedAt.isNull()),
    ])
      ..where(_db.collectionItemTags.itemClientUuid.equals(itemClientUuid));
    final rows = await q.get();
    return rows.map((r) => r.readTable(_db.collectionItemTags).tagClientUuid).toList();
  }
}
