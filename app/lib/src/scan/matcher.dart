import 'phash.dart';

/// Match thresholds — see /shared/HASHING.md. Tunable via the eval harness.
const int kAcceptThreshold = 40;
const int kAcceptMargin = 12;

class MatchCandidate {
  const MatchCandidate(this.variantId, this.distance);
  final String variantId;
  final int distance;
}

class MatchResult {
  const MatchResult(this.ranked, this.accepted);
  final List<MatchCandidate> ranked; // ascending distance
  final bool accepted; // top-1 passed threshold + margin

  MatchCandidate? get top1 => ranked.isEmpty ? null : ranked.first;
  List<MatchCandidate> get top3 => ranked.take(3).toList();
}

/// Rank a query hash against a {variantId: phash} database. When [restrictTo]
/// is given (e.g. variants of an OCR-read card code), only those are scored.
MatchResult matchHash(
  String queryHash,
  Map<String, String> db, {
  Iterable<String>? restrictTo,
}) {
  final ids = restrictTo ?? db.keys;
  final ranked = <MatchCandidate>[];
  for (final id in ids) {
    final h = db[id];
    if (h == null || h.length != 48) continue;
    ranked.add(MatchCandidate(id, hammingHex(queryHash, h)));
  }
  ranked.sort((a, b) => a.distance.compareTo(b.distance));

  final accepted = ranked.isNotEmpty &&
      ranked.first.distance <= kAcceptThreshold &&
      (ranked.length < 2 || ranked[1].distance - ranked.first.distance >= kAcceptMargin);

  return MatchResult(ranked, accepted);
}
