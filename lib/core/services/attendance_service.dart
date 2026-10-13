import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/attendance_model.dart';
import '../database/local_database_service.dart';
import 'auth_service.dart';
import 'posan_api_service.dart';

/// Service manajemen state absensi karyawan POSAN.
/// Terhubung langsung ke database lokal (SQLite offline-first) dan REST API PostgreSQL backend.
class AttendanceService extends ChangeNotifier {
  static final AttendanceService _instance = AttendanceService._internal();
  factory AttendanceService() => _instance;
  AttendanceService._internal() {
    _initializeInitialState();
    loadAttendanceData();
  }

  final LocalDatabaseService _localDb = LocalDatabaseService();
  late AttendanceRecordModel _todayRecord;
  final List<AttendanceRecordModel> _historyRecords = [];
  String _selectedFilterPeriod = 'all'; // 'all', 'week', 'month'
  bool _isLoading = false;

  AttendanceRecordModel get todayRecord => _todayRecord;
  List<AttendanceRecordModel> get allHistory => List.unmodifiable(_historyRecords);
  String get selectedFilterPeriod => _selectedFilterPeriod;
  bool get isLoading => _isLoading;

  /// Helper boolean untuk status tombol
  bool get canCheckIn => _todayRecord.status == AttendanceStatus.notCheckedIn;
  bool get canCheckOut => _todayRecord.status == AttendanceStatus.working;
  bool get isCompleted => _todayRecord.status == AttendanceStatus.completed;

  /// Inisialisasi status dasar absensi hari ini (berdasarkan staf yang sedang login)
  void _initializeInitialState() {
    final now = DateTime.now();
    final user = AuthService().currentUser;
    final session = AuthService().currentSession;

    final currentUserId = user?.id ?? (session.cashierName.isNotEmpty ? session.cashierName : 'emp-001');
    final currentUserName = user?.name.isNotEmpty == true
        ? user!.name
        : (session.cashierName.isNotEmpty ? session.cashierName : 'Karyawan POSAN');
    final currentRole = user?.role ?? session.role;

    _todayRecord = AttendanceRecordModel(
      id: 'att-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$currentUserId',
      userId: currentUserId,
      userName: currentUserName,
      role: currentRole,
      date: DateTime(now.year, now.month, now.day),
      checkInTime: null,
      checkOutTime: null,
      status: AttendanceStatus.notCheckedIn,
    );

    _historyRecords.clear();
  }

