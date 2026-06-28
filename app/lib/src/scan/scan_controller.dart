import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// The on-device match database ({variantId: phash}) loaded from local SQLite.
final scanDbProvider = FutureProvider<Map<String, String>>(
  (ref) => ref.watch(catalogRepositoryProvider).phashDb(),
);

/// Tag applied to every card confirmed during the current scan session.
final scanTagProvider = NotifierProvider<ScanTagNotifier, String?>(ScanTagNotifier.new);

class ScanTagNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? tagClientUuid) => state = tagClientUuid;
}

/// Rapid-add: auto-add confidently matched cards without a confirm tap.
final rapidAddProvider = NotifierProvider<RapidAddNotifier, bool>(RapidAddNotifier.new);

class RapidAddNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}
