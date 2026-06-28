import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'phash.dart';

// Canonical card aspect ratio (w/h) — see /shared/HASHING.md.
const double _cardAspect = 600 / 838; // ~0.716

/// Decode a captured photo and center-crop to the card aspect ratio, yielding
/// RGB pixels for hashing.
///
/// NOTE: this assumes the card roughly fills the frame. Perspective de-skew of
/// an angled card via OpenCV (Canny -> contours -> largest card-aspect quad ->
/// warpPerspective) is the planned upgrade for this stage; the recognizer and
/// the hash spec are already designed for a rectified 600:838 input, so only
/// this function changes.
RgbImage? rectifyToRgb(Uint8List photoBytes) {
  final decoded = img.decodeImage(photoBytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded); // honor EXIF rotation
  final cropped = _centerCropToAspect(oriented, _cardAspect);

  final w = cropped.width, h = cropped.height;
  final data = Uint8List(w * h * 3);
  var i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = cropped.getPixel(x, y);
      data[i++] = p.r.toInt();
      data[i++] = p.g.toInt();
      data[i++] = p.b.toInt();
    }
  }
  return RgbImage(data, w, h);
}

img.Image _centerCropToAspect(img.Image im, double aspect) {
  final current = im.width / im.height;
  int cw, ch;
  if (current > aspect) {
    ch = im.height;
    cw = (ch * aspect).round();
  } else {
    cw = im.width;
    ch = (cw / aspect).round();
  }
  final x = (im.width - cw) ~/ 2;
  final y = (im.height - ch) ~/ 2;
  return img.copyCrop(im, x: x, y: y, width: cw, height: ch);
}
