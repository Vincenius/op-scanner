import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

/// In-memory conversion of a live camera stream frame ([CameraImage]) into the
/// formats the recognizer needs — a BGR [cv.Mat] for OpenCV detection, and an
/// ML Kit [InputImage] for OCR — WITHOUT going through a JPEG file on disk.
///
/// This is what makes streaming-mode scanning fast: the old path called
/// `takePicture()` (full-res still + JPEG encode + disk write + read back) for
/// every frame. Here we operate directly on the raw preview buffers.
///
/// Format handling:
///   * Android: we request [ImageFormatGroup.nv21] → a single tightly-packed
///     NV21 plane, trivial to wrap. The same bytes feed ML Kit directly.
///   * iOS: we request [ImageFormatGroup.bgra8888] → a single BGRA plane.
///   * yuv420 (any platform, fallback): the 3-plane YUV_420_888 layout is
///     re-packed into NV21 (handles row/pixel strides) for OpenCV; OCR is
///     skipped on this path (matching alone is robust).
///
/// All returned Mats are owned by the caller and must be disposed.
cv.Mat? cameraImageToBgr(CameraImage image) {
  switch (image.format.group) {
    case ImageFormatGroup.nv21:
      return _nv21ToBgr(image);
    case ImageFormatGroup.bgra8888:
      return _bgraToBgr(image);
    case ImageFormatGroup.yuv420:
      return _yuv420ToBgr(image);
    default:
      return null;
  }
}

cv.Mat? _nv21ToBgr(CameraImage image) {
  final w = image.width, h = image.height;
  final plane = image.planes[0];
  // NV21 from camerax is normally tightly packed (Y: w*h, then interleaved VU:
  // w*h/2). If a device pads rows we fall back to repacking via the YUV path.
  final expected = w * h + 2 * ((w + 1) ~/ 2) * ((h + 1) ~/ 2);
  if (plane.bytes.length < expected || plane.bytesPerRow != w) {
    return _yuv420ToBgr(image);
  }
  final yuv = cv.Mat.fromList(h + h ~/ 2, w, cv.MatType.CV_8UC1, plane.bytes);
  try {
    return cv.cvtColor(yuv, cv.COLOR_YUV2BGR_NV21);
  } finally {
    yuv.dispose();
  }
}

cv.Mat? _bgraToBgr(CameraImage image) {
  final w = image.width, h = image.height;
  final plane = image.planes[0];
  final stride = plane.bytesPerRow;
  final Uint8List packed;
  if (stride == w * 4) {
    packed = plane.bytes;
  } else {
    // Strip per-row padding so the Mat sees a contiguous w*4 stride.
    packed = Uint8List(w * h * 4);
    for (var r = 0; r < h; r++) {
      packed.setRange(r * w * 4, r * w * 4 + w * 4, plane.bytes, r * stride);
    }
  }
  final bgra = cv.Mat.fromList(h, w, cv.MatType.CV_8UC4, packed);
  try {
    return cv.cvtColor(bgra, cv.COLOR_BGRA2BGR);
  } finally {
    bgra.dispose();
  }
}

cv.Mat? _yuv420ToBgr(CameraImage image) {
  final nv21 = yuv420ToNv21(image);
  if (nv21 == null) return null;
  final w = image.width, h = image.height;
  final yuv = cv.Mat.fromList(h + h ~/ 2, w, cv.MatType.CV_8UC1, nv21);
  try {
    return cv.cvtColor(yuv, cv.COLOR_YUV2BGR_NV21);
  } finally {
    yuv.dispose();
  }
}

/// Re-pack a (multi-plane) YUV_420_888 / biplanar frame into a contiguous NV21
/// buffer (Y plane followed by interleaved V,U), honoring each plane's row and
/// pixel strides. Also used to feed ML Kit on the yuv420 fallback path.
Uint8List? yuv420ToNv21(CameraImage image) {
  if (image.planes.isEmpty) return null;
  final w = image.width, h = image.height;
  final cw = (w + 1) ~/ 2, ch = (h + 1) ~/ 2;
  final out = Uint8List(w * h + 2 * cw * ch);

  // Y plane (strip row padding).
  final y = image.planes[0];
  var o = 0;
  for (var r = 0; r < h; r++) {
    out.setRange(o, o + w, y.bytes, r * y.bytesPerRow);
    o += w;
  }

  // Chroma. 3-plane (Android YUV_420_888): U=plane1, V=plane2, pixelStride 1|2.
  // 2-plane (iOS biplanar NV12): plane1 holds interleaved Cb,Cr.
  final bool triPlane = image.planes.length >= 3;
  final u = image.planes[1];
  final v = triPlane ? image.planes[2] : image.planes[1];
  final uRow = u.bytesPerRow, vRow = v.bytesPerRow;
  final uPix = u.bytesPerPixel ?? (triPlane ? 1 : 2);
  final vPix = v.bytesPerPixel ?? 2;
  // For biplanar NV12, Cb (U) is at even offsets and Cr (V) at odd offsets of
  // the same plane.
  final vBase = triPlane ? 0 : 1;
  for (var r = 0; r < ch; r++) {
    for (var c = 0; c < cw; c++) {
      final vi = r * vRow + c * vPix + vBase;
      final ui = r * uRow + c * uPix;
      out[o++] = vi < v.bytes.length ? v.bytes[vi] : 128; // V
      out[o++] = ui < u.bytes.length ? u.bytes[ui] : 128; // U
    }
  }
  return out;
}

/// Build an ML Kit [InputImage] from a live frame for OCR, best-effort.
///
/// Returns null for formats we don't pass through (the caller then runs without
/// the OCR card-code prefilter — matching still works). [sensorOrientation] is
/// the camera's reported sensor orientation in degrees (used as the rotation
/// hint on Android; unused on iOS).
///
/// The plane bytes are COPIED: OCR runs asynchronously and the underlying stream
/// buffer is recycled as soon as the frame callback returns.
InputImage? inputImageFromCameraImage(CameraImage image, int sensorOrientation) {
  final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
      InputImageRotation.rotation0deg;
  final size = Size(image.width.toDouble(), image.height.toDouble());
  final InputImageFormat format;
  switch (image.format.group) {
    case ImageFormatGroup.nv21:
      format = InputImageFormat.nv21;
    case ImageFormatGroup.bgra8888:
      format = InputImageFormat.bgra8888;
    default:
      return null;
  }
  return InputImage.fromBytes(
    bytes: Uint8List.fromList(image.planes[0].bytes),
    metadata: InputImageMetadata(
      size: size,
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    ),
  );
}
