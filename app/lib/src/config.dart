/// App configuration. Override at build/run time with:
///   --dart-define=API_BASE_URL=http://192.168.1.10:3000
class AppConfig {
  /// Base URL of the OP Scanner API. Defaults to localhost (web/desktop).
  /// For the Android emulator use http://10.0.2.2:3000.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// Resolve a server-relative image/proxy path to an absolute URL.
  static String imageUrl(String path) => '$apiBaseUrl$path';
}
