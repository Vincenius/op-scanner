import 'package:dio/dio.dart';

import '../../config.dart';
import '../auth/auth_storage.dart';

const _authPaths = {'/auth/login', '/auth/register', '/auth/refresh', '/auth/logout'};

enum _RefreshResult { ok, authFailed, networkError }

/// HTTP client for the OP Scanner API. Injects the bearer access token and
/// transparently refreshes it once on a 401 (rotating refresh token).
class ApiClient {
  ApiClient(this._storage, {Dio? dio, Dio? bareDio})
      : _dio = dio ?? _build(),
        _bareDio = bareDio ?? _build() {
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  final AuthStorage _storage;
  final Dio _dio;
  final Dio _bareDio; // no interceptors — used for token refresh
  Future<_RefreshResult>? _refreshing;

  /// Called when the session can no longer be refreshed (forces logout).
  void Function()? onUnauthenticated;

  static Dio _build() => Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 2),
      ));

  static bool _isAuthPath(String path) => _authPaths.any(path.endsWith);

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthPath(options.path)) {
      final token = await _storage.accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler handler) async {
    final req = e.requestOptions;
    final is401 = e.response?.statusCode == 401;
    if (is401 && !_isAuthPath(req.path) && req.extra['retried'] != true) {
      final result = await _refreshOnce();
      if (result == _RefreshResult.ok) {
        final token = await _storage.accessToken();
        req.extra['retried'] = true;
        req.headers['Authorization'] = 'Bearer $token';
        try {
          return handler.resolve(await _dio.fetch(req));
        } catch (err) {
          return handler.reject(err is DioException ? err : e);
        }
      }
      // Only force logout when the refresh token is genuinely rejected — never
      // on a transient network error (which must not wipe the local session).
      if (result == _RefreshResult.authFailed) onUnauthenticated?.call();
    }
    handler.next(e);
  }

  Future<_RefreshResult> _refreshOnce() {
    return _refreshing ??= () async {
      try {
        final rt = await _storage.refreshToken();
        if (rt == null) return _RefreshResult.authFailed;
        final res = await _bareDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': rt},
        );
        final data = res.data!;
        await _storage.updateTokens(AuthTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        ));
        return _RefreshResult.ok;
      } on DioException catch (err) {
        final status = err.response?.statusCode;
        return (status == 401 || status == 403)
            ? _RefreshResult.authFailed
            : _RefreshResult.networkError;
      } catch (_) {
        return _RefreshResult.networkError;
      } finally {
        _refreshing = null;
      }
    }();
  }

  // --- Auth ---
  Future<Map<String, dynamic>> register(String email, String password) async {
    final res = await _bareDio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email, 'password': password},
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _bareDio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return res.data!;
  }

  Future<void> logout(String refreshToken) async {
    await _bareDio.post('/auth/logout', data: {'refreshToken': refreshToken});
  }

  // --- Catalog ---
  Future<Map<String, dynamic>> catalogSync(DateTime? since) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/catalog/sync',
      queryParameters: since != null ? {'since': since.toUtc().toIso8601String()} : null,
    );
    return res.data!;
  }

  Future<List<dynamic>> priceHistory(String variantId, String range) async {
    final res = await _dio.get<List<dynamic>>(
      '/variants/$variantId/prices',
      queryParameters: {'range': range},
    );
    return res.data ?? const [];
  }

  Future<List<int>> imageBytes(String relativePath) async {
    final res = await _dio.get<List<int>>(
      relativePath,
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data ?? const [];
  }

  // --- Share ---
  Future<String?> shareStatus() async {
    final res = await _dio.get<Map<String, dynamic>>('/share');
    return res.data?['slug'] as String?;
  }

  Future<String> enableShare() async {
    final res = await _dio.post<Map<String, dynamic>>('/share');
    return res.data!['slug'] as String;
  }

  Future<void> disableShare() async {
    await _dio.delete<void>('/share');
  }

  Future<Map<String, dynamic>> publicCollection(String slug) async {
    final res = await _dio.get<Map<String, dynamic>>('/share/$slug');
    return res.data!;
  }

  // --- Collection ---
  Future<Map<String, dynamic>> collectionSync(
    DateTime? since,
    List<Map<String, dynamic>> tags,
    List<Map<String, dynamic>> mutations,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/collection/sync',
      data: {
        if (since != null) 'since': since.toUtc().toIso8601String(),
        'tags': tags,
        'mutations': mutations,
      },
    );
    return res.data!;
  }
}
