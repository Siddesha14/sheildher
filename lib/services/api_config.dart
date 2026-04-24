/// ApiConfig centralizes all external service keys and endpoints.
/// IMPORTANT: For production, API keys should NOT be hardcoded. 
/// They should be fetched from a secure environment or a backend proxy.
class ApiConfig {
  /// SECURE KEY MANAGEMENT
  /// We use String.fromEnvironment to read keys passed during build/run via --dart-define.
  /// Example: flutter run --dart-define=GOOGLE_MAPS_KEY=your_key
  
  static const String googleMapsKey = String.fromEnvironment('GOOGLE_MAPS_KEY');
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Safety Check: Ensures the app doesn't attempt API calls without valid keys.
  static bool get hasValidGoogleKey => googleMapsKey.isNotEmpty && googleMapsKey != 'null';
  static bool get hasValidGeminiKey => geminiApiKey.isNotEmpty && geminiApiKey != 'null';

  // Base URLs for external services
  static const String osrmBaseUrl = "https://router.project-osrm.org/route/v1";
  static const String osmSearchUrl = "https://nominatim.openstreetmap.org/search";

  // Security Policy: All network requests must use HTTPS
  static const bool enforceHttps = true;
  
  // Timeout settings for robust network handling
  static const Duration requestTimeout = Duration(seconds: 15);

  static void validateConfig() {
    if (!hasValidGoogleKey) {
      print('WARNING: GOOGLE_MAPS_KEY is missing. Map features may fail.');
    }
    if (!hasValidGeminiKey) {
      print('WARNING: GEMINI_API_KEY is missing. AI features will be disabled.');
    }
  }
}
