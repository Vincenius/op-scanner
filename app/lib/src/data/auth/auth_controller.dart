import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../collection_controller.dart';
import 'auth_storage.dart';

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState(this.status, [this.user]);
  final AuthStatus status;
  final StoredUser? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Force logout if the access token can no longer be refreshed.
    ref.read(apiClientProvider).onUnauthenticated = _forceLogout;
    _restore();
    return const AuthState(AuthStatus.unknown);
  }

  Future<void> _restore() async {
    final user = await ref.read(authRepositoryProvider).currentUser();
    state = user != null
        ? AuthState(AuthStatus.authenticated, user)
        : const AuthState(AuthStatus.unauthenticated);
    if (user != null) _afterLogin();
  }

  Future<void> login(String email, String password) async {
    final user = await ref.read(authRepositoryProvider).login(email, password);
    state = AuthState(AuthStatus.authenticated, user);
    _afterLogin();
  }

  Future<void> register(String email, String password) async {
    final user = await ref.read(authRepositoryProvider).register(email, password);
    state = AuthState(AuthStatus.authenticated, user);
    _afterLogin();
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    await ref.read(databaseProvider).clearCollection();
    state = const AuthState(AuthStatus.unauthenticated);
  }

  /// Pull the user's collection right after authenticating.
  void _afterLogin() {
    Future.microtask(() => ref.read(collectionSyncControllerProvider.notifier).sync());
  }

  void _forceLogout() {
    ref.read(authRepositoryProvider).logout();
    ref.read(databaseProvider).clearCollection();
    state = const AuthState(AuthStatus.unauthenticated);
  }
}
