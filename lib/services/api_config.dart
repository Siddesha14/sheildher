/// ApiConfig centralizes all external service keys and endpoints.
/// IMPORTANT: For production, API keys should NOT be hardcoded. 
/// They should be fetched from a secure environment or a backend proxy.
class ApiConfig {
  // Use environment variables for keys where possible
  // In a real production app, these would be injected during CI/CD
  static const String googleMapsKey = String.fromEnvironment('GOOGLE_MAPS_KEY', defaultValue: 'AIzaSyAdMSePuSPNMw3aD4EbQL8S0YqE4vjTCA0');
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AIzaSyC80tPfMIW3fpgZ7qGKlt2B2GA3hhdxjVM');

  // Base URLs for external services
  static const String osrmBaseUrl = "https://router.project-osrm.org/route/v1";
  static const String osmSearchUrl = "https://nominatim.openstreetmap.org/search";

  // Security Policy: All network requests must use HTTPS
  static const bool enforceHttps = true;
  
  // Timeout settings for robust network handling
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Production Strategy Note:
  /// Moving to a backend proxy (e.g., Firebase Functions) is highly recommended.
  /// The app should call YOUR server, and your server calls Google/Gemini.
  /// This prevents your API keys from being extracted from the APK.
}
