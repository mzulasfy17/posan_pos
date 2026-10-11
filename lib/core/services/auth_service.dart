import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/cashier_session_model.dart';
import 'posan_api_service.dart';

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String role; // 'kasir', 'admin', 'super_admin', 'barista', 'kitchen'
  final bool isActive;
  final int? merchantId;
  final String? merchantName;
  final String? merchantAddress;
  final String? merchantPhone;
  final String? shift;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isActive = true,
    this.merchantId,
    this.merchantName,
    this.merchantAddress,
    this.merchantPhone,
    this.shift,
  });

  bool get isBarista => role.toLowerCase() == 'barista';
  bool get isKitchen => role.toLowerCase() == 'kitchen' || role.toLowerCase() == 'koki';
  bool get isCashier => role.toLowerCase() == 'kasir';
  bool get isAdmin => role.toLowerCase() == 'admin' || role.toLowerCase() == 'super_admin';
  bool get isSuperAdmin => role.toLowerCase() == 'super_admin';

  String get roleDisplayTitle {
    switch (role.toLowerCase()) {
      case 'barista':
        return 'Stasiun Barista (Minuman)';
      case 'kitchen':
      case 'koki':
        return 'Stasiun Dapur / Koki';
      case 'super_admin':
        return 'Super Administrator';
      case 'admin':
        return 'Administrator Cafe';
      case 'kasir':
      default:
        return 'Kasir Utama';
    }
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as Map<String, dynamic>?;
    final mId = (json['merchant_id'] as num?)?.toInt() ?? (merchant?['id'] as num?)?.toInt();
    final mName = json['merchant_name']?.toString() ?? merchant?['name']?.toString();
    final mAddress = json['merchant_address']?.toString() ?? merchant?['address']?.toString();
    final mPhone = json['merchant_phone']?.toString() ?? merchant?['phone']?.toString();

    return AuthUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Pengguna',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'kasir',
      isActive: json['is_active'] == null || json['is_active'] == true,
      merchantId: mId,
      merchantName: mName,
      merchantAddress: mAddress,
      merchantPhone: mPhone,
      shift: json['shift']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'is_active': isActive,
      'merchant_id': merchantId,
      'merchant_name': merchantName,
      'merchant_address': merchantAddress,
      'merchant_phone': merchantPhone,
      'shift': shift,
    };
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final PosanApiService _api = PosanApiService();

  AuthUser? _currentUser;
  CashierSessionModel? _currentSession;

  AuthUser? get currentUser => _currentUser;
  CashierSessionModel get currentSession =>
      _currentSession ?? CashierSessionModel.empty;

  bool get isLoggedIn => _currentUser != null || _currentSession != null;

  Future<File?> _getSessionFile() async {
    try {
      if (kIsWeb) return null;
      final docsDir = await getApplicationDocumentsDirectory();
      return File(p.join(docsDir.path, 'posan_auth_session.json'));
    } catch (e) {
      debugPrint('AuthService _getSessionFile error: $e');
      return null;
    }
  }

  Future<void> _saveSessionToFile({
    required AuthUser user,
    required CashierSessionModel session,
    String? token,
  }) async {
    try {
      final file = await _getSessionFile();
      if (file == null) return;
      final data = {
        'token': token ?? _api.authToken,
        'user': user.toJson(),
        'session': session.toJson(),
        'saved_at': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
      debugPrint('AuthService: Sesi login berhasil disimpan di ${file.path}');
    } catch (e) {
      debugPrint('AuthService: Gagal menyimpan sesi login ke file: $e');
    }
  }

  Future<void> _clearSavedSession() async {
    try {
      final file = await _getSessionFile();
      if (file != null && await file.exists()) {
        await file.delete();
        debugPrint('AuthService: File sesi login berhasil dihapus.');
      }
    } catch (e) {
      debugPrint('AuthService: Gagal menghapus file sesi login: $e');
    }
  }

  /// Restore saved session from persistent storage on app launch
  Future<AuthUser?> restoreSession() async {
    if (_currentUser != null) return _currentUser;
    try {
      final file = await _getSessionFile();
      if (file == null || !await file.exists()) {
        debugPrint('AuthService: Tidak ada file sesi tersimpan.');
        return null;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;

      final data = jsonDecode(content) as Map<String, dynamic>;
      final userData = data['user'] as Map<String, dynamic>?;
      if (userData == null) return null;

      final user = AuthUser.fromJson(userData);
      final token = data['token']?.toString();
      if (token != null && token.isNotEmpty) {
        _api.setAuthToken(token);
      }

      CashierSessionModel session;
      if (data['session'] != null) {
        session = CashierSessionModel.fromJson(data['session'] as Map<String, dynamic>);
      } else {
        String stationName = 'Kasir Utama';
        if (user.isBarista) stationName = 'Stasiun Barista';
        if (user.isKitchen) stationName = 'Stasiun Dapur';

        final mName = user.merchantName?.isNotEmpty == true
            ? user.merchantName!
            : 'POSAN Cafe';
        final mAddress = user.merchantAddress?.isNotEmpty == true
            ? user.merchantAddress!
            : 'Cabang Utama';

        session = CashierSessionModel(
          merchantId: user.merchantId,
          cashierName: user.name,
          cashierGreeting: 'Selamat bertugas, ${user.name} 👋',
          role: user.role,
          merchantName: mName,
          outletLocation: mAddress,
          shift: user.shift ?? 'Shift Utama',
          shiftNumber: 'Shift 1',
          activeStation: stationName,
        );
      }

      _currentUser = user;
      _currentSession = session;
      debugPrint('AuthService: Sesi login berhasil dipulihkan untuk ${user.name} (${user.role})');
      return user;
    } catch (e) {
      debugPrint('AuthService: Gagal memulihkan sesi login: $e');
      return null;
    }
  }

  void updateSession(CashierSessionModel session) {
    _currentSession = session;
    if (_currentUser != null) {
      _saveSessionToFile(user: _currentUser!, session: session);
    }
  }

  /// Sign in using PostgreSQL REST API backend
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    
    try {
      final res = await _api.login(
        email: cleanEmail,
        password: password.trim(),
      );

      if (res != null && res['user'] != null) {
        final userData = res['user'] as Map<String, dynamic>;
        final user = AuthUser.fromJson(userData);

        // Strict RBAC: Admin and Super Admin are NOT permitted to access the Mobile POS App
        final roleLower = user.role.toLowerCase();
        if (roleLower == 'admin' || roleLower == 'super_admin' || roleLower == 'superadmin') {
          _currentUser = null;
          _currentSession = null;
          throw Exception(
            'Akses Ditolak: Akun Admin dan Super Admin hanya dapat login melalui Web Admin / Dashboard Backoffice, bukan di Aplikasi Kasir Mobile.',
          );
        }

        final token = res['token']?.toString();
        if (token != null && token.isNotEmpty) {
          _api.setAuthToken(token);
        }

        _currentUser = user;

        String stationName = 'Kasir Utama';
        if (user.isBarista) stationName = 'Stasiun Barista';
        if (user.isKitchen) stationName = 'Stasiun Dapur';

        final mName = user.merchantName?.isNotEmpty == true
            ? user.merchantName!
            : 'POSAN Cafe';
        final mAddress = user.merchantAddress?.isNotEmpty == true
            ? user.merchantAddress!
            : 'Cabang Utama';

        _currentSession = CashierSessionModel(
          merchantId: user.merchantId,
          cashierName: user.name,
          cashierGreeting: 'Selamat bertugas, ${user.name} 👋',
          role: user.role,
          merchantName: mName,
          outletLocation: mAddress,
          shift: user.shift ?? 'Shift Utama',
          shiftNumber: 'Shift 1',
          activeStation: stationName,
          todaySalesAmount: 0.0,
          todayTransactionCount: 0,
          pendingSyncCount: 0,
          lastSyncTime: 'Baru saja',
          localStorageCount: 0,
          isOnline: true,
        );

        if (rememberMe) {
          await _saveSessionToFile(
            user: user,
            session: _currentSession!,
            token: token,
          );
        } else {
          await _clearSavedSession();
        }

        return user;
      } else {
        throw Exception('Respons server tidak valid.');
      }
    } catch (e) {
      debugPrint('AuthService signIn error: $e');
      rethrow;
    }
  }

  /// Fast PIN-based login for POS Cashier terminal
  Future<CashierSessionModel> signInWithPin({
    required String cashierName,
    required String pin,
    required String outlet,
    required String shift,
    bool rememberMe = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (pin.length == 4) {
      final session = CashierSessionModel.empty.copyWith(
        cashierName: cashierName,
        cashierGreeting: 'Selamat pagi, $cashierName 👋',
        outletLocation: outlet,
        shift: shift,
        isOnline: true,
      );
      _currentSession = session;
      _currentUser = AuthUser(
        id: 'pin-user',
        name: cashierName,
        email: 'pin@posan.local',
        role: session.role,
      );

      if (rememberMe) {
        await _saveSessionToFile(user: _currentUser!, session: session);
      }

      return session;
    } else {
      throw Exception('PIN tidak valid. Masukkan 4 digit angka.');
    }
  }

  /// Load current active session
  Future<CashierSessionModel> loadCurrentSession() async {
    if (_currentSession == null) {
      await restoreSession();
    }
    return currentSession;
  }

  /// Request password reset link / simulation
  Future<void> resetPassword(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('Password reset link requested for: $email');
  }

  /// Sign out current user
  Future<void> signOut() async {
    _currentUser = null;
    _currentSession = null;
    _api.setAuthToken(null);
    await _clearSavedSession();
  }
}
