import 'package:flutter/material.dart';
import '../../core/services/sales_report_export_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/cashier_session_model.dart';
import '../../models/recent_transaction_model.dart';
import 'widgets/history_filter_chips.dart';
import 'widgets/history_filter_modal.dart';
import 'widgets/history_header.dart';
import 'widgets/history_summary_card.dart';
import 'widgets/transaction_card.dart';
import 'widgets/transaction_detail_modal.dart';
import 'widgets/thermal_receipt_modal.dart';

class CashierHistoryView extends StatefulWidget {
  final CashierSessionModel session;
  final List<RecentTransactionModel> transactions;
  final VoidCallback onSyncTap;
  final VoidCallback onProfileTap;

  const CashierHistoryView({
    super.key,
    required this.session,
    required this.transactions,
    required this.onSyncTap,
    required this.onProfileTap,
  });

  @override
  State<CashierHistoryView> createState() => _CashierHistoryViewState();
}

class _CashierHistoryViewState extends State<CashierHistoryView> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedQuickChip = 'all';
  HistoryFilterState _modalFilter = const HistoryFilterState();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RecentTransactionModel> get _filteredTransactions {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final yesterdayEnd = DateTime(
      yesterdayStart.year,
      yesterdayStart.month,
      yesterdayStart.day,
      23,
      59,
      59,
      999,
    );
    final sevenDaysAgoStart = todayStart.subtract(const Duration(days: 6));

    return widget.transactions.where((tx) {
      // 1. Payment Method Filter
      final matchesPaymentMethod = switch (_modalFilter.paymentMethod) {
        'cash' => tx.paymentMethod == TransactionPaymentMethod.cash,
        'qris' => tx.paymentMethod == TransactionPaymentMethod.qris,
        'bank' => tx.paymentMethod == TransactionPaymentMethod.bank,
        _ => true,
      };

      // 2. Sync Status Filter
      final matchesSyncStatus = switch (_modalFilter.syncStatus) {
        'pending' => tx.syncStatus == SyncStatus.pending,
        'synced' => tx.syncStatus == SyncStatus.synced,
        _ => true,
      };

      // 3. Time Range Filter
      final txDate = tx.createdAt ?? DateTime.now();
      final matchesTimeRange = switch (_modalFilter.timeRange) {
        'today' =>
          txDate.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
              txDate.isBefore(todayEnd.add(const Duration(seconds: 1))),
        'yesterday' =>
          txDate.isAfter(yesterdayStart.subtract(const Duration(seconds: 1))) &&
              txDate.isBefore(yesterdayEnd.add(const Duration(seconds: 1))),
        'this_week' =>
          txDate.isAfter(sevenDaysAgoStart.subtract(const Duration(seconds: 1))) &&
              txDate.isBefore(todayEnd.add(const Duration(seconds: 1))),
        'all' => true,
        _ => true,
      };

      // 4. Order Type Filter
      final orderTypeLower = (tx.orderType ?? '').toLowerCase();
      final matchesOrderType = switch (_modalFilter.orderType) {
        'dine_in' => orderTypeLower.contains('dine') || orderTypeLower.contains('makan'),
        'takeaway' => orderTypeLower.contains('take') || orderTypeLower.contains('bawa') || orderTypeLower.contains('bungkus'),
        _ => true,
      };

      // 5. Search Query
      final matchesQuery = query.isEmpty ||
          tx.id.toLowerCase().contains(query) ||
          tx.itemSummary.toLowerCase().contains(query) ||
          tx.paymentMethod.label.toLowerCase().contains(query) ||
          (tx.cashierName?.toLowerCase().contains(query) ?? false) ||
          (tx.customerName?.toLowerCase().contains(query) ?? false) ||
          (tx.orderType?.toLowerCase().contains(query) ?? false) ||
          tx.totalAmount.toInt().toString().contains(query);

      return matchesPaymentMethod &&
          matchesSyncStatus &&
          matchesTimeRange &&
          matchesOrderType &&
          matchesQuery;
    }).toList();
  }

  int get _pendingCount {
    return widget.transactions
        .where((t) => t.syncStatus == SyncStatus.pending)
        .length;
  }

  double get _totalSales {
    return widget.transactions.fold<double>(
      0,
      (sum, t) => sum + t.totalAmount,
    );
  }

  bool get _hasActiveFilters =>
      !_modalFilter.isDefault || _searchController.text.isNotEmpty;

  void _onQuickChipSelected(String id) {
    setState(() {
      _selectedQuickChip = id;
      if (id == 'all') {
        _modalFilter = _modalFilter.copyWith(
          paymentMethod: 'all',
          syncStatus: 'all',
        );
      } else if (id == 'cash' || id == 'qris' || id == 'bank') {
        _modalFilter = _modalFilter.copyWith(
          paymentMethod: id,
          syncStatus: 'all',
        );
      } else if (id == 'pending' || id == 'synced') {
        _modalFilter = _modalFilter.copyWith(
          syncStatus: id,
          paymentMethod: 'all',
        );
      }
    });
  }

  void _resetAllFilters() {
    setState(() {
      _selectedQuickChip = 'all';
      _modalFilter = const HistoryFilterState();
      _searchController.clear();
    });
  }

  void _openFilterModal() async {
    final result = await HistoryFilterModal.show(
      context,
      currentFilter: _modalFilter,
    );
    if (result != null && mounted) {
      setState(() {
        _modalFilter = result;
        // Harmonize quick chip with modal filter
        if (result.paymentMethod != 'all' && result.syncStatus == 'all') {
          _selectedQuickChip = result.paymentMethod;
        } else if (result.syncStatus != 'all' && result.paymentMethod == 'all') {
          _selectedQuickChip = result.syncStatus;
        } else if (result.paymentMethod == 'all' && result.syncStatus == 'all') {
          _selectedQuickChip = 'all';
        } else {
          _selectedQuickChip = '';
        }
      });
    }
  }

  void _showDetailModal(RecentTransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailModal(
        transaction: transaction,
        onReprint: () {
          ThermalReceiptModal.show(
            context,
            transaction: transaction,
            onPrint: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Struk ${transaction.id} berhasil dikirim ke printer bluetooth.',
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
          );
        },
      ),
    );
  }

  void _openExportReportModal() {
    SalesReportExportService.showExportReportModal(
      context,
      session: widget.session,
      transactions: widget.transactions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;

    return RefreshIndicator(
      onRefresh: () async {
        widget.onSyncTap();
      },
      color: AppColors.primaryDark,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header (Brand Logo, Riwayat Transaksi, Online Pill, Profile Avatar)
            HistoryHeader(
              session: widget.session,
              onProfileTap: widget.onProfileTap,
              onSyncTap: widget.onSyncTap,
            ),
            const SizedBox(height: 14),

            // 2. Summary Card (Omset, Transaksi, Offline Sync)
            HistorySummaryCard(
              totalSales: _totalSales,
              totalCount: widget.transactions.length,
              pendingCount: _pendingCount,
              onSyncTap: widget.onSyncTap,
            ),
            const SizedBox(height: 14),

            // 3. Search Bar + Filter Button
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFECE4D9),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Cari nomor struk (#SEN-...), menu, kasir...',
                        hintStyle: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                color: AppColors.textMuted,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Filter Modal Button
                InkWell(
                  onTap: _openFilterModal,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _modalFilter.isDefault
                          ? const Color(0xFFF3EEE7)
                          : const Color(0xFF30221A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _modalFilter.isDefault
                            ? const Color(0xFFECE4D9)
                            : const Color(0xFF30221A),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: _modalFilter.isDefault
                              ? AppColors.textPrimary
                              : Colors.white,
                        ),
                        if (!_modalFilter.isDefault)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFBA6A34),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4. Quick Filter Chips
            HistoryFilterChips(
              selectedFilter: _selectedQuickChip,
              totalCount: widget.transactions.length,
              pendingCount: _pendingCount,
              onFilterSelected: _onQuickChipSelected,
            ),
            const SizedBox(height: 16),

            // 5. Section Header with count, export, and reset action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daftar Transaksi (${filtered.length})',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasActiveFilters) ...[
                      InkWell(
                        onTap: _resetAllFilters,
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(
                            'Reset Filter',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFBA6A34),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    InkWell(
                      onTap: _openExportReportModal,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFC8E6C9),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.table_view_rounded,
                              size: 13,
                              color: Color(0xFF2E7D32),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Unduh XLSX',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 6. Transactions List
            if (filtered.isEmpty)
              _buildEmptyState()
            else if (MediaQuery.sizeOf(context).width >= 720)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 520,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 92,
                ),
                itemBuilder: (context, index) {
                  final tx = filtered[index];
                  return TransactionCard(
                    transaction: tx,
                    onTap: () => _showDetailModal(tx),
                  );
                },
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final tx = filtered[index];
                  return TransactionCard(
                    transaction: tx,
                    onTap: () => _showDetailModal(tx),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECE4D9), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF3EEE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tidak ada transaksi ditemukan',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Coba ubah kata kunci pencarian atau filter yang dipilih.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _resetAllFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
              ),
              child: const Text(
                'Reset Semua Filter',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
