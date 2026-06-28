import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'local/database.dart';

/// Local-first tag store. Writes apply immediately and enqueue the tag for sync.
class TagRepository {
  TagRepository(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();
  final AppDatabase _db;
  final Uuid _uuid;

  Stream<List<TagRow>> watchActive() {
    return (_db.select(_db.tags)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<String> create(String name, {String? color}) async {
    final now = DateTime.now().toUtc();
    final clientUuid = _uuid.v4();
    await _write(TagRow(
      clientUuid: clientUuid,
      name: name.trim(),
      color: color,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    ));
    return clientUuid;
  }

  Future<void> rename(TagRow tag, String name) =>
      _write(tag.copyWith(name: name.trim(), updatedAt: DateTime.now().toUtc()));

  Future<void> setColor(TagRow tag, String? color) =>
      _write(tag.copyWith(color: Value(color), updatedAt: DateTime.now().toUtc()));

  Future<void> delete(TagRow tag) => _write(
        tag.copyWith(deletedAt: Value(DateTime.now().toUtc()), updatedAt: DateTime.now().toUtc()),
      );

  Future<void> _write(TagRow row) async {
    await _db.transaction(() async {
      await _db.into(_db.tags).insertOnConflictUpdate(row);
      await _db.into(_db.tagSyncQueue).insertOnConflictUpdate(
            TagSyncQueueRow(clientUuid: row.clientUuid, queuedAt: DateTime.now().toUtc()),
          );
    });
  }
}
