import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/catalog/card_detail_screen.dart';
import '../features/collection/collection_stats_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/share/public_collection_screen.dart';
import '../features/shell/home_shell.dart';
import '../scan/scan_entry.dart';

/// App router. Kept in a provider so later phases can react to auth state
/// (redirects) and inject route guards.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/card/:cardId',
        name: 'card',
        builder: (context, state) =>
            CardDetailScreen(cardId: state.pathParameters['cardId']!),
      ),
      GoRoute(
        path: '/scan',
        name: 'scan',
        builder: (context, state) => const ScanScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/collection/stats',
        name: 'collection-stats',
        builder: (context, state) => const CollectionStatsScreen(),
      ),
      GoRoute(
        path: '/share/:slug',
        name: 'share',
        builder: (context, state) =>
            PublicCollectionScreen(slug: state.pathParameters['slug']!),
      ),
    ],
  );
});
