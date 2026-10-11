import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service untuk meredupkan layar secara otomatis jika kasir tidak digunakan (Idle Auto-Dim).
/// Menghemat baterai, mencegah burn-in layar OLED/AMOLED, dan menjaga keamanan visual POS.
class AutoDimService extends ChangeNotifier {
  static final AutoDimService _instance = AutoDimService._internal();
  factory AutoDimService() => _instance;
  AutoDimService._internal();

  Timer? _idleTimer;
  bool _isAutoDimEnabled = true;
  bool _isDimmed = false;
  int _idleTimeoutSeconds = 60; // Default 60 detik idle

  bool get isAutoDimEnabled => _isAutoDimEnabled;
  bool get isDimmed => _isDimmed;
  int get idleTimeoutSeconds => _idleTimeoutSeconds;

  /// Inisialisasi awal
  void init() {
    startTimer();
  }

  /// Panggil setiap kali ada interaksi sentuhan dari pengguna
  void onUserInteraction() {
    if (_isDimmed) {
      wakeUp();
    } else {
      resetTimer();
    }
  }

  /// Mulai / Reset timer idle
  void resetTimer() {
    _idleTimer?.cancel();
    if (!_isAutoDimEnabled) return;

    _idleTimer = Timer(Duration(seconds: _idleTimeoutSeconds), () {
      if (!_isDimmed) {
        _isDimmed = true;
        notifyListeners();
        debugPrint('🌙 AutoDimService: Layar diredupkan karena tidak ada interaksi selama ${_idleTimeoutSeconds}s');
      }
    });
  }

  void startTimer() => resetTimer();

  /// Bangunkan layar kembali ke kecerahan 100%
  void wakeUp() {
    _idleTimer?.cancel();
    if (_isDimmed) {
      _isDimmed = false;
      notifyListeners();
      debugPrint('☀️ AutoDimService: Layar diaktifkan kembali penuh.');
    }
    resetTimer();
  }

  /// Aktifkan / Nonaktifkan fitur redup otomatis
  void setAutoDimEnabled(bool enabled) {
    _isAutoDimEnabled = enabled;
    if (!enabled && _isDimmed) {
      _isDimmed = false;
    }
    if (enabled) {
      resetTimer();
    } else {
      _idleTimer?.cancel();
    }
    notifyListeners();
  }

  /// Atur durasi idle (dalam detik)
  void setIdleTimeoutSeconds(int seconds) {
    _idleTimeoutSeconds = seconds;
    resetTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }
}
