import '../remote/api_client.dart';
import 'auth_storage.dart';

/// Coordinates auth API calls with token/user persistence.
class AuthRepository {
  AuthRepository(this._api, this._storage);
  final ApiClient _api;
  final AuthStorage _storage;

  Future<StoredUser> register(String email, String password) async =>
      _persist(await _api.register(email.trim(), password));

  Future<StoredUser> login(String email, String password) async =>
      _persist(await _api.login(email.trim(), password));

  Future<void> logout() async {
    final rt = await _storage.refreshToken();
    if (rt != null) {
      try {
        await _api.logout(rt);
      } catch (_) {
        // best-effort revoke; clear locally regardless
      }
    }
    await _storage.clear();
  }

  Future<StoredUser?> currentUser() => _storage.user();

  Future<StoredUser> _persist(Map<String, dynamic> data) async {
    final user = data['user'] as Map<String, dynamic>;
    final stored = StoredUser(id: user['id'] as String, email: user['email'] as String);
    await _storage.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: stored.id,
      email: stored.email,
    );
    return stored;
  }
}
