import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/api_constants.dart';
import '../database/local_database_service.dart';
import '../../models/cart_order_model.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/receipt_settings_model.dart';
import '../../models/recent_transaction_model.dart';
import 'auth_service.dart';
import 'posan_api_service.dart';

class OfflineSyncManager {
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  factory OfflineSyncManager() => _instance;
  OfflineSyncManager._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();
  final PosanApiService _api = PosanApiService();

  int? get _activeMerchantId => AuthService().currentUser?.merchantId;

  // 2-Minute Idle Auto-Sync Timer State
  static const int kIdleTimeoutSeconds = ApiConstants.autoSyncIdleTimeoutSeconds; // 120 seconds
  Timer? _countdownTimer;
  int _secondsRemaining = kIdleTimeoutSeconds;
  DateTime _lastTransactionTime = DateTime.now();

  // Notifiers for reactive UI updates
  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier<int>(kIdleTimeoutSeconds);
  final ValueNotifier<int> pendingSyncCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<String> lastSyncTimeNotifier = ValueNotifier<String>('Belum sinkron');
  final ValueNotifier<String> syncStatusMessageNotifier = ValueNotifier<String>('Siap');

  bool get isSyncing => isSyncingNotifier.value;
  bool get isOnline => isOnlineNotifier.value;
  int get pendingCount => pendingSyncCountNotifier.value;
  int get secondsRemaining => remainingSecondsNotifier.value;
  DateTime get lastTransactionTime => _lastTransactionTime;

