import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/local_database_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/posan_api_service.dart';
import '../../core/services/station_notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/station_order_model.dart';
import '../auth/login_screen.dart';
import '../attendance/attendance_screen.dart';

class _OptimisticStatusRecord {
  final String status;
  final String? processedBy;
  final int? processingAtMillis;
  final int? completedAtMillis;
  final DateTime updatedAt;

  _OptimisticStatusRecord({
    required this.status,
    this.processedBy,
    this.processingAtMillis,
    this.completedAtMillis,
    required this.updatedAt,
  });
}

class BaristaStationScreen extends StatefulWidget {
  const BaristaStationScreen({super.key});

  @override
  State<BaristaStationScreen> createState() => _BaristaStationScreenState();
}

class _BaristaStationScreenState extends State<BaristaStationScreen> {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final PosanApiService _api = PosanApiService();
  final StationNotificationService _notifService = StationNotificationService();

  List<StationOrderItemModel> _orders = [];
  final Set<int> _knownItemIds = {};
  final Map<int, _OptimisticStatusRecord> _optimisticOverrides = {};
  final Set<int> _inFlightItemIds = {};
  bool _isInitialLoadDone = false;
  bool _isLoading = false;
  String _activeFilter = 'pending'; // 'pending' (Pesanan Masuk) or 'processing' (Sedang Diproses)
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadStationOrders();
    // Auto-poll new orders every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadStationOrders(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  String get _currentStaffName {
    final user = AuthService().currentUser;
    if (user != null && user.name.trim().isNotEmpty) {
      return user.name.trim();
    }
    final session = AuthService().currentSession;
    if (session.cashierName.trim().isNotEmpty) {
      return session.cashierName.trim();
    }
    return 'Barista';
  }

  Future<void> _loadStationOrders({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      // 1. Try fetching from online PostgreSQL backend
      List<StationOrderItemModel> rawOrders = [];
      bool onlineSuccess = false;

      try {
        final onlineData = await _api.getBaristaOrders(status: 'active');
        rawOrders = onlineData.map((j) => StationOrderItemModel.fromJson(j)).toList();
        onlineSuccess = true;

        for (final o in rawOrders) {
          // Jika item sedang dalam override lokal, jangan timpa status lokal di SQLite
          if (_optimisticOverrides.containsKey(o.itemId)) {
            final override = _optimisticOverrides[o.itemId]!;
            if (override.status == o.itemStatus) {
              _optimisticOverrides.remove(o.itemId);
            } else {
              continue;
            }
          }

          await _localDb.syncStationItemStatus(
            itemId: o.itemId,
            itemStatus: o.itemStatus,
            processedBy: o.processedBy,
            processingAtMillis: o.processingAtMillis,
            completedAtMillis: o.completedAtMillis,
          );
        }
      } catch (_) {}

      // 2. Fallback to local SQLite database (for offline-first capability)
      if (!onlineSuccess) {
        final localData = await _localDb.getStationOrders('barista', statusFilter: 'active');
        rawOrders = localData.map((j) => StationOrderItemModel.fromJson(j)).toList();
      }

      // 3. Auto-sync pending overrides to backend when online is available
      if (onlineSuccess && _optimisticOverrides.isNotEmpty) {
        for (final entry in Map.of(_optimisticOverrides).entries) {
          final itemId = entry.key;
          final override = entry.value;
          _api.updateOrderItemStatus(
            itemId: itemId,
            nextStatus: override.status,
            processedBy: override.processedBy,
            updatedBy: _currentStaffName,
          ).then((_) {
            _optimisticOverrides.remove(itemId);
          }).catchError((_) {});
        }
      }

      // 4. Rekonsiliasi rawOrders dengan optimistic overrides (mencegah bug mantul)
      final now = DateTime.now();
      _optimisticOverrides.removeWhere((_, v) => now.difference(v.updatedAt).inSeconds > 60);

      final List<StationOrderItemModel> reconciledOrders = [];

      for (final raw in rawOrders) {
        if (_optimisticOverrides.containsKey(raw.itemId)) {
          final override = _optimisticOverrides[raw.itemId]!;
          if (override.status == 'completed') {
            continue; // Sudah selesai secara lokal, jangan munculkan lagi
          } else if (override.status == 'processing') {
            reconciledOrders.add(raw.copyWith(
              itemStatus: 'processing',
              processedBy: override.processedBy ?? raw.processedBy,
              processingAtMillis: override.processingAtMillis ?? raw.processingAtMillis,
            ));
          } else if (override.status == 'pending') {
            reconciledOrders.add(raw.copyWith(
              itemStatus: 'pending',
              processedBy: null,
              processingAtMillis: null,
            ));
          }
        } else {
          reconciledOrders.add(raw);
        }
      }

      // 5. Deteksi pesanan baru untuk Push Notifikasi & Audio Alert
      if (_isInitialLoadDone && mounted) {
        final newPendingOrders = reconciledOrders.where((o) => o.isPending && !_knownItemIds.contains(o.itemId)).toList();
        if (newPendingOrders.isNotEmpty) {
          final firstNew = newPendingOrders.first;
          final totalCount = newPendingOrders.length;
          final title = totalCount == 1
              ? 'Pesanan Minuman Baru! ☕'
              : '$totalCount Pesanan Minuman Baru Masuk! ☕';
          final desc = totalCount == 1
              ? '${firstNew.quantity}x ${firstNew.productName} (#${firstNew.receiptNumber})'
              : '${firstNew.quantity}x ${firstNew.productName} & ${totalCount - 1} pesanan lainnya';

          StationNotificationService.showOrderNotificationBanner(
            context: context,
            title: title,
            message: desc,
            station: 'barista',
            onTap: () {
              setState(() => _activeFilter = 'pending');
            },
          );
        }
      }

      // Update known IDs
      for (final o in reconciledOrders) {
        _knownItemIds.add(o.itemId);
      }
      _isInitialLoadDone = true;

      if (mounted) {
        setState(() {
          _orders = reconciledOrders;
          if (!silent) _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Barista orders fetch error: $e');
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<StationOrderItemModel> get _filteredOrders {
    if (_activeFilter == 'processing') {
      return _orders.where((o) => o.isProcessing).toList();
    }
    return _orders.where((o) => o.isPending).toList();
  }

  int get _pendingCount => _orders.where((o) => o.isPending).length;
  int get _processingCount => _orders.where((o) => o.isProcessing).length;

  Future<void> _handleUpdateStatus(StationOrderItemModel order, String nextStatus) async {
    final staffName = _currentStaffName;
    final nowMillis = DateTime.now().millisecondsSinceEpoch;

    // Cek locking ketat: Jika pesanan sudah diambil staf lain, staf lain tidak boleh menyelesaikan ataupun membatalkan
    if (order.isLockedByOther(staffName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔒 Pesanan ini terkunci & sedang dikerjakan oleh ${order.processedBy}. Anda tidak dapat menyelesaikan maupun membatalkannya.'),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final targetProcessedBy = nextStatus == 'processing'
        ? staffName
        : (nextStatus == 'completed' ? (order.processedBy ?? staffName) : null);
    final targetProcessingMillis = nextStatus == 'processing'
        ? (order.processingAtMillis ?? nowMillis)
        : (nextStatus == 'pending' ? null : order.processingAtMillis);
    final targetCompletedMillis = nextStatus == 'completed' ? nowMillis : null;

    // Rekam override optimistik anti-mantul
    _inFlightItemIds.add(order.itemId);
    _optimisticOverrides[order.itemId] = _OptimisticStatusRecord(
      status: nextStatus,
      processedBy: targetProcessedBy,
      processingAtMillis: targetProcessingMillis,
      completedAtMillis: targetCompletedMillis,
      updatedAt: DateTime.now(),
    );

    // 1. Optimistic local update UI
    setState(() {
      if (nextStatus == 'completed') {
        _orders.removeWhere((o) => o.itemId == order.itemId);
      } else if (nextStatus == 'processing') {
        final index = _orders.indexWhere((o) => o.itemId == order.itemId);
        if (index != -1) {
          _orders[index] = order.copyWith(
            itemStatus: 'processing',
            processedBy: targetProcessedBy,
            processingAtMillis: targetProcessingMillis,
          );
        }
      } else if (nextStatus == 'pending') {
        final index = _orders.indexWhere((o) => o.itemId == order.itemId);
        if (index != -1) {
          _orders[index] = order.copyWith(
            itemStatus: 'pending',
            processedBy: null,
            processingAtMillis: null,
          );
        }
      }
    });

    // 2. Persist in local SQLite
    try {
      await _localDb.updateStationItemStatus(
        itemId: order.itemId,
        nextStatus: nextStatus,
        updatedBy: staffName,
        processedBy: targetProcessedBy,
      );
    } catch (e) {
      debugPrint('Local SQLite status update error: $e');
    }

    // 3. Sync to PostgreSQL backend
    try {
      await _api.updateOrderItemStatus(
        itemId: order.itemId,
        nextStatus: nextStatus,
        updatedBy: staffName,
        processedBy: targetProcessedBy,
      );
      _optimisticOverrides.remove(order.itemId);
    } catch (e) {
      debugPrint('Online status update sync notice: $e (saved in SQLite & retained in override)');
    } finally {
      _inFlightItemIds.remove(order.itemId);
    }
  }

  void _handleLogout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = _currentStaffName;
    final filtered = _filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1712),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFBA6A34),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.coffee_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Stasiun Barista',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Petugas: $userName • Minuman & Kopi',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB5A99B),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Menu Absen Karyawan
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.event_available_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Absen',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBA6A34),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                minimumSize: const Size(60, 34),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AttendanceScreen(isStandalone: true),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 4),

          // Sound Toggle Button
          IconButton(
            icon: Icon(
              _notifService.isSoundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _notifService.isSoundEnabled ? const Color(0xFFFBBF24) : Colors.white60,
            ),
            tooltip: _notifService.isSoundEnabled ? 'Suara Notifikasi: Aktif' : 'Suara Notifikasi: Nonaktif',
            onPressed: () {
              setState(() {
                _notifService.toggleSound();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_notifService.isSoundEnabled
                      ? '🔔 Bunyi notifikasi pesanan diaktifkan'
                      : '🔕 Bunyi notifikasi pesanan dimatikan'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Segarkan Pesanan',
            onPressed: () => _loadStationOrders(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFE57373)),
            tooltip: 'Keluar',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // 2-Button Navigation Switch (Pesanan Masuk & Sedang Diproses)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _buildNavTab(
                    id: 'pending',
                    label: 'Pesanan Masuk',
                    count: _pendingCount,
                    icon: Icons.hourglass_top_rounded,
                    activeColor: const Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildNavTab(
                    id: 'processing',
                    label: 'Sedang Diproses',
                    count: _processingCount,
                    icon: Icons.autorenew_rounded,
                    activeColor: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),

          // Sub-header stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFEFEBE4),
              border: Border(bottom: BorderSide(color: Color(0xFFE0D8CC))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _activeFilter == 'pending'
                        ? 'Menampilkan $_pendingCount pesanan masuk baru'
                        : 'Menampilkan $_processingCount pesanan dalam pembuatan',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Auto-sync & Notif',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Orders Grid / List
          Expanded(
            child: _isLoading && _orders.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFBA6A34)))
                : filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _loadStationOrders(),
                        color: const Color(0xFFBA6A34),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isTablet = constraints.maxWidth >= 700;
                            if (isTablet) {
                              return GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 440,
                                  mainAxisExtent: 290,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  return _buildOrderCard(filtered[index], userName);
                                },
                              );
                            } else {
                              return ListView.separated(
                                padding: const EdgeInsets.all(14),
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return _buildOrderCard(filtered[index], userName);
                                },
                              );
                            }
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab({
    required String id,
    required String label,
    required int count,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _activeFilter == id;
    return Material(
      color: isSelected ? const Color(0xFF1E1712) : const Color(0xFFF3EEE7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _activeFilter = id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF1E1712) : const Color(0xFFE4DCCE),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : activeColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : const Color(0xFFE2D9CC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(StationOrderItemModel order, String currentUserName) {
    final isProcessing = order.isProcessing;
    final isLockedByOther = order.isLockedByOther(currentUserName);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLockedByOther
              ? const Color(0xFFF59E0B)
              : isProcessing
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFFE2D9CC),
          width: isProcessing ? 1.8 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isLockedByOther
                ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                : isProcessing
                    ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Struk No, Status Pill
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EBE2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.receiptNumber.startsWith('#') ? order.receiptNumber : '#${order.receiptNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isProcessing) ...[
                if (isLockedByOther)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, size: 12, color: Color(0xFFB45309)),
                        const SizedBox(width: 4),
                        Text(
                          'TERKUNCI (${order.processedBy})',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.autorenew_rounded, size: 12, color: Color(0xFF1D4ED8)),
                        SizedBox(width: 4),
                        Text(
                          'SEDANG ANDA PROSES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: Color(0xFFB45309)),
                      SizedBox(width: 4),
                      Text(
                        'MASUK ANTRIAN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Menu Item & Quantity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFBA6A34).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${order.quantity}x',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFBA6A34),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.productName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (order.customerName != null && order.customerName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Pemesan: ${order.customerName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (order.itemNotes != null && order.itemNotes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          'Catatan: ${order.itemNotes}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Processed By Notice Bar (if in processing)
          if (isProcessing && order.processedBy != null && order.processedBy!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLockedByOther ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isLockedByOther ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isLockedByOther ? Icons.lock_outline_rounded : Icons.person_pin_rounded,
                    size: 13,
                    color: isLockedByOther ? const Color(0xFFB45309) : const Color(0xFF15803D),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      isLockedByOther
                          ? 'Sedang diproses oleh: ${order.processedBy}'
                          : 'Sedang Anda proses (${order.processedBy})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isLockedByOther ? const Color(0xFFB45309) : const Color(0xFF15803D),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFECE4D9)),
          const SizedBox(height: 8),

          // Footer: Waktu masuk & Tombol Aksi
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    order.elapsedMinutesFormatted,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Spacer(),

              // Action buttons
              if (order.isPending)
                ElevatedButton.icon(
                  onPressed: () => _handleUpdateStatus(order, 'processing'),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Proses Pesanan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else if (order.isProcessing) ...[
                if (isLockedByOther)
                  ElevatedButton.icon(
                    onPressed: null, // Disabled for other staff
                    icon: const Icon(Icons.lock_rounded, size: 14),
                    label: Text('Terkunci (${order.processedBy})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5E7EB),
                      foregroundColor: const Color(0xFF9CA3AF),
                      disabledBackgroundColor: const Color(0xFFF3F4F6),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  )
                else ...[
                  // Kembalikan ke antrean (Release) button
                  IconButton(
                    icon: const Icon(Icons.undo_rounded, size: 16, color: Color(0xFFB45309)),
                    tooltip: 'Lepas / Kembalikan ke Antrean',
                    onPressed: () => _handleUpdateStatus(order, 'pending'),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: () => _handleUpdateStatus(order, 'completed'),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Selesai Dibuat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isPendingTab = _activeFilter == 'pending';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFEBE5DB),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPendingTab ? Icons.check_circle_outline_rounded : Icons.coffee_maker_rounded,
                size: 48,
                color: const Color(0xFF8C7A6B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPendingTab ? 'Tidak Ada Pesanan Masuk Baru' : 'Tidak Ada Pesanan Sedang Dibuat',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isPendingTab
                  ? 'Semua racikan minuman sudah diproses atau diselesaikan.'
                  : 'Buka tab "Pesanan Masuk" lalu klik Proses Pesanan untuk mulai membuat minuman.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
