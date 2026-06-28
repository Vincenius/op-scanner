import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

class StoredUser {
  const StoredUser({required this.id, required this.email});
  final String id;
  final String email;
}

/// Persists auth tokens + user across launches (Keychain/Keystore on mobile,
/// localStorage-backed on web).
class AuthStorage {
  AuthStorage([FlutterSecureStorage? storage])
      : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUserId = 'user_id';
  static const _kEmail = 'user_email';

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String email,
  }) async {
    await _s.write(key: _kAccess, value: accessToken);
    await _s.write(key: _kRefresh, value: refreshToken);
    await _s.write(key: _kUserId, value: userId);
    await _s.write(key: _kEmail, value: email);
  }

  Future<void> updateTokens(AuthTokens tokens) async {
    await _s.write(key: _kAccess, value: tokens.accessToken);
    await _s.write(key: _kRefresh, value: tokens.refreshToken);
  }

  Future<String?> accessToken() => _s.read(key: _kAccess);
  Future<String?> refreshToken() => _s.read(key: _kRefresh);

  Future<StoredUser?> user() async {
    final id = await _s.read(key: _kUserId);
    final email = await _s.read(key: _kEmail);
    if (id == null || email == null) return null;
    return StoredUser(id: id, email: email);
  }

  Future<void> clear() async {
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
    await _s.delete(key: _kUserId);
    await _s.delete(key: _kEmail);
  }
}
