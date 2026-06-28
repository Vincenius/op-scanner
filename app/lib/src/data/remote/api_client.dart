import 'package:dio/dio.dart';

import '../../config.dart';

/// Thin HTTP client for the OP Scanner API.
class ApiClient {
  ApiClient([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 2),
            ));

  final Dio _dio;

  /// GET /catalog/sync?since= — full snapshot (since null) or delta.
  Future<Map<String, dynamic>> catalogSync(DateTime? since) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/catalog/sync',
      queryParameters: since != null ? {'since': since.toUtc().toIso8601String()} : null,
    );
    return res.data!;
  }

  /// GET /variants/:id/prices?range=
  Future<List<dynamic>> priceHistory(String variantId, String range) async {
    final res = await _dio.get<List<dynamic>>(
      '/variants/$variantId/prices',
      queryParameters: {'range': range},
    );
    return res.data ?? const [];
  }

  /// Download raw bytes for a proxied image path (used by thumbnail prefetch).
  Future<List<int>> imageBytes(String relativePath) async {
    final res = await _dio.get<List<int>>(
      relativePath,
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data ?? const [];
  }
}
