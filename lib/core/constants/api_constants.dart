import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static const String localHostPort = '3000';

  /// Mengambil Base URL dari environment dengan prioritas:
  /// 1. File `.env` (variabel `BASE_URL` atau `API_BASE_URL`)
  /// 2. Flag `--dart-define` saat compile (contoh: `--dart-define=BASE_URL=http://...`)
  /// 3. Nilai default fallback
  static String get defaultBaseUrl {
    // 1. Prioritas utama: File .env
    final envUrl = dotenv.isInitialized
        ? (dotenv.env['BASE_URL'] ?? dotenv.env['API_BASE_URL'])
        : null;
    if (envUrl != null && envUrl.trim().isNotEmpty) {
      return envUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }

    // 2. Prioritas kedua: --dart-define
    const dartDefineUrl = String.fromEnvironment('BASE_URL');
    if (dartDefineUrl.isNotEmpty) {
      return dartDefineUrl.trim().replaceAll(RegExp(r'/+$'), '');
    }

    // 3. Fallback default
    return 'http://127.0.0.1:3000/api';
  }

  /// Daftar kandidat URL backend yang dicoba otomatis untuk auto-fallback
  static List<String> get candidateBaseUrls {
    final activeUrl = defaultBaseUrl;
    final List<String> candidates = [
      activeUrl,
      'http://127.0.0.1:3000/api',
      'http://192.168.123.75:3000/api',
      'http://localhost:3000/api',
      'http://10.109.105.5:3000/api',
      'http://192.168.1.2:3000/api',
      'http://192.168.1.18:3000/api',
      'http://10.0.2.2:3000/api',
    ];

    // Opsional: daftar URL tambahan dari .env (dipisahkan koma)
    final additional = dotenv.isInitialized ? dotenv.env['ADDITIONAL_BASE_URLS'] : null;
    if (additional != null && additional.trim().isNotEmpty) {
      final extras = additional
          .split(',')
          .map((e) => e.trim().replaceAll(RegExp(r'/+$'), ''))
          .where((e) => e.isNotEmpty);
      candidates.addAll(extras);
    }

    // Filter duplikasi namun tetap mempertahankan urutan prioritas
    return candidates.toSet().toList();
  }

  // Auto-sync idle timeout in seconds (2 minutes = 120 seconds)
  static const int autoSyncIdleTimeoutSeconds = 120;
}
