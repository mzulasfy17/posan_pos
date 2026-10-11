class ApiConstants {
  static const String localHostPort = '3000';

  static const List<String> candidateBaseUrls = [
    'http://10.109.105.5:3000/api',
    'http://127.0.0.1:3000/api',
    'http://localhost:3000/api',
    'http://192.168.1.2:3000/api',
    'http://192.168.1.18:3000/api',
    'http://10.0.2.2:3000/api',
  ];

  static String get defaultBaseUrl {
    return 'http://10.109.105.5:3000/api';
  }

  // Auto-sync idle timeout in seconds (2 minutes = 120 seconds)
  static const int autoSyncIdleTimeoutSeconds = 120;
}