  String get formattedCountdown {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Initialize SQLite Database and start the 2-Minute Inactivity / Idle Auto-Sync Timer
  Future<void> initialize() async {
    debugPrint('Initializing POSAN Offline Sync Manager & SQLite Database...');
    try {
      await _localDb.database;
      await refreshPendingCount();
      await checkOnlineStatus();
      _startIdleCountdownTimer();
      debugPrint('POSAN Offline Sync Manager active (2-minute idle timer started).');
    } catch (e) {
      debugPrint('OfflineSyncManager initialization error: $e');
    }
  }

  /// Start the 1-second interval countdown timer
  void _startIdleCountdownTimer() {
    _countdownTimer?.cancel();
    _secondsRemaining = kIdleTimeoutSeconds;
    remainingSecondsNotifier.value = _secondsRemaining;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        _secondsRemaining--;
        remainingSecondsNotifier.value = _secondsRemaining;
      } else {
        // 2 minutes of inactivity reached with no transactions -> Trigger Auto Sync!
        debugPrint('⏰ 2 minutes idle without transactions reached! Triggering auto-sync...');
        _secondsRemaining = kIdleTimeoutSeconds;
        remainingSecondsNotifier.value = _secondsRemaining;
        performAutoSync(trigger: 'Auto (2 Menit Idle)');
      }
    });
  }

  /// Reset the 2-minute timer when a new transaction is made
  void resetIdleTimer() {
    _lastTransactionTime = DateTime.now();
    _secondsRemaining = kIdleTimeoutSeconds;
    remainingSecondsNotifier.value = _secondsRemaining;
    debugPrint('Reset 2-minute idle timer. Next auto-sync in 120s.');
  }

  /// Refresh pending count from SQLite
  Future<int> refreshPendingCount({int? merchantId}) async {
    try {
      final mId = merchantId ?? _activeMerchantId;
      final count = await _localDb.getPendingSyncCount(merchantId: mId);
      pendingSyncCountNotifier.value = count;
      return count;
    } catch (e) {
      debugPrint('Error refreshing pending count: $e');
      return 0;
    }
  }

  /// Check online connection to PostgreSQL backend
  Future<bool> checkOnlineStatus() async {
    try {
      final isPostgresOnline = await _api.checkConnection();
      isOnlineNotifier.value = isPostgresOnline;
      return isPostgresOnline;
    } catch (_) {
      isOnlineNotifier.value = false;
      return false;
    }
  }

  /// Load initial catalog from SQLite offline database (with online sync update)
  Future<Map<String, dynamic>> loadCatalog({int? merchantId}) async {
    final mId = merchantId ?? _activeMerchantId;

    // 1. First, retrieve from local SQLite for instant zero-latency loading
    List<CategoryModel> categories = await _localDb.getCategories(merchantId: mId);
    List<ProductModel> products = await _localDb.getProducts(merchantId: mId);

    debugPrint('Loaded from SQLite (Merchant: $mId): ${categories.length} categories, ${products.length} products');

    // 2. If SQLite is empty or online, fetch latest snapshot from PostgreSQL backend
    if (categories.isEmpty || products.isEmpty || isOnline) {
      try {
        final onlineSnapshot = await _fetchOnlineSnapshot();
        if (onlineSnapshot != null) {
          categories = onlineSnapshot['categories'] as List<CategoryModel>;
          products = onlineSnapshot['products'] as List<ProductModel>;
          
          // Save fresh snapshot to SQLite with merchant isolation
          await _localDb.saveCategories(categories, merchantId: mId);
          await _localDb.saveProducts(products, merchantId: mId);
        }
      } catch (e) {
        debugPrint('Online catalog fetch error, using SQLite cache: $e');
      }

      try {
        final onlineTrxs = await _api.fetchRecentTransactions(limit: 50);
        if (onlineTrxs.isNotEmpty) {
          await _localDb.syncOnlineTransactions(onlineTrxs, merchantId: mId);
        }
      } catch (_) {}
    }

    return {
      'categories': categories,
      'products': products,
    };
  }

  /// Helper to fetch catalog snapshot from PostgreSQL backend
  Future<Map<String, dynamic>?> _fetchOnlineSnapshot() async {
    try {
      final snapshot = await _api.fetchCatalogSnapshot();
      if (snapshot != null && snapshot['products'] != null) {
        final rawCats = snapshot['categories'] as List<dynamic>? ?? [];
        final rawProds = snapshot['products'] as List<dynamic>? ?? [];

        final categories = <CategoryModel>[
          const CategoryModel(id: 'all', name: 'Semua', icon: Icons.grid_view_rounded),
        ];
        for (final c in rawCats) {
          final id = c['id']?.toString() ?? '';
          final name = c['name']?.toString() ?? 'Kategori';
          final nameLower = name.toLowerCase();

          IconData icon = Icons.coffee_rounded;
          if (nameLower.contains('minum') || nameLower.contains('drink') || nameLower.contains('coffee') || nameLower.contains('teh')) {
            icon = Icons.local_drink_rounded;
          } else if (nameLower.contains('makan') || nameLower.contains('food') || nameLower.contains('nasi')) {
            icon = Icons.restaurant_rounded;
          } else if (nameLower.contains('snack') || nameLower.contains('kentang') || nameLower.contains('roti') || nameLower.contains('pastry')) {
            icon = Icons.cookie_rounded;
          }

          categories.add(CategoryModel(id: id, name: name, icon: icon));
        }

        final products = rawProds.map<ProductModel>((p) {
          final id = p['id']?.toString() ?? '';
          final name = p['name']?.toString() ?? 'Menu';
          final catId = p['category_id']?.toString() ?? '';
          final catName = p['category_name']?.toString() ?? 'MENU';
          
          double price = 0.0;
          if (p['price'] is num) {
            price = (p['price'] as num).toDouble();
          } else if (p['price'] != null) {
            price = double.tryParse(p['price'].toString()) ?? 0.0;
          }

          final rawActive = p['is_active'];
          final isAvailable = rawActive == null || rawActive == true || rawActive == 1 || rawActive == 'true' || rawActive == 't';

          // Extract image from server (image_url or description containing photo)
          final rawImgUrl = p['image_url']?.toString().trim() ?? '';
          final rawDesc = p['description']?.toString().trim() ?? '';

          String finalAsset = '';
          if (rawImgUrl.isNotEmpty && (rawImgUrl.startsWith('http') || rawImgUrl.startsWith('data:image') || rawImgUrl.startsWith('/') || rawImgUrl.startsWith('assets/'))) {
            finalAsset = rawImgUrl;
          } else if (rawDesc.isNotEmpty && (rawDesc.startsWith('http') || rawDesc.startsWith('data:image') || rawDesc.startsWith('/') || rawDesc.startsWith('assets/'))) {
            finalAsset = rawDesc;
          } else if (rawImgUrl.isNotEmpty) {
            finalAsset = rawImgUrl;
          }

          // Fallback to local assets matching common cafe menu names if no server image
          if (finalAsset.isEmpty) {
            final nameLower = name.toLowerCase();
            if (nameLower.contains('croissant') || nameLower.contains('butter') || nameLower.contains('pastry') || nameLower.contains('cheesecake') || nameLower.contains('cake') || nameLower.contains('bakery') || nameLower.contains('roti')) {
              finalAsset = 'assets/images/butter_croissant.jpg';
            } else if (nameLower.contains('almond')) {
              finalAsset = 'assets/images/almond_croissant.jpg';
            } else if (nameLower.contains('matcha') || nameLower.contains('taro') || nameLower.contains('tea') || nameLower.contains('teh') || nameLower.contains('green')) {
              finalAsset = 'assets/images/matcha_latte.jpg';
            } else if (nameLower.contains('americano') || nameLower.contains('black') || nameLower.contains('espresso')) {
              finalAsset = 'assets/images/iced_americano.jpg';
            } else if (nameLower.contains('aren') || nameLower.contains('kopi') || nameLower.contains('coffee') || nameLower.contains('coffe')) {
              finalAsset = 'assets/images/kopi_susu_aren.jpg';
            } else {
              finalAsset = 'assets/images/caramel_macchiato.jpg';
            }
          }

          return ProductModel(
            id: id,
            name: name,
            categoryId: catId,
            category: catName.toUpperCase(),
            price: price,
            imageAsset: finalAsset,
            isAvailable: isAvailable,
            cartQuantity: 0,
          );
        }).toList();

        return {
          'categories': categories,
          'products': products,
        };
      }
    } catch (e) {
      debugPrint('Snapshot parsing error: $e');
    }
    return null;
  }

  /// Record a new transaction (Offline-first: saved directly to SQLite with merchant isolation, resets 2-min timer)
  Future<void> recordTransaction({
    required RecentTransactionModel transaction,
    required List<CartItemModel> items,
    String? cashierId,
    String? cashierName,
    int? merchantId,
    String? orderType,
    String? customerName,
    String? notes,
  }) async {
    final mId = merchantId ?? _activeMerchantId;

    // 1. Save locally to SQLite immediately with status 'pending' and merchant_id
    await _localDb.saveTransactionOffline(
      transaction: transaction,
      items: items,
      cashierId: cashierId,
      cashierName: cashierName,
      merchantId: mId,
      orderType: orderType,
      customerName: customerName,
      notes: notes,
      isSynced: false,
    );

    // 2. Reset the 2-minute inactivity / idle countdown timer
    resetIdleTimer();

    // 3. Update pending count for this merchant
    await refreshPendingCount(merchantId: mId);

    // 4. If online, trigger background auto-sync immediately to update PostgreSQL & stations
    if (isOnlineNotifier.value) {
      unawaited(performAutoSync(trigger: 'Auto (Transaksi Baru)', merchantId: mId));
    } else {
      syncStatusMessageNotifier.value = 'Tersimpan di SQLite (Offline). Auto-sync dalam 2 menit idle.';
    }
    debugPrint('Transaction ${transaction.id} saved in SQLite (Merchant: $mId). Pending count: ${pendingSyncCountNotifier.value}');
  }

  /// Perform synchronization (push pending transactions to PostgreSQL, and refresh catalog)
  Future<bool> performAutoSync({String trigger = 'Manual', int? merchantId}) async {
    final mId = merchantId ?? _activeMerchantId;

    if (isSyncingNotifier.value) {
      debugPrint('Sync already in progress, skipping...');
      return false;
    }

    isSyncingNotifier.value = true;
    syncStatusMessageNotifier.value = 'Sedang menyinkronkan data ($trigger)...';

    try {
      // 1. Check connectivity
      final online = await checkOnlineStatus();
      if (!online) {
        syncStatusMessageNotifier.value = 'Mode Offline (Server PostgreSQL belum terjangkau).';
        await _localDb.logSyncEvent(
          triggerType: trigger,
          status: 'offline',
          message: 'Server PostgreSQL online tidak terjangkau. Transaksi tetap tersimpan aman di SQLite.',
        );
        isSyncingNotifier.value = false;
        return false;
      }

      // 2. Fetch pending transactions from SQLite for this merchant
      final pendingTransactions = await _localDb.getPendingSyncTransactions(merchantId: mId);
      int syncedSuccessCount = 0;

      if (pendingTransactions.isNotEmpty) {
        debugPrint('Found ${pendingTransactions.length} pending transactions to sync to PostgreSQL (Merchant: $mId).');

        try {
          final res = await _api.syncBatchTransactions(pendingTransactions);
          if (res['success'] == true) {
            final syncedReceipts = pendingTransactions.map((t) => t['receipt_number'].toString()).toList();
            // Hapus data transaksi lokal di SQLite setelah berhasil di-sync ke backend
            await _localDb.deleteSyncedTransactions(syncedReceipts);
            await _localDb.deleteAllSyncedTransactions(merchantId: mId);
            syncedSuccessCount = pendingTransactions.length;
            debugPrint('Successfully synced ${pendingTransactions.length} transactions to PostgreSQL and removed local records!');
          }
        } catch (e) {
          debugPrint('PostgreSQL batch sync failed: $e');
        }
      }

      // 3. Pull latest catalog from PostgreSQL database & update SQLite for this merchant
      try {
        final onlineSnapshot = await _fetchOnlineSnapshot();
        if (onlineSnapshot != null) {
          await _localDb.saveCategories(onlineSnapshot['categories'] as List<CategoryModel>, merchantId: mId);
          await _localDb.saveProducts(onlineSnapshot['products'] as List<ProductModel>, merchantId: mId);
        }
      } catch (e) {
        debugPrint('Catalog refresh error: $e');
      }

      // 3b. Pull latest receipt settings from PostgreSQL database & update SQLite
      try {
        final onlineSettings = await _api.getReceiptSettings();
        if (onlineSettings != null) {
          await _localDb.saveReceiptSettings(ReceiptSettingsModel.fromJson(onlineSettings));
        }
      } catch (e) {
        debugPrint('Receipt settings refresh error: $e');
      }

      // 3c. Bersihkan SQLite lokal dari sisa data transaksi yang telah tersinkron
      try {
        await _localDb.deleteAllSyncedTransactions(merchantId: mId);
      } catch (e) {
        debugPrint('Clean local synced transactions error: $e');
      }

      // 4. Update sync state
      await refreshPendingCount(merchantId: mId);
      final nowFormatted = DateFormat('HH:mm:ss').format(DateTime.now());
      lastSyncTimeNotifier.value = '$nowFormatted WIB';
      syncStatusMessageNotifier.value = syncedSuccessCount > 0
          ? 'Berhasil sinkronisasi $syncedSuccessCount transaksi ke database PostgreSQL.'
          : 'Database SQLite dan PostgreSQL telah tersinkronkan ($nowFormatted WIB).';

      await _localDb.logSyncEvent(
        triggerType: trigger,
        status: 'success',
        message: 'Sinkronisasi berhasil: $syncedSuccessCount transaksi terunggah ke PostgreSQL.',
        itemsSynced: syncedSuccessCount,
      );

      isSyncingNotifier.value = false;
      return true;
    } catch (e) {
      debugPrint('Auto sync exception: $e');
      syncStatusMessageNotifier.value = 'Gagal sinkronisasi: ${e.toString()}';
      await _localDb.logSyncEvent(
        triggerType: trigger,
        status: 'error',
        message: 'Gagal sinkronisasi: $e',
      );
      isSyncingNotifier.value = false;
      return false;
    }
  }

  void dispose() {
    _countdownTimer?.cancel();
  }
}
