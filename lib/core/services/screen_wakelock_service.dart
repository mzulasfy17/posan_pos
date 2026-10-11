import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Service untuk mengontrol status layar kasir (Cegah layar mati / Keep Screen Awake).
/// Memastikan layar perangkat tetap menyala selama aplikasi kasir POSAN berjalan.
class ScreenWakelockService extends ChangeNotifier {
  static final ScreenWakelockService _instance = ScreenWakelockService._internal();
  factory ScreenWakelockService() => _instance;
  ScreenWakelockService._internal();

  bool _isKeepScreenOn = true;

  bool get isKeepScreenOn => _isKeepScreenOn;

  /// Inisialisasi awal saat aplikasi mulai dibuka.
  /// Secara default diaktifkan (Keep Screen ON) untuk operasional kasir.
  Future<void> init() async {
    try {
      await WakelockPlus.enable();
      _isKeepScreenOn = true;
      notifyListeners();
    } catch (e) {
      debugPrint('ScreenWakelockService init error: $e');
    }
  }

  /// Mengaktifkan atau menonaktifkan mode layar tetap menyala.
  Future<void> setKeepScreenOn(bool enable) async {
    try {
      if (enable) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
      _isKeepScreenOn = enable;
      notifyListeners();
    } catch (e) {
      debugPrint('ScreenWakelockService toggle error: $e');
    }
  }

  /// Toggle status aktif/nonaktif
  Future<void> toggle() async {
    await setKeepScreenOn(!_isKeepScreenOn);
  }
}
