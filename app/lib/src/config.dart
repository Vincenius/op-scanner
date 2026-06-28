/// App configuration. Override at build/run time with:
///   --dart-define=API_BASE_URL=http://192.168.1.10:3000
class AppConfig {
  /// Base URL of the OP Scanner API. Defaults to localhost (web/desktop).
  /// For the Android emulator use http://10.0.2.2:3000.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3022',
  );

  /// Base URL of the web app, used to build shareable links on mobile (on web
  /// the current origin is used instead). e.g. https://cards.example.com
  static const String webBaseUrl = String.fromEnvironment('WEB_BASE_URL', defaultValue: '');

  /// Resolve a server-relative image/proxy path to an absolute URL.
  static String imageUrl(String path) => '$apiBaseUrl$path';
}
