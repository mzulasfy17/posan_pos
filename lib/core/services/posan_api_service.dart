import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class PosanApiService {
  static final PosanApiService _instance = PosanApiService._internal();
  factory PosanApiService() => _instance;
  PosanApiService._internal();

  String _baseUrl = ApiConstants.defaultBaseUrl;
  String? _authToken;

  String get baseUrl => _baseUrl;
  set baseUrl(String url) {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  void resetBaseUrl() {
    _baseUrl = ApiConstants.defaultBaseUrl;
  }

  String? get authToken => _authToken;
  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Ensure a working backend URL is selected
  Future<String> ensureReachableUrl() async {
    // 1. Test current _baseUrl
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health/db'), headers: _headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['connected'] == true) {
          debugPrint('Backend URL reachable & database connected: $_baseUrl');
          return _baseUrl;
        }
      }
    } catch (e) {
      debugPrint('Base URL $_baseUrl unreachable ($e), testing candidates...');
    }

    // 2. Probe candidates in parallel / sequence
    for (final candidate in ApiConstants.candidateBaseUrls) {
      if (candidate == _baseUrl) continue;
      try {
        final response = await http
            .get(Uri.parse('$candidate/health/db'), headers: _headers)
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['connected'] == true) {
            _baseUrl = candidate;
            debugPrint('PosanApiService switched to reachable backend URL: $_baseUrl');
            return _baseUrl;
          }
        }
      } catch (_) {}
    }

    debugPrint('No reachable backend URL found among candidates. Remaining on: $_baseUrl');
    return _baseUrl;
  }

  /// Health check connection to PostgreSQL backend with auto fallback
  Future<bool> checkConnection() async {
    final activeUrl = await ensureReachableUrl();
    try {
      final response = await http
          .get(Uri.parse('$activeUrl/health/db'), headers: _headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool isDbConnected = data['connected'] == true;
        debugPrint('PostgreSQL Database Online: $isDbConnected (via $activeUrl)');
        return isDbConnected;
      }
    } catch (e) {
      debugPrint('checkConnection error: $e');
    }
    return false;
  }

  /// Login directly to Postgres backend with auto URL recovery
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    await ensureReachableUrl();
    
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: _headers,
            body: jsonEncode({
              'email': email.trim(),
              'password': password.trim(),
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _authToken = data['token'];
        return data;
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Login backend gagal');
      }
    } catch (e) {
      // Retry once after re-probing reachable URL
      try {
        await ensureReachableUrl();
        final retryRes = await http
            .post(
              Uri.parse('$_baseUrl/auth/login'),
              headers: _headers,
              body: jsonEncode({
                'email': email.trim(),
                'password': password.trim(),
              }),
            )
            .timeout(const Duration(seconds: 6));

        if (retryRes.statusCode == 200) {
          final data = jsonDecode(retryRes.body);
          _authToken = data['token'];
          return data;
        }
      } catch (_) {}

      debugPrint('PosanApiService login error: $e');
      rethrow;
    }
  }

  /// Fetch full catalog snapshot from PostgreSQL for SQLite offline cache
  Future<Map<String, dynamic>?> fetchCatalogSnapshot() async {
    try {
      await ensureReachableUrl();
      final response = await http
          .get(Uri.parse('$_baseUrl/transactions/catalog/snapshot'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('PosanApiService fetchCatalogSnapshot error: $e');
      return null;
    }
  }

  /// Fetch orders for Barista station (Minuman) - default active only
  Future<List<Map<String, dynamic>>> getBaristaOrders({String status = 'active'}) async {
    try {
      await ensureReachableUrl();
      final response = await http
          .get(Uri.parse('$_baseUrl/orders/barista?status=$status'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('PosanApiService getBaristaOrders error: $e');
      return [];
    }
  }

  /// Fetch orders for Kitchen/Koki station (Makanan & Pastry) - default active only
  Future<List<Map<String, dynamic>>> getKitchenOrders({String status = 'active'}) async {
    try {
      await ensureReachableUrl();
      final response = await http
          .get(Uri.parse('$_baseUrl/orders/kitchen?status=$status'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('PosanApiService getKitchenOrders error: $e');
      return [];
    }
  }

  /// Update status of a specific order item (e.g. processing, completed)
  Future<Map<String, dynamic>> updateOrderItemStatus({
    required int itemId,
    required String nextStatus,
    String? updatedBy,
    String? processedBy,
  }) async {
    try {
      await ensureReachableUrl();
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/orders/items/$itemId/status'),
            headers: _headers,
            body: jsonEncode({
              'next_status': nextStatus,
              ...? (updatedBy != null ? {'updated_by': updatedBy} : null),
              ...? (processedBy != null ? {'processed_by': processedBy} : null),
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Gagal memperbarui status pesanan.');
      }
    } catch (e) {
      debugPrint('PosanApiService updateOrderItemStatus error: $e');
      rethrow;
    }
  }

  /// Kasir/Admin update all items status of a transaction
  Future<Map<String, dynamic>> updateTransactionItemsStatus({
    required String receiptOrId,
    required String nextStatus,
    String? updatedBy,
    String? station,
  }) async {
    try {
      await ensureReachableUrl();
      final clean = receiptOrId.replaceAll('#', '').trim();
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/orders/transactions/$clean/status'),
            headers: _headers,
            body: jsonEncode({
              'next_status': nextStatus,
              ...? (updatedBy != null ? {'updated_by': updatedBy} : null),
              ...? (station != null ? {'station': station} : null),
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Gagal memperbarui status transaksi.');
      }
    } catch (e) {
      debugPrint('PosanApiService updateTransactionItemsStatus error: $e');
      rethrow;
    }
  }

  /// Get order logs (currentmillis history) for a specific receipt
  Future<List<Map<String, dynamic>>> getOrderLogs(String receiptNumber) async {
    try {
      await ensureReachableUrl();
      final clean = receiptNumber.replaceAll('#', '').trim();
      final response = await http
          .get(Uri.parse('$_baseUrl/orders/logs/$clean'), headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('PosanApiService getOrderLogs error: $e');
      return [];
    }
  }

  /// Get receipt customization settings (Header & Footer)
  Future<Map<String, dynamic>?> getReceiptSettings() async {
    try {
      await ensureReachableUrl();
      final response = await http
          .get(Uri.parse('$_baseUrl/settings/receipt'), headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('PosanApiService getReceiptSettings error: $e');
      return null;
    }
  }

  /// Create transaction online directly
  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> payload) async {
    try {
      await ensureReachableUrl();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/transactions'),
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Gagal membuat transaksi di server');
      }
    } catch (e) {
      debugPrint('PosanApiService createTransaction error: $e');
      rethrow;
    }
  }

  /// Batch sync offline transactions from SQLite to PostgreSQL
  Future<Map<String, dynamic>> syncBatchTransactions(
    List<Map<String, dynamic>> transactions,
  ) async {
    if (transactions.isEmpty) {
      return {'success': true, 'syncedCount': 0, 'results': []};
    }

    try {
      await ensureReachableUrl();
      final response = await http
          .post(
            Uri.parse('$_baseUrl/transactions/sync-batch'),
            headers: _headers,
            body: jsonEncode({'transactions': transactions}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Sync batch gagal pada server');
      }
    } catch (e) {
      debugPrint('PosanApiService syncBatchTransactions error: $e');
      rethrow;
    }
  }

  /// Fetch recent transactions directly from PostgreSQL
  Future<List<Map<String, dynamic>>> fetchRecentTransactions({int limit = 30}) async {
    try {
      await ensureReachableUrl();
      final response = await http
          .get(Uri.parse('$_baseUrl/transactions?limit=$limit'), headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('PosanApiService fetchRecentTransactions error: $e');
      return [];
    }
  }

  /// Fetch today's sales metrics & stats from PostgreSQL
  Future<Map<String, dynamic>?> fetchTransactionStats() async {
    try {
      await ensureReachableUrl();
      final response = await http
          .get(Uri.parse('$_baseUrl/transactions/stats'), headers: _headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('PosanApiService fetchTransactionStats error: $e');
      return null;
    }
  }
}
