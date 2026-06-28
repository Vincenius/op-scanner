import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../../data/auth/auth_controller.dart';
import '../../providers.dart';

/// Current share slug for the signed-in user (null when sharing is off).
final shareStatusProvider = FutureProvider<String?>((ref) async {
  if (!ref.watch(authControllerProvider).isAuthenticated) return null;
  return ref.watch(apiClientProvider).shareStatus();
});

/// Public collection for a share slug (cached per slug).
final publicCollectionProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, slug) => ref.watch(apiClientProvider).publicCollection(slug),
);

final shareControllerProvider = Provider<ShareController>((ref) => ShareController(ref));

class ShareController {
  ShareController(this._ref);
  final Ref _ref;

  Future<void> enable() async {
    await _ref.read(apiClientProvider).enableShare();
    _ref.invalidate(shareStatusProvider);
  }

  Future<void> disable() async {
    await _ref.read(apiClientProvider).disableShare();
    _ref.invalidate(shareStatusProvider);
  }
}

/// Build a shareable link for a slug. On web uses the current origin; on mobile
/// uses WEB_BASE_URL (falls back to the hash path if unset).
String shareLink(String slug) {
  final base = kIsWeb ? Uri.base.origin : AppConfig.webBaseUrl;
  return '$base/#/share/$slug';
}
