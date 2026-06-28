import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/catalog/card_detail_screen.dart';
import '../features/catalog/catalog_screen.dart';

/// App router. Kept in a provider so later phases can react to auth state
/// (redirects) and inject route guards.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'catalog',
        builder: (context, state) => const CatalogScreen(),
      ),
      GoRoute(
        path: '/card/:cardId',
        name: 'card',
        builder: (context, state) =>
            CardDetailScreen(cardId: state.pathParameters['cardId']!),
      ),
    ],
  );
});
