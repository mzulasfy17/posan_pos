import 'package:flutter/material.dart';
import '../../core/database/local_database_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/offline_sync_manager.dart';
import '../../core/services/posan_api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive_layout.dart';
import '../../models/cashier_session_model.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/recent_transaction_model.dart';
import '../../models/cart_order_model.dart';
import '../auth/login_screen.dart';
import '../cashier_dashboard/cashier_dashboard_view.dart';
import '../cashier_cart/cashier_cart_screen.dart';
import '../cashier_history/cashier_history_view.dart';
import '../cashier_history/widgets/transaction_detail_modal.dart';
import '../cashier_others/cashier_others_view.dart';
import '../attendance/attendance_screen.dart';
import 'cashier_catalog_view.dart';
import 'widgets/cashier_cart_panel.dart';
import 'widgets/floating_cart_bar.dart';
import 'widgets/order_type_picker_modal.dart';
import 'widgets/posan_bottom_nav.dart';

class CashierHomeScreen extends StatefulWidget {
  const CashierHomeScreen({super.key});

  @override
  State<CashierHomeScreen> createState() => _CashierHomeScreenState();
}

class _CashierHomeScreenState extends State<CashierHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final OfflineSyncManager _syncManager = OfflineSyncManager();
  final LocalDatabaseService _localDb = LocalDatabaseService();

  late CashierSessionModel _session;
  late List<CategoryModel> _categories;
  late List<ProductModel> _products;
  late List<RecentTransactionModel> _recentTransactions;
  String _selectedCategoryId = 'all';
  String _currentOrderType = 'Dine In';
  int _currentNavIndex = 0; // 0: Beranda, 1: Pesanan, 2: Riwayat, 3: Absen, 4: Lainnya
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _session = AuthService().currentSession;
    _categories = const [
      CategoryModel(
        id: 'all',
        name: 'Semua',
        icon: Icons.grid_view_rounded,
      ),
    ];
    _products = [];
    _recentTransactions = [];

    _syncManager.pendingSyncCountNotifier.addListener(_onSyncStateChanged);
    _syncManager.isOnlineNotifier.addListener(_onSyncStateChanged);

    _loadData();
  }

  void _onSyncStateChanged() {
    if (mounted) {
      setState(() {
        _session = _session.copyWith(
          pendingSyncCount: _syncManager.pendingCount,
          isOnline: _syncManager.isOnline,
        );
      });
    }
  }

  Future<void> _loadData() async {
    final userSession = await AuthService().loadCurrentSession();
    final mId = userSession.merchantId ?? AuthService().currentUser?.merchantId;

    // 1. Load catalog from SQLite (instant offline) + online sync for this specific cafe
    final catalog = await _syncManager.loadCatalog(merchantId: mId);
    final List<CategoryModel> categories = catalog['categories'] as List<CategoryModel>;
    final List<ProductModel> products = catalog['products'] as List<ProductModel>;

    // 2. Load recent transactions (online PostgreSQL when connected + local pending offline)
    List<RecentTransactionModel> transactions = [];
    if (_syncManager.isOnline) {
      try {
        final onlineData = await PosanApiService().fetchRecentTransactions(limit: 50);
        transactions = onlineData.map((d) => RecentTransactionModel.fromJson(d)).toList();
      } catch (e) {
        debugPrint('Error fetching online transactions: $e');
      }
    }
    
    // Merge pending local transactions at the top
    final localPending = await _localDb.getRecentTransactions(merchantId: mId);
    if (localPending.isNotEmpty) {
      final existingIds = transactions.map((t) => t.id.replaceAll('#', '')).toSet();
      final pendingOnly = localPending.where((t) => !existingIds.contains(t.id.replaceAll('#', ''))).toList();
      transactions = [...pendingOnly, ...transactions];
    }

    // 3. Load today's metrics & starting cash
    double totalSales = 0.0;
    int totalCount = 0;
    final int pendingCount = await _localDb.getPendingSyncCount(merchantId: mId);
    final double startingCash = await _localDb.getStartingCash(merchantId: mId);

    if (_syncManager.isOnline) {
      try {
        final stats = await PosanApiService().fetchTransactionStats();
        if (stats != null && stats['summary'] != null) {
          totalSales = (stats['summary']['today_revenue'] as num?)?.toDouble() ?? 0.0;
          totalCount = (stats['summary']['today_transactions'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}
    }

    if (totalSales == 0.0 && totalCount == 0) {
      final metrics = await _localDb.getTodayMetrics(merchantId: mId);
      totalSales = (metrics['todaySales'] as num?)?.toDouble() ?? 0.0;
      totalCount = (metrics['todayCount'] as num?)?.toInt() ?? 0;
    }

    if (mounted) {
      final populatedCategories = categories.map((cat) {
        if (cat.id == 'all') {
          return CategoryModel(
            id: cat.id,
            name: cat.name,
            icon: cat.icon,
            itemCount: products.length,
          );
        }
        final count = products.where((p) {
          if (p.categoryId.isNotEmpty && p.categoryId == cat.id) return true;
          final catName = cat.name.trim().toLowerCase();
          final prodCat = p.category.trim().toLowerCase();
          if (prodCat == catName) return true;
          if (catName.contains('makan') &&
              (prodCat == 'food' || prodCat == 'makanan')) {
            return true;
          }
          if (catName.contains('coff') &&
              !catName.contains('non') &&
              (prodCat == 'coffee' || prodCat == 'coffe' || prodCat == 'kopi')) {
            return true;
          }
          if (catName.contains('non') &&
              (prodCat == 'non-coffee' ||
                  prodCat == 'non coffe' ||
                  prodCat == 'minuman' ||
                  prodCat == 'tea' ||
                  prodCat == 'teh')) {
            return true;
          }
          if ((catName.contains('snack') || catName.contains('pastry')) &&
              (prodCat == 'pastry' || prodCat == 'snack')) {
            return true;
          }
          return false;
        }).length;
        return CategoryModel(
          id: cat.id,
          name: cat.name,
          icon: cat.icon,
          itemCount: count,
        );
      }).toList();

      setState(() {
        _session = userSession.copyWith(
          merchantName: userSession.merchantName.isNotEmpty ? userSession.merchantName : _session.merchantName,
          outletLocation: userSession.outletLocation.isNotEmpty ? userSession.outletLocation : _session.outletLocation,
          todaySalesAmount: totalSales,
          todayTransactionCount: totalCount,
          localStorageCount: transactions.length,
          pendingSyncCount: pendingCount,
          isOnline: _syncManager.isOnline,
          initialCash: startingCash,
        );
        _categories = populatedCategories;
        if (products.isNotEmpty) {
          _products = products;
        }
        _recentTransactions = transactions;
      });
    }
  }

  @override
  void dispose() {
    _syncManager.pendingSyncCountNotifier.removeListener(_onSyncStateChanged);
    _syncManager.isOnlineNotifier.removeListener(_onSyncStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<ProductModel> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();

    // Look up selected category model if any
    final selectedCat = _categories.cast<CategoryModel?>().firstWhere(
      (c) => c?.id == _selectedCategoryId,
      orElse: () => null,
    );
    final selectedCatName = selectedCat?.name.trim().toLowerCase() ?? '';

    return _products.where((item) {
      bool matchesCategory = false;
      if (_selectedCategoryId == 'all') {
        matchesCategory = true;
      } else if (item.categoryId.isNotEmpty &&
          item.categoryId == _selectedCategoryId) {
        matchesCategory = true;
      } else {
        final prodCat = item.category.trim().toLowerCase();
        final selectedId = _selectedCategoryId.toLowerCase();

        if (prodCat == selectedId ||
            (selectedCatName.isNotEmpty && prodCat == selectedCatName)) {
          matchesCategory = true;
        } else if ((selectedId == 'food' ||
                selectedCatName.contains('makan')) &&
            (prodCat == 'food' || prodCat == 'makanan')) {
          matchesCategory = true;
        } else if ((selectedId == 'coffee' ||
                (selectedCatName.contains('coff') &&
                    !selectedCatName.contains('non'))) &&
            (prodCat == 'coffee' || prodCat == 'coffe' || prodCat == 'kopi')) {
          matchesCategory = true;
        } else if ((selectedId == 'non_coffee' ||
                selectedCatName.contains('non')) &&
            (prodCat == 'non-coffee' ||
                prodCat == 'non coffe' ||
                prodCat == 'minuman' ||
                prodCat == 'tea' ||
                prodCat == 'teh')) {
          matchesCategory = true;
        } else if ((selectedId == 'pastry' ||
                selectedCatName.contains('snack') ||
                selectedCatName.contains('pastry')) &&
            (prodCat == 'pastry' || prodCat == 'snack')) {
          matchesCategory = true;
        }
      }

      final matchesQuery = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);

      return matchesCategory && matchesQuery;
    }).toList();
  }

  int get _totalCartItems {
    return _products.fold<int>(0, (sum, item) => sum + item.cartQuantity);
  }

  double get _totalCartPrice {
    return _products.fold<double>(
      0,
      (sum, item) => sum + (item.cartQuantity * item.price),
    );
  }

  void _incrementQuantity(ProductModel product) {
    if (!product.isAvailable) return;
    setState(() {
      product.cartQuantity += 1;
    });
  }

  void _decrementQuantity(ProductModel product) {
    if (product.cartQuantity <= 0) return;
    setState(() {
      product.cartQuantity -= 1;
    });
  }

  void _handleIncrementCartItem(CartItemModel item) {
    _incrementQuantity(item.product);
  }

  void _handleDecrementCartItem(CartItemModel item) {
    _decrementQuantity(item.product);
  }

  void _handleDeleteCartItem(CartItemModel item) {
    setState(() {
      item.product.cartQuantity = 0;
    });
  }

  void _handleClearAllCart() {
    setState(() {
      for (final p in _products) {
        p.cartQuantity = 0;
      }
    });
  }

  void _handleSelectOrderType() async {
    final isDineIn = _currentOrderType.toLowerCase().contains('dine in');
    final result = await OrderTypePickerModal.show(
      context,
      initialType: isDineIn ? OrderType.dineIn : OrderType.takeaway,
      initialDetail: _currentOrderType,
    );
    if (result != null && mounted) {
      setState(() {
        _currentOrderType = result.label;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tipe pesanan diubah: ${result.label}'),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    }
  }

  void _handleSync() async {
    if (_session.isAutoSyncing) return;

    setState(() {
      _session = _session.copyWith(isAutoSyncing: true);
    });

    final success = await _syncManager.performAutoSync(
      trigger: 'Manual Kasir',
      merchantId: _session.merchantId,
    );
    await _loadData();

    if (!mounted) return;

    setState(() {
      _session = _session.copyWith(
        isAutoSyncing: false,
        isOnline: _syncManager.isOnline,
        pendingSyncCount: _syncManager.pendingCount,
        lastSyncTime: _syncManager.lastSyncTimeNotifier.value,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                success
                    ? 'Sinkronisasi offline ke server berhasil diselesaikan.'
                    : 'Mode Offline Aktif. Transaksi tersimpan di penyimpanan lokal dan otomatis disinkronkan saat online.',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleNavTap(int index) {
    setState(() {
      _currentNavIndex = index;
    });
  }

  void _handleUpdateMenu() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text('Mengunduh katalog menu dan harga terbaru dari server...'),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 1200),
      ),
    );

    await _syncManager.performAutoSync(
      trigger: 'Unduh Katalog',
      merchantId: _session.merchantId,
    );
    await _loadData();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('Katalog menu dan harga berhasil diperbarui & disimpan di penyimpanan lokal.'),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleStartingCashChanged(double amount) async {
    await _localDb.updateStartingCash(
      amount,
      merchantId: _session.merchantId,
      cashierName: _session.cashierName,
    );
    setState(() {
      _session = _session.copyWith(initialCash: amount);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Modal awal kasir berhasil diperbarui: ${CurrencyFormatter.format(amount)}',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleShiftClosed() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Shift Berhasil Ditutup',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Laporan rekonsiliasi kas telah tersimpan di sistem penyimpanan lokal.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5EE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFECE4D9)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kasir:', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      Text(_session.cashierName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Transaksi:', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      Text('${_recentTransactions.length} transaksi', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Omset:', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      Text(
                        CurrencyFormatter.format(_recentTransactions.fold<double>(0, (s, t) => s + t.totalAmount)),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFBA6A34)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _localDb.openNewShift(
                merchantId: _session.merchantId,
                cashierName: _session.cashierName,
                startingCash: _session.initialCash,
              );
              await _loadData();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Shift baru berhasil dibuka. Selamat bertugas!'),
                  backgroundColor: AppColors.primaryDark,
                ),
              );
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Buka Shift Baru', style: TextStyle(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.primaryDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _handleLogout();
            },
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Selesai & Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogout() async {
    await AuthService().signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Sesi kasir berhasil ditutup.',
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 1500),
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  void _showTransactionDetail(RecentTransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailModal(
        transaction: transaction,
        onReprint: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Struk ${transaction.id} berhasil dikirim ke antrean cetak printer thermal.',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primaryDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _showCashierProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Kasir Aktif: ${_session.cashierName} (${_session.shift} - ${_session.shiftNumber})',
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<CartItemModel> _getCartItems() {
    final cartList = <CartItemModel>[];
    for (final p in _products) {
      if (p.cartQuantity > 0) {
        String? note;
        String unit = 'porsi';
        if (p.id == 'p1') {
          note = 'Less ice, gula aren 50%';
        } else if (p.id == 'p2') {
          note = 'Dihangatkan';
          unit = 'pcs';
        }
        cartList.add(CartItemModel(
          product: p,
          quantity: p.cartQuantity,
          note: note,
          unitLabel: unit,
        ));
      }
    }
    return cartList;
  }

  void _handlePaymentCompleted(RecentTransactionModel newTransaction, [List<CartItemModel>? items]) async {
    final paidItems = items != null && items.isNotEmpty ? items : _getCartItems();

    // 1. Reset all product cart quantities in UI
    setState(() {
      for (final p in _products) {
        p.cartQuantity = 0;
      }
      _currentNavIndex = 0; // Switch to Beranda Dashboard
    });

    // 2. Save directly to local SQLite Database (Offline First) and reset 2-minute idle timer
    await _syncManager.recordTransaction(
      transaction: newTransaction,
      items: paidItems,
      cashierId: AuthService().currentUser?.id,
      cashierName: _session.cashierName,
      merchantId: _session.merchantId,
      orderType: _currentOrderType,
      customerName: 'Pelanggan POSAN',
      notes: _currentOrderType,
    );

    // 3. Reload recent transactions and metrics from SQLite
    await _loadData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.offline_pin_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Transaksi ${newTransaction.id} tersimpan di penyimpanan lokal. Auto-sync dalam 2 menit idle.',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleViewCart() async {
    final items = _getCartItems();
    final newTransaction = await Navigator.push<RecentTransactionModel>(
      context,
      MaterialPageRoute(
        builder: (context) => CashierCartScreen(
          initialItems: items,
          initialOrderInfo: OrderInfoModel(
            orderType: _currentOrderType,
            station: 'Kasir Utama',
          ),
          onCartUpdated: (updatedList) {
            setState(() {
              // Sync updated quantities back to product catalog
              for (final prod in _products) {
                final match = updatedList.cast<CartItemModel?>().firstWhere(
                      (it) => it?.product.id == prod.id,
                      orElse: () => null,
                    );
                prod.cartQuantity = match?.quantity ?? 0;
              }
            });
          },
        ),
      ),
    );

    if (newTransaction != null && mounted) {
      _handlePaymentCompleted(newTransaction, items);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isWide(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentNavIndex,
          children: [
            // Tab 0: Beranda (Home Dashboard Kasir)
            MaxContentWidth(
              maxWidth: 1100,
              child: CashierDashboardView(
                session: _session,
                transactions: _recentTransactions,
                onCreateOrderTap: () {
                  setState(() {
                    _currentNavIndex = 1; // Switch to Pesanan (Catalog)
                  });
                },
                onOrderHistoryTap: () {
                  _handleNavTap(2);
                },
                onSyncTap: _handleSync,
                onProfileTap: _showCashierProfile,
                onTransactionTap: _showTransactionDetail,
              ),
            ),

            // Tab 1: Pesanan (Katalog Menu Kasir • Split Screen on Tablet/Landscape)
            isWide
                ? Row(
                    children: [
                      // Sisi Kiri: Katalog & Kategori
                      Expanded(
                        child: CashierCatalogView(
                          session: _session,
                          searchController: _searchController,
                          categories: _categories,
                          selectedCategoryId: _selectedCategoryId,
                          filteredProducts: _filteredProducts,
                          onCategorySelected: (id) {
                            setState(() {
                              _selectedCategoryId = id;
                            });
                          },
                          onIncrementProduct: _incrementQuantity,
                          onDecrementProduct: _decrementQuantity,
                          onSyncTap: _handleSync,
                          onProfileTap: _showCashierProfile,
                          onSearchChanged: () {
                            setState(() {});
                          },
                          isSplitPane: true,
                          isGridView: _isGridView,
                          onToggleViewMode: () {
                            setState(() {
                              _isGridView = !_isGridView;
                            });
                          },
                        ),
                      ),

                      // Sisi Kanan: Panel Keranjang & Checkout Aktif Langsung
                      SizedBox(
                        width: (MediaQuery.sizeOf(context).width * 0.36)
                            .clamp(330.0, 420.0),
                        child: CashierCartPanel(
                          items: _getCartItems(),
                          orderType: _currentOrderType,
                          onSelectOrderType: _handleSelectOrderType,
                          onIncrementItem: _handleIncrementCartItem,
                          onDecrementItem: _handleDecrementCartItem,
                          onDeleteItem: _handleDeleteCartItem,
                          onClearCart: _handleClearAllCart,
                          onPaymentSuccess: _handlePaymentCompleted,
                        ),
                      ),
                    ],
                  )
                : CashierCatalogView(
                    session: _session,
                    searchController: _searchController,
                    categories: _categories,
                    selectedCategoryId: _selectedCategoryId,
                    filteredProducts: _filteredProducts,
                    onCategorySelected: (id) {
                      setState(() {
                        _selectedCategoryId = id;
                      });
                    },
                    onIncrementProduct: _incrementQuantity,
                    onDecrementProduct: _decrementQuantity,
                    onSyncTap: _handleSync,
                    onProfileTap: _showCashierProfile,
                    onSearchChanged: () {
                      setState(() {});
                    },
                    isGridView: _isGridView,
                    onToggleViewMode: () {
                      setState(() {
                        _isGridView = !_isGridView;
                      });
                    },
                  ),

            // Tab 2: Riwayat Transaksi
            MaxContentWidth(
              maxWidth: 1100,
              child: CashierHistoryView(
                session: _session,
                transactions: _recentTransactions,
                onSyncTap: _handleSync,
                onProfileTap: _showCashierProfile,
              ),
            ),

            // Tab 3: Absen (Kehadiran Karyawan)
            const AttendanceScreen(
              isStandalone: false,
            ),

            // Tab 4: Pengaturan & Lainnya
            MaxContentWidth(
              maxWidth: 880,
              child: CashierOthersView(
                session: _session,
                transactions: _recentTransactions,
                onSyncTap: _handleSync,
                onUpdateMenuTap: _handleUpdateMenu,
                onStartingCashChanged: _handleStartingCashChanged,
                onShiftClosed: _handleShiftClosed,
                onLogout: _handleLogout,
              ),
            ),
          ],
        ),
      ),

      // Floating Cart Summary Bar (shows on Catalog tab when items are present and on mobile portrait)
      bottomSheet: _totalCartItems > 0 && _currentNavIndex == 1 && !isWide
          ? Container(
              color: Colors.transparent,
              child: FloatingCartBar(
                totalItemCount: _totalCartItems,
                totalPrice: _totalCartPrice,
                orderType: _currentOrderType,
                onTap: _handleViewCart,
                onOrderTypeTap: _handleSelectOrderType,
              ),
            )
          : null,

      // Bottom Navigation Bar
      bottomNavigationBar: PosanBottomNav(
        currentIndex: _currentNavIndex,
        onTap: _handleNavTap,
      ),
    );
  }
}
