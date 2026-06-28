import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:op_scanner/src/scan/opencv_rectifier.dart';
import 'package:op_scanner/src/scan/phash.dart';

// Self-contained validation of the OpenCV card detector + perspective-warp. Runs
// only where the dartcv native lib is loadable (set DARTCV_LIB_PATH); skips in a
// plain `flutter test`. A device build links the lib so the scanner works there.

/// Structured synthetic card (block grid + white border) — robust to hash.
cv.Mat _syntheticCard() {
  const w = kCardW, h = kCardH;
  const cols = 6, rows = 8;
  const palette = [
    [40, 60, 200], [200, 80, 40], [60, 180, 70], [220, 200, 50],
    [150, 60, 180], [50, 190, 200], [230, 120, 160], [90, 110, 60],
  ];
  final data = Uint8List(w * h * 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 3;
      if (x < 16 || x >= w - 16 || y < 16 || y >= h - 16) {
        data[i] = data[i + 1] = data[i + 2] = 255; // border
      } else {
        final c = palette[((y * rows ~/ h) * cols + (x * cols ~/ w)) % palette.length];
        data[i] = c[0];
        data[i + 1] = c[1];
        data[i + 2] = c[2];
      }
    }
  }
  return cv.Mat.fromList(h, w, cv.MatType.CV_8UC3, data);
}

RgbImage _matToRgb(cv.Mat bgr) {
  final rgb = cv.cvtColor(bgr, cv.COLOR_BGR2RGB);
  final out = RgbImage(Uint8List.fromList(rgb.data), rgb.cols, rgb.rows);
  rgb.dispose();
  return out;
}

bool _opencvAvailable() {
  try {
    cv.Mat.zeros(2, 2, cv.MatType.CV_8UC3).dispose();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  test('detects + de-skews a perspective-warped card', () {
    final card = _syntheticCard();
    const cw = 820, ch = 1080;
    final canvas = cv.Mat.zeros(ch, cw, cv.MatType.CV_8UC3);
    final src = cv.VecPoint.fromList([
      cv.Point(0, 0),
      cv.Point(kCardW - 1, 0),
      cv.Point(kCardW - 1, kCardH - 1),
      cv.Point(0, kCardH - 1),
    ]);
    final dst = cv.VecPoint.fromList([
      cv.Point(140, 120),
      cv.Point(660, 150),
      cv.Point(700, 920),
      cv.Point(110, 880),
    ]);
    final m = cv.getPerspectiveTransform(src, dst);
    cv.warpPerspective(card, m, (cw, ch), dst: canvas, borderMode: cv.BORDER_TRANSPARENT);

    final rectified = rectifyCardFromBgr(canvas);
    expect(rectified, isNotNull, reason: 'card quad should be detected');

    final dist = hammingHex(phashFromRgb(rectified!), phashFromRgb(_matToRgb(card)));
    expect(dist, lessThan(30), reason: 'de-skewed card should hash close to the original (got $dist)');

    card.dispose();
    canvas.dispose();
    src.dispose();
    dst.dispose();
    m.dispose();
  }, skip: !_opencvAvailable() ? 'dartcv native lib not available (set DARTCV_LIB_PATH)' : null);
}
