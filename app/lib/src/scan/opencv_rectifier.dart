import 'dart:math' as math;
import 'dart:typed_data';

import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'phash.dart';

// Canonical rectified size (aspect 600:838) — see /shared/HASHING.md.
const int kCardW = 600;
const int kCardH = 838;

const double _minAreaFrac = 0.12; // quad must cover >= this fraction of the frame
const double _aspectMin = 0.55; // card w/h ~ 0.716
const double _aspectMax = 0.88;

/// Detect the largest card-like quadrilateral in a BGR image and perspective-warp
/// it to a canonical RGB image for hashing. Returns null if no confident quad is
/// found (caller may fall back to a center crop).
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

cv.VecPoint? _findCardQuad(cv.Mat bgr) {
  final gray = cv.cvtColor(bgr, cv.COLOR_BGR2GRAY);
  final blurred = cv.gaussianBlur(gray, (5, 5), 0);
  final edges = cv.canny(blurred, 50, 150);
  // Close gaps + thicken so the card border forms one closed contour.
  final kernel = cv.getStructuringElement(cv.MORPH_RECT, (7, 7));
  final closed = cv.morphologyEx(edges, cv.MORPH_CLOSE, kernel);
  final (contours, hierarchy) = cv.findContours(closed, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);

  final imgArea = (bgr.rows * bgr.cols).toDouble();
  cv.VecPoint? best;
  var bestArea = 0.0;
  for (final c in contours) {
    final area = cv.contourArea(c);
    if (area < imgArea * _minAreaFrac) continue;
    final quad = _quadFromContour(c);
    if (quad != null && area > bestArea && _aspectOk(quad)) {
      best?.dispose();
      best = quad;
      bestArea = area;
    } else {
      quad?.dispose();
    }
  }

  gray.dispose();
  blurred.dispose();
  edges.dispose();
  kernel.dispose();
  closed.dispose();
  contours.dispose();
  hierarchy.dispose();
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

bool _aspectOk(cv.VecPoint quad) {
  final pts = _ordered(quad);
  final wTop = _dist(pts[0], pts[1]);
  final wBot = _dist(pts[3], pts[2]);
  final hLeft = _dist(pts[0], pts[3]);
  final hRight = _dist(pts[1], pts[2]);
  final w = (wTop + wBot) / 2;
  final h = (hLeft + hRight) / 2;
  if (h <= 0) return false;
  final aspect = w / h;
  return aspect >= _aspectMin && aspect <= _aspectMax;
}

cv.Mat _warpToCanonical(cv.Mat bgr, cv.VecPoint quad) {
  final pts = _ordered(quad);
  final src = cv.VecPoint.fromList(pts);
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

RgbImage _matBgrToRgb(cv.Mat bgr) {
  final rgb = cv.cvtColor(bgr, cv.COLOR_BGR2RGB);
  try {
    return RgbImage(Uint8List.fromList(rgb.data), rgb.cols, rgb.rows);
  } finally {
    rgb.dispose();
  }
}

/// Order 4 corners as [TL, TR, BR, BL] using x+y and y-x extremes.
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

double _dist(cv.Point a, cv.Point b) {
  final dx = (a.x - b.x).toDouble();
  final dy = (a.y - b.y).toDouble();
  return math.sqrt(dx * dx + dy * dy);
}
