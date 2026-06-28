import 'package:flutter/foundation.dart';

/// Whether the on-device card scanner is available on this platform.
///
/// Scanning (camera + OpenCV + ML Kit + pHash) is mobile-only and must be
/// cleanly flagged off on web — web users browse/edit only (see project plan §9).
/// All scanner UI and imports should sit behind this flag.
bool get isScanningSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
