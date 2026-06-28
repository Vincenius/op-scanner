import 'dart:typed_data';

import 'opencv_rectifier.dart';
import 'phash.dart';
import 'rectifier.dart';

/// Turn a captured photo into RGB pixels for hashing: OpenCV card detection +
/// perspective de-skew, falling back to a center crop if no card quad is found.
/// (Mobile/native only — pulls in opencv_dart via dart:ffi.)
RgbImage? rectifyPhoto(Uint8List photoBytes) {
  return rectifyCardFromBytes(photoBytes) ?? rectifyToRgb(photoBytes);
}