  /// Memuat riwayat absensi dan status hari ini secara otomatis dari SQLite lokal & Backend PostgreSQL
  Future<void> loadAttendanceData({bool forceRefresh = false}) async {
    final user = AuthService().currentUser;
    final session = AuthService().currentSession;
    final currentUserId = user?.id ?? (session.cashierName.isNotEmpty ? session.cashierName : 'emp-001');

    _isLoading = true;
    notifyListeners();

    // 1. Memuat dari database lokal SQLite terlebih dahulu (instan offline-first)
    try {
      final cachedToday = await _localDb.getTodayAttendance(currentUserId);
      if (cachedToday != null) {
        _todayRecord = cachedToday;
      }
      final cachedHistory = await _localDb.getAttendanceHistory(currentUserId);
      if (cachedHistory.isNotEmpty) {
        _historyRecords.clear();
        _historyRecords.addAll(cachedHistory);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('AttendanceService: Membaca cache SQLite: $e');
    }

    // 2. Sinkronkan dengan Backend REST API PostgreSQL
    try {
      final api = PosanApiService();
      final reachableUrl = await api.ensureReachableUrl();
      
      // Ambil status hari ini dari API
      final todayUrl = '$reachableUrl/attendance/today?user_id=${Uri.encodeComponent(currentUserId)}';
      final todayRes = await http.get(
        Uri.parse(todayUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (api.authToken != null) 'Authorization': 'Bearer ${api.authToken}',
        },
      ).timeout(const Duration(seconds: 4));

      if (todayRes.statusCode == 200) {
        final todayData = jsonDecode(todayRes.body);
        if (todayData['hasCheckedIn'] == true && todayData['record'] != null) {
          final serverToday = AttendanceRecordModel.fromJson(todayData['record'] as Map<String, dynamic>);
          _todayRecord = serverToday;
          await _localDb.saveAttendanceRecord(serverToday, syncStatus: 'synced');
        }
      }

      // Ambil riwayat absensi staf dari API
      final historyUrl = '$reachableUrl/attendance?user_id=${Uri.encodeComponent(currentUserId)}&period=all';
      final historyRes = await http.get(
        Uri.parse(historyUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (api.authToken != null) 'Authorization': 'Bearer ${api.authToken}',
        },
      ).timeout(const Duration(seconds: 4));

      if (historyRes.statusCode == 200) {
        final historyData = jsonDecode(historyRes.body);
        final recordsJson = historyData['attendanceRecords'] as List?;
        if (recordsJson != null) {
          final List<AttendanceRecordModel> fetchedList = [];
          for (final item in recordsJson) {
            try {
              fetchedList.add(AttendanceRecordModel.fromJson(item as Map<String, dynamic>));
            } catch (_) {}
          }

          if (fetchedList.isNotEmpty) {
            _historyRecords.clear();
            _historyRecords.addAll(fetchedList);
            await _localDb.saveAttendanceBatch(fetchedList);
          }
        }
      }
    } catch (e) {
      debugPrint('AttendanceService: Gagal sinkronisasi data absensi ke cloud (menggunakan cache lokal): $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Catat Absen Masuk ke SQLite Lokal dan sinkronkan ke PostgreSQL Backend
  Future<bool> checkIn() async {
    if (!canCheckIn) return false;

    final now = DateTime.now();
    _todayRecord = _todayRecord.copyWith(
      checkInTime: now,
      status: AttendanceStatus.working,
    );

    notifyListeners();

    // Simpan langsung ke database SQLite lokal (offline-first)
    try {
      await _localDb.saveAttendanceRecord(_todayRecord, syncStatus: 'pending');
    } catch (e) {
      debugPrint('Local SQLite save skipped: $e');
    }

    // Sinkronkan ke PostgreSQL REST API Backend
    try {
      final api = PosanApiService();
      final reachableUrl = await api.ensureReachableUrl();
      final url = '$reachableUrl/attendance/check-in';
      
      final res = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (api.authToken != null) 'Authorization': 'Bearer ${api.authToken}',
        },
        body: jsonEncode({
          'user_id': _todayRecord.userId,
          'user_name': _todayRecord.userName,
          'role': _todayRecord.role,
          'merchant_id': AuthService().currentUser?.merchantId,
          'notes': 'Absen Masuk POSAN Mobile POS',
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['data'] != null) {
          final serverRec = AttendanceRecordModel.fromJson(data['data'] as Map<String, dynamic>);
          _todayRecord = serverRec;
          await _localDb.saveAttendanceRecord(serverRec, syncStatus: 'synced');
          notifyListeners();
        }
        debugPrint('Cloud attendance check-in synced berhasil: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Cloud attendance check-in offline (tersimpan lokal): $e');
    }

    return true;
  }

  /// Catat Absen Keluar ke SQLite Lokal dan sinkronkan ke PostgreSQL Backend
  Future<bool> checkOut() async {
    if (!canCheckOut) return false;

    final now = DateTime.now();
    _todayRecord = _todayRecord.copyWith(
      checkOutTime: now,
      status: AttendanceStatus.completed,
    );

    // Update list riwayat lokal
    _historyRecords.removeWhere((r) => r.id == _todayRecord.id);
    _historyRecords.insert(0, _todayRecord);

    notifyListeners();

    // Simpan ke SQLite lokal
    try {
      await _localDb.saveAttendanceRecord(_todayRecord, syncStatus: 'pending');
    } catch (e) {
      debugPrint('Local SQLite checkout save skipped: $e');
    }

    // Sinkronkan ke PostgreSQL REST API Backend
    try {
      final api = PosanApiService();
      final reachableUrl = await api.ensureReachableUrl();
      final url = '$reachableUrl/attendance/check-out';
      
      final res = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (api.authToken != null) 'Authorization': 'Bearer ${api.authToken}',
        },
        body: jsonEncode({
          'user_id': _todayRecord.userId,
          'notes': 'Absen Pulang POSAN Mobile POS',
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['data'] != null) {
          final serverRec = AttendanceRecordModel.fromJson(data['data'] as Map<String, dynamic>);
          _todayRecord = serverRec;
          _historyRecords.removeWhere((r) => r.id == serverRec.id);
          _historyRecords.insert(0, serverRec);
          await _localDb.saveAttendanceRecord(serverRec, syncStatus: 'synced');
          notifyListeners();
        }
        debugPrint('Cloud attendance check-out synced berhasil: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Cloud attendance check-out offline (tersimpan lokal): $e');
    }

    return true;
  }

  /// Atur filter periode riwayat absensi ('all', 'week', 'month')
  void setFilterPeriod(String period) {
    _selectedFilterPeriod = period;
    notifyListeners();
  }

  /// Ambil riwayat yang terfilter berdasarkan pilihan periode
  List<AttendanceRecordModel> get filteredHistory {
    final now = DateTime.now();
    switch (_selectedFilterPeriod) {
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startThreshold = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return _historyRecords.where((item) => item.date.isAfter(startThreshold.subtract(const Duration(seconds: 1)))).toList();
      case 'month':
        final startOfMonth = DateTime(now.year, now.month, 1);
        return _historyRecords.where((item) => item.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1)))).toList();
      case 'all':
      default:
        return _historyRecords;
    }
  }

  /// Segarkan data absensi dari database dan backend
  Future<void> refresh() async {
    await loadAttendanceData(forceRefresh: true);
  }

  /// Reset simulasi absensi hari ini (untuk unit testing / reset lokal)
  void resetAttendanceForDemo() {
    _initializeInitialState();
    notifyListeners();
  }

  /// Bersihkan riwayat absensi (untuk unit testing kondisi kosong)
  void clearHistoryForDemo() {
    _historyRecords.clear();
    notifyListeners();
  }

  /// Tambahkan sampel riwayat untuk pengujian unit test
  void addSampleRecordsForTesting(List<AttendanceRecordModel> records) {
    _historyRecords.clear();
    _historyRecords.addAll(records);
    notifyListeners();
  }
}
