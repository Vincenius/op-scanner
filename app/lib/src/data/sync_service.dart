import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../config.dart';
import 'local/database.dart';
import 'remote/api_client.dart';

/// Progress of a catalog sync (data first, then optional image prefetch).
class SyncProgress {
  const SyncProgress({
    required this.phase,
    this.done = 0,
    this.total = 0,
  });

  final String phase; // 'data' | 'images' | 'complete'
  final int done;
  final int total;

  double? get fraction => total > 0 ? done / total : null;
}

/// Pulls the catalog into the local drift DB and (best-effort) prefetches
/// thumbnails so browsing works offline.
class SyncService {
  SyncService(this._db, this._api, {CacheManager? cacheManager})
      : _cache = cacheManager ?? DefaultCacheManager();

  final AppDatabase _db;
  final ApiClient _api;
  final CacheManager _cache;

  Future<void> sync({
    void Function(SyncProgress)? onProgress,
    bool prefetchImages = true,
  }) async {
    onProgress?.call(const SyncProgress(phase: 'data'));
    final since = await _db.lastSyncAt();
    final payload = await _api.catalogSync(since);
    await _applyCatalog(payload);

    final serverTime = DateTime.parse(payload['serverTime'] as String);
    await _db.setLastSyncAt(serverTime);

    if (prefetchImages) {
      await _prefetchThumbnails(onProgress: onProgress);
    }
    onProgress?.call(const SyncProgress(phase: 'complete'));
  }

  Future<void> _applyCatalog(Map<String, dynamic> payload) async {
    final sets = (payload['sets'] as List).cast<Map<String, dynamic>>();
    final cards = (payload['cards'] as List).cast<Map<String, dynamic>>();

    await _db.batch((b) {
      for (final s in sets) {
        b.insert(
          _db.sets,
          SetsCompanion.insert(
            id: s['id'] as String,
            code: s['code'] as String,
            name: s['name'] as String,
            releaseDate: Value(_parseDate(s['releaseDate'])),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
      for (final c in cards) {
        b.insert(
          _db.cards,
          CardsCompanion.insert(
            id: c['id'] as String,
            cardCode: c['cardCode'] as String,
            name: c['name'] as String,
            colors: (c['colors'] as List).join(','),
            type: c['type'] as String,
            cost: Value(c['cost'] as int?),
            power: Value(c['power'] as int?),
            counter: Value(c['counter'] as int?),
            attribute: Value(c['attribute'] as String?),
            family: Value(c['family'] as String?),
            abilityText: Value(c['abilityText'] as String?),
            triggerText: Value(c['triggerText'] as String?),
            setId: c['setId'] as String,
            setCode: c['setCode'] as String,
          ),
          mode: InsertMode.insertOrReplace,
        );
        for (final v in (c['variants'] as List).cast<Map<String, dynamic>>()) {
          final price = v['currentPrice'] as Map<String, dynamic>?;
          b.insert(
            _db.variants,
            VariantsCompanion.insert(
              variantId: v['variantId'] as String,
              cardId: v['cardId'] as String,
              rarity: Value(v['rarity'] as String?),
              isAltArt: Value(v['isAltArt'] as bool? ?? false),
              variantLabel: Value(v['variantLabel'] as String?),
              thumbUrl: v['thumbUrl'] as String,
              fullUrl: v['fullUrl'] as String,
              marketPrice: Value((price?['marketPrice'] as num?)?.toDouble()),
              lowPrice: Value((price?['lowPrice'] as num?)?.toDouble()),
              priceCurrency: Value(price?['currency'] as String?),
              priceCapturedAt: Value(_parseDate(price?['capturedAt'])),
              phash: Value(v['phash'] as String?),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
    });
  }

  Future<void> _prefetchThumbnails({void Function(SyncProgress)? onProgress}) async {
    final rows = await _db.select(_db.variants).get();
    final urls = rows.map((r) => AppConfig.imageUrl(r.thumbUrl)).toList();
    final total = urls.length;
    var done = 0;
    onProgress?.call(SyncProgress(phase: 'images', done: 0, total: total));

    // Bounded concurrency; best-effort (failures don't abort the sync).
    const concurrency = 8;
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= urls.length) break;
        try {
          await _cache.downloadFile(urls[i]);
        } catch (err) {
          if (kDebugMode) debugPrint('thumb prefetch failed: ${urls[i]} ($err)');
        }
        done++;
        if (done % 25 == 0 || done == total) {
          onProgress?.call(SyncProgress(phase: 'images', done: done, total: total));
        }
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
  }

  static DateTime? _parseDate(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}
