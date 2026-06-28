import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/catalog/card_detail_screen.dart';
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
    ],
  );
});
