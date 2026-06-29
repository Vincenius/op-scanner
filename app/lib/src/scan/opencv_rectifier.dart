import 'dart:math' as math;
import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'phash.dart';

// Canonical rectified size (aspect 600:838) — see /shared/HASHING.md.
const int kCardW = 600;
const int kCardH = 838;

// A quad must cover at least this fraction of the frame. Kept low so a card that
// does NOT fill the viewfinder (held back, off-center, at a distance) is still
// detected — fixing the old "must be exactly in position" behavior.
const double _minAreaFrac = 0.06;
// Acceptable short/long edge ratio of the detected quad. A One Piece card is
// 600:838 → 0.716; the wide window absorbs perspective foreshortening when the
// card is photographed at an angle, and accepts the card in any rotation (we
// re-orient to portrait afterwards).
const double _ratioMin = 0.45;
const double _ratioMax = 0.97;
// Contour detection runs on a copy downscaled to this longest side: far cheaper
// than full-res edge finding, with negligible corner-precision loss after the
// quad is scaled back up for the full-resolution warp.
const int _detectTarget = 600;

// The morphology kernel is constant, so build it once and reuse it across every
// frame instead of allocating + disposing a Mat per detection.
cv.Mat? _closeKernel;
cv.Mat _morphCloseKernel() =>
    _closeKernel ??= cv.getStructuringElement(cv.MORPH_RECT, (7, 7));

/// Detect the largest card-like quadrilateral and perspective-warp it to a
/// canonical upright RGB image (single best-guess orientation). Used by the
/// rectifier test and the encoded-bytes path. Returns null if no quad is found.
RgbImage? rectifyCardFromBgr(cv.Mat bgr) {
  final quad = _findCardQuad(bgr);
  if (quad == null) return null;
  try {
    final warped = _warpToCanonical(bgr, quad);
    try {
      return _matBgrToRgb(warped);
    } finally {
      warped.dispose();
    }
  } finally {
    quad.dispose();
  }
}

/// Convenience: decode encoded bytes (JPEG/PNG) then rectify.
RgbImage? rectifyCardFromBytes(Uint8List imageBytes) {
  final bgr = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
  try {
    if (bgr.isEmpty) return null;
    return rectifyCardFromBgr(bgr);
  } finally {
    bgr.dispose();
  }
}

/// Detect a card and return BOTH plausible upright orientations of the warped
/// card (the warp normalized to portrait, plus its 180° rotation). The live
/// scanner hashes each and keeps the best match, so a card held upside-down — or
/// rotated 90°/270° in the frame, which portrait-normalization folds into these
/// two — is recognized. Returns an empty list if no card quad is found.
List<RgbImage> rectifyCardOrientations(cv.Mat bgr) {
  final quad = _findCardQuad(bgr);
  if (quad == null) return const [];
  try {
    final warped = _warpToPortrait(bgr, quad);
    try {
      return _bothOrientations(warped);
    } finally {
      warped.dispose();
    }
  } finally {
    quad.dispose();
  }
}

/// Fallback when no card quad is found: center-crop the frame to the card aspect
/// (assumes the card roughly fills/centers the frame) and return both upright
/// orientations. Lower quality than a detected warp, but keeps scanning usable
/// when edges are too weak to detect a quad.
List<RgbImage> centerCropOrientations(cv.Mat bgr) {
  final cropped = _centerCropToAspect(bgr);
  try {
    return _bothOrientations(cropped);
  } finally {
    cropped.dispose();
  }
}

List<RgbImage> _bothOrientations(cv.Mat warpedBgr) {
  final upright = _matBgrToRgb(warpedBgr);
  final flipped = cv.rotate(warpedBgr, cv.ROTATE_180);
  try {
    return [upright, _matBgrToRgb(flipped)];
  } finally {
    flipped.dispose();
  }
}

cv.VecPoint? _findCardQuad(cv.Mat bgr) {
  // Downscale for detection, remembering the factor to map corners back.
  final longest = math.max(bgr.rows, bgr.cols);
  final scale = longest > _detectTarget ? _detectTarget / longest : 1.0;
  cv.Mat work;
  final ownWork = scale < 1.0;
  if (ownWork) {
    work = cv.resize(
      bgr,
      ((bgr.cols * scale).round(), (bgr.rows * scale).round()),
      interpolation: cv.INTER_AREA,
    );
  } else {
    work = bgr;
  }

  final gray = cv.cvtColor(work, cv.COLOR_BGR2GRAY);
  final blurred = cv.gaussianBlur(gray, (5, 5), 0);
  final edges = cv.canny(blurred, 50, 150);
  // Close gaps + thicken so the card border forms one closed contour.
  final closed = cv.morphologyEx(edges, cv.MORPH_CLOSE, _morphCloseKernel());
  final (contours, hierarchy) = cv.findContours(closed, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);

  final imgArea = (work.rows * work.cols).toDouble();
  cv.VecPoint? best;
  var bestArea = 0.0;
  for (final c in contours) {
    final area = cv.contourArea(c);
    if (area < imgArea * _minAreaFrac) continue;
    final quad = _quadFromContour(c);
    if (quad == null) continue;
    if (area > bestArea && cv.isContourConvex(quad) && _ratioOk(quad)) {
      best?.dispose();
      best = quad;
      bestArea = area;
    } else {
      quad.dispose();
    }
  }

  gray.dispose();
  blurred.dispose();
  edges.dispose();
  closed.dispose();
  contours.dispose();
  hierarchy.dispose();
  if (ownWork) work.dispose();

  if (best == null) return null;
  if (scale < 1.0) {
    final scaled = _scaleQuad(best, 1 / scale);
    best.dispose();
    return scaled;
  }
  return best;
}

