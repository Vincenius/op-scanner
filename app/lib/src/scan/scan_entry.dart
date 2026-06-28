// Selects the scan implementation per platform so the web build never compiles
// the camera / ML Kit code: native (dart:ffi available) gets the real screen,
// web gets the stub. Both export a `ScanScreen` widget.
export 'scan_unsupported.dart' if (dart.library.ffi) 'scan_screen.dart';
