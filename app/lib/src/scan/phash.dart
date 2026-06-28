import 'dart:math' as math;
import 'dart:typed_data';

/// RGB perceptual hash — see /shared/HASHING.md. MUST stay byte-for-byte
/// equivalent to the TypeScript implementation in /ingest (ingest/src/phash/hash.ts).

class RgbImage {
  RgbImage(this.data, this.width, this.height);
  final Uint8List data; // row-major, 3 bytes/pixel (RGB, no alpha)
  final int width;
  final int height;
}

const double _cropLeft = 0.05, _cropTop = 0.06, _cropRight = 0.95, _cropBottom = 0.78;
const int _n = 32;

// cos[freq][x] = cos(((2x+1) * freq * π) / 64)
final List<List<double>> _cos = List.generate(
  8,
  (f) => List.generate(_n, (x) => math.cos(((2 * x + 1) * f * math.pi) / (2 * _n))),
);

List<Float64List> _downscale(RgbImage img) {
  final w = img.width, h = img.height, d = img.data;
  final x0 = (_cropLeft * w).round(), x1 = (_cropRight * w).round();
  final y0 = (_cropTop * h).round(), y1 = (_cropBottom * h).round();
  final cropW = x1 - x0, cropH = y1 - y0;
  final r = Float64List(_n * _n), g = Float64List(_n * _n), b = Float64List(_n * _n);

  for (var oy = 0; oy < _n; oy++) {
    var sy0 = y0 + (oy * cropH) ~/ _n;
    var sy1 = y0 + ((oy + 1) * cropH) ~/ _n;
    if (sy1 == sy0) sy1 = sy0 + 1;
    for (var ox = 0; ox < _n; ox++) {
      var sx0 = x0 + (ox * cropW) ~/ _n;
      var sx1 = x0 + ((ox + 1) * cropW) ~/ _n;
      if (sx1 == sx0) sx1 = sx0 + 1;
      var sr = 0, sg = 0, sb = 0, cnt = 0;
      for (var y = sy0; y < sy1; y++) {
        for (var x = sx0; x < sx1; x++) {
          final idx = (y * w + x) * 3;
          sr += d[idx];
          sg += d[idx + 1];
          sb += d[idx + 2];
          cnt++;
        }
      }
      final o = oy * _n + ox;
      r[o] = sr / cnt;
      g[o] = sg / cnt;
      b[o] = sb / cnt;
    }
  }
  return [r, g, b];
}

String _hashChannel(Float64List ch) {
  final block = Float64List(64);
  for (var v = 0; v < 8; v++) {
    final av = v == 0 ? math.sqrt(1 / _n) : math.sqrt(2 / _n);
    for (var u = 0; u < 8; u++) {
      final au = u == 0 ? math.sqrt(1 / _n) : math.sqrt(2 / _n);
      var sum = 0.0;
      for (var y = 0; y < _n; y++) {
        final cv = _cos[v][y];
        final row = y * _n;
        for (var x = 0; x < _n; x++) {
          sum += ch[row + x] * _cos[u][x] * cv;
        }
      }
      block[v * 8 + u] = au * av * sum;
    }
  }
  final vals = block.sublist(1)..sort();
  final median = vals[vals.length ~/ 2]; // 63 values -> index 31
  final sb = StringBuffer();
  for (var i = 0; i < 16; i++) {
    var nibble = 0;
    for (var j = 0; j < 4; j++) {
      final k = i * 4 + j;
      nibble = (nibble << 1) | (block[k] > median ? 1 : 0);
    }
    sb.write(nibble.toRadixString(16));
  }
  return sb.toString();
}

/// Compute the 48-hex (192-bit) RGB perceptual hash of a decoded image.
String phashFromRgb(RgbImage img) {
  final ch = _downscale(img);
  return _hashChannel(ch[0]) + _hashChannel(ch[1]) + _hashChannel(ch[2]);
}

/// Hamming distance between two 48-hex hashes (0..192).
int hammingHex(String a, String b) {
  var dist = 0;
  for (var i = 0; i < a.length; i++) {
    var x = int.parse(a[i], radix: 16) ^ int.parse(b[i], radix: 16);
    while (x > 0) {
      dist += x & 1;
      x >>= 1;
    }
  }
  return dist;
}