/// Approximate a contour to a 4-point polygon, trying increasing tolerances.
cv.VecPoint? _quadFromContour(cv.VecPoint contour) {
  final peri = cv.arcLength(contour, true);
  for (final eps in const [0.02, 0.03, 0.04, 0.05, 0.06, 0.08]) {
    final approx = cv.approxPolyDP(contour, eps * peri, true);
    if (approx.length == 4) return approx;
    approx.dispose();
  }
  return null;
}

cv.VecPoint _scaleQuad(cv.VecPoint quad, double f) {
  return cv.VecPoint.fromList([
    for (final p in quad.toList()) cv.Point((p.x * f).round(), (p.y * f).round()),
  ]);
}

bool _ratioOk(cv.VecPoint quad) {
  final pts = _ordered(quad);
  final wTop = _dist(pts[0], pts[1]);
  final wBot = _dist(pts[3], pts[2]);
  final hLeft = _dist(pts[0], pts[3]);
  final hRight = _dist(pts[1], pts[2]);
  final w = (wTop + wBot) / 2;
  final h = (hLeft + hRight) / 2;
  final lo = math.min(w, h), hi = math.max(w, h);
  if (hi <= 0) return false;
  final ratio = lo / hi;
  return ratio >= _ratioMin && ratio <= _ratioMax;
}

/// Warp using the upright-assuming [_ordered] corner mapping (TL→TR→BR→BL).
cv.Mat _warpToCanonical(cv.Mat bgr, cv.VecPoint quad) {
  return _warp(bgr, _ordered(quad));
}

/// Warp so the card's SHORT edge becomes the top: the result is always portrait,
/// regardless of how the card was rotated in the frame. The remaining up/down
/// ambiguity is resolved by hashing both this warp and its 180° rotation.
cv.Mat _warpToPortrait(cv.Mat bgr, cv.VecPoint quad) {
  final ring = _orderClockwise(quad.toList());
  final e01 = _dist(ring[0], ring[1]);
  final e12 = _dist(ring[1], ring[2]);
  final start = e01 <= e12 ? 0 : 1; // begin on a short edge → it maps to the top
  return _warp(bgr, [for (var i = 0; i < 4; i++) ring[(start + i) % 4]]);
}

cv.Mat _warp(cv.Mat bgr, List<cv.Point> orderedCorners) {
  final src = cv.VecPoint.fromList(orderedCorners);
  final dst = cv.VecPoint.fromList([
    cv.Point(0, 0),
    cv.Point(kCardW - 1, 0),
    cv.Point(kCardW - 1, kCardH - 1),
    cv.Point(0, kCardH - 1),
  ]);
  final m = cv.getPerspectiveTransform(src, dst);
  final warped = cv.warpPerspective(bgr, m, (kCardW, kCardH));
  src.dispose();
  dst.dispose();
  m.dispose();
  return warped;
}

cv.Mat _centerCropToAspect(cv.Mat bgr) {
  const aspect = kCardW / kCardH; // ~0.716
  final w = bgr.cols, h = bgr.rows;
  final cur = w / h;
  int cw, ch;
  if (cur > aspect) {
    ch = h;
    cw = (ch * aspect).round();
  } else {
    cw = w;
    ch = (cw / aspect).round();
  }
  final x = (w - cw) ~/ 2, y = (h - ch) ~/ 2;
  return cv.Mat.fromMat(bgr, copy: true, roi: cv.Rect(x, y, cw, ch));
}

RgbImage _matBgrToRgb(cv.Mat bgr) {
  final rgb = cv.cvtColor(bgr, cv.COLOR_BGR2RGB);
  try {
    return RgbImage(Uint8List.fromList(rgb.data), rgb.cols, rgb.rows);
  } finally {
    rgb.dispose();
  }
}

/// Order 4 corners as [TL, TR, BR, BL] using x+y and y-x extremes (assumes the
/// card is roughly upright in the frame).
List<cv.Point> _ordered(cv.VecPoint quad) {
  final pts = quad.toList();
  cv.Point byMin(int Function(cv.Point) f) => pts.reduce((a, b) => f(a) <= f(b) ? a : b);
  cv.Point byMax(int Function(cv.Point) f) => pts.reduce((a, b) => f(a) >= f(b) ? a : b);
  final tl = byMin((p) => p.x + p.y);
  final br = byMax((p) => p.x + p.y);
  final tr = byMin((p) => p.y - p.x);
  final bl = byMax((p) => p.y - p.x);
  return [tl, tr, br, bl];
}

/// Order 4 corners into a consistent clockwise ring (image coords, y-down) by
/// angle about the centroid. Clockwise matches the destination winding, so the
/// warp is never mirrored, only rotated — and the rotation is pinned by the
/// caller choosing which edge starts the ring.
List<cv.Point> _orderClockwise(List<cv.Point> pts) {
  var cx = 0.0, cy = 0.0;
  for (final p in pts) {
    cx += p.x;
    cy += p.y;
  }
  cx /= pts.length;
  cy /= pts.length;
  final sorted = [...pts]
    ..sort((a, b) =>
        math.atan2(a.y - cy, a.x - cx).compareTo(math.atan2(b.y - cy, b.x - cx)));
  return sorted;
}

double _dist(cv.Point a, cv.Point b) {
  final dx = (a.x - b.x).toDouble();
  final dy = (a.y - b.y).toDouble();
  return math.sqrt(dx * dx + dy * dy);
}
