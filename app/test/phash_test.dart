import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:op_scanner/src/scan/matcher.dart';
import 'package:op_scanner/src/scan/phash.dart';

/// Deterministic procedural image — identical formula in TS and Dart.
RgbImage procedural(int w, int h, int seed) {
  final data = Uint8List(w * h * 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      for (var c = 0; c < 3; c++) {
        data[(y * w + x) * 3 + c] = (x * (7 + seed) + y * 13 + c * 53) & 0xff;
      }
    }
  }
  return RgbImage(data, w, h);
}

void main() {
  group('phash cross-implementation', () {
    test('Dart phash matches the TS reference on the same pixels', () {
      // Reference computed by ingest/src/phash/hash.ts on the seed-0 image.
      const tsReference = 'fb557511aa558855d0d7545555f9415584282cff143a54ff';
      final hash = phashFromRgb(procedural(300, 419, 0));
      expect(hash.length, 48);
      expect(hash, tsReference);
    });
  });

  group('matcher', () {
    test('finds the exact match at distance 0 and accepts with margin', () {
      final h1 = phashFromRgb(procedural(300, 419, 0));
      final h2 = phashFromRgb(procedural(300, 419, 3));
      final h3 = phashFromRgb(procedural(300, 419, 9));
      final db = {'v1': h1, 'v2': h2, 'v3': h3};

      final r = matchHash(h1, db);
      expect(r.top1!.variantId, 'v1');
      expect(r.top1!.distance, 0);
      expect(r.accepted, isTrue);
      // distinct images are well separated
      expect(hammingHex(h1, h2), greaterThan(kAcceptMargin));
    });

    test('restrictTo narrows candidates (OCR prefilter)', () {
      final h1 = phashFromRgb(procedural(300, 419, 0));
      final db = {'OP01-016': h1, 'OP01-016_p1': phashFromRgb(procedural(300, 419, 5))};
      final r = matchHash(h1, db, restrictTo: ['OP01-016']);
      expect(r.ranked, hasLength(1));
      expect(r.top1!.variantId, 'OP01-016');
    });

    test('does not accept when nothing is close', () {
      final db = {'v1': phashFromRgb(procedural(300, 419, 3))};
      // A query that is far from v1 (all-different image) should not auto-accept.
      final far = phashFromRgb(procedural(64, 90, 42));
      final r = matchHash(far, db);
      if (r.top1!.distance > kAcceptThreshold) {
        expect(r.accepted, isFalse);
      }
    });
  });
}
