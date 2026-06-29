import 'phash.dart';

/// Match thresholds — see /shared/HASHING.md. Tunable via the eval harness.
const int kAcceptThreshold = 40;
const int kAcceptMargin = 12;
// With a single candidate (e.g. OCR restricted to a one-printing code) there is
// no runner-up to compare, so require a tighter distance to avoid accepting an
// OCR-misread code's lone variant.
const int kSingleCandidateThreshold = 28;

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
}) =>
    matchHashMulti([queryHash], db, restrictTo: restrictTo);

/// Like [matchHash] but scores several candidate hashes for the SAME card —
/// e.g. the two upright orientations produced by [rectifyCardOrientations] — and
/// keeps, per variant, the closest match across them. This is what lets a card
/// be recognized when it is held upside-down or rotated in the frame.
MatchResult matchHashMulti(
  List<String> queryHashes,
  Map<String, String> db, {
  Iterable<String>? restrictTo,
}) {
  final ids = restrictTo ?? db.keys;
  final ranked = <MatchCandidate>[];
  for (final id in ids) {
    final h = db[id];
    if (h == null || h.length != 48) continue;
    var best = 192;
    for (final q in queryHashes) {
      final d = hammingHex(q, h);
      if (d < best) best = d;
    }
    ranked.add(MatchCandidate(id, best));
  }
  ranked.sort((a, b) => a.distance.compareTo(b.distance));

  final bool accepted;
  if (ranked.isEmpty) {
    accepted = false;
  } else if (ranked.length < 2) {
    accepted = ranked.first.distance <= kSingleCandidateThreshold;
  } else {
    accepted = ranked.first.distance <= kAcceptThreshold &&
        ranked[1].distance - ranked.first.distance >= kAcceptMargin;
  }

  return MatchResult(ranked, accepted);
}
