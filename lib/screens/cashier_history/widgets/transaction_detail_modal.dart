import 'package:flutter/material.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/posan_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/order_log_model.dart';
import '../../../models/recent_transaction_model.dart';

class TransactionDetailModal extends StatefulWidget {
  final RecentTransactionModel transaction;
  final VoidCallback onReprint;

  const TransactionDetailModal({
    super.key,
    required this.transaction,
    required this.onReprint,
  });

  @override
  State<TransactionDetailModal> createState() => _TransactionDetailModalState();
}

class _TransactionDetailModalState extends State<TransactionDetailModal> {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final PosanApiService _api = PosanApiService();

  List<Map<String, dynamic>> _items = [];
  List<OrderLogModel> _orderLogs = [];
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final receiptNo = widget.transaction.id.replaceAll('#', '').trim();
    try {
      // 1. Ambil item transaksi dari SQLite
      final items = await _localDb.getTransactionItems(receiptNo);

      // 2. Ambil log pengantaran/proses dari SQLite
      final localRows = await _localDb.getOrderLogs(receiptNo);
      List<OrderLogModel> logs = localRows.map((r) => OrderLogModel.fromJson(r)).toList();

      // 3. Ambil online logs jika online
      try {
        final onlineRows = await _api.getOrderLogs(receiptNo);
        if (onlineRows.isNotEmpty) {
          logs = onlineRows.map((r) => OrderLogModel.fromJson(r)).toList();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _items = items;
          _orderLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching transaction detail: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Kasir mengubah status 1 item tertentu
  Future<void> _handleUpdateSingleItemStatus(int itemId, String nextStatus) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    final staffName = AuthService().currentUser?.name ?? 'Kasir POSAN';

    try {
      // 1. Update SQLite
      await _localDb.updateStationItemStatus(
        itemId: itemId,
        nextStatus: nextStatus,
        updatedBy: staffName,
        processedBy: nextStatus == 'processing' ? staffName : null,
      );

      // 2. Update API
      try {
        await _api.updateOrderItemStatus(
          itemId: itemId,
          nextStatus: nextStatus,
          updatedBy: staffName,
          processedBy: nextStatus == 'processing' ? staffName : null,
        );
      } catch (e) {
        debugPrint('Online update notice: $e (saved in SQLite)');
      }

      if (!mounted) return;

      final label = nextStatus == 'completed'
          ? 'Selesai Dibuat ✅'
          : nextStatus == 'processing'
              ? 'Sedang Diproses ☕/🍳'
              : 'Masuk Antrean ⏳';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status item berhasil diubah menjadi: $label'),
          backgroundColor: nextStatus == 'completed'
              ? const Color(0xFF15803D)
              : nextStatus == 'processing'
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );

      // Reload
      await _loadData();
    } catch (e) {
      debugPrint('Error updating item status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status item: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  /// Kasir menandai seluruh item dalam transaksi sebagai selesai atau status lain
  Future<void> _handleUpdateAllItemsStatus(String nextStatus) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    final staffName = AuthService().currentUser?.name ?? 'Kasir POSAN';
    final receiptNo = widget.transaction.id.replaceAll('#', '').trim();

    try {
      // 1. Update SQLite
      await _localDb.updateTransactionAllItemsStatus(
        receiptNumber: receiptNo,
        nextStatus: nextStatus,
        updatedBy: staffName,
      );

      // 2. Update API
      try {
        await _api.updateTransactionItemsStatus(
          receiptOrId: receiptNo,
          nextStatus: nextStatus,
          updatedBy: staffName,
        );
      } catch (e) {
        debugPrint('Online bulk update notice: $e');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Semua item pesanan struk #$receiptNo ditandai $nextStatus! ✨'),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
        ),
      );

      await _loadData();
    } catch (e) {
      debugPrint('Error bulk updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.transaction.syncStatus == SyncStatus.pending;

    // Check if all items are completed
    final allCompleted = _items.isNotEmpty && _items.every((it) => it['item_status'] == 'completed');
    final hasPendingOrProcessing = _items.any((it) => it['item_status'] == 'pending' || it['item_status'] == 'processing');

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderMedium,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header: Transaction ID & Status Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.transaction.id,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.transaction.time} • Kasir POSAN',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Payment Method Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3EEE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.transaction.paymentMethod.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Sync Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: isPending
                                  ? const Color(0xFFFDEEE6)
                                  : const Color(0xFFEAF7EE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPending
                                      ? Icons.hourglass_top_rounded
                                      : Icons.cloud_done_rounded,
                                  size: 11,
                                  color: isPending
                                      ? const Color(0xFFBA6A34)
                                      : const Color(0xFF2E7D32),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isPending ? 'PENDING' : 'SYNCED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isPending
                                        ? const Color(0xFFBA6A34)
                                        : const Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Receipt Breakdown Box (Digital Receipt Look)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5EE),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFECE4D9),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RINCIAN ITEM PESANAN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.transaction.itemSummary,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Color(0xFFECE4D9), height: 1),
                        const SizedBox(height: 10),
                        _buildRow(
                          'Total Tagihan',
                          CurrencyFormatter.format(widget.transaction.totalAmount),
                          isBold: true,
                          valueSize: 15,
                        ),
                        if (widget.transaction.amountPaid > 0) ...[
                          const SizedBox(height: 6),
                          _buildRow(
                            'Uang Diterima (Tunai)',
                            CurrencyFormatter.format(widget.transaction.amountPaid),
                          ),
                          const SizedBox(height: 6),
                          _buildRow(
                            'Kembalian',
                            CurrencyFormatter.format(widget.transaction.changeAmount),
                            valueColor: const Color(0xFF2E7D32),
                            isBold: true,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Modul Kontrol Status Pesanan Kasir (Live Status Stasiun & Aksi Kasir)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE5DECF),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Bar Kasir Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.tune_rounded, color: Color(0xFFBA6A34), size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'STATUS & KONTROL PESANAN STASIUN',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                            if (_isLoading || _isUpdating)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFFBA6A34)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Tombol Aksi Cepat Kasir: Tandai Semua Selesai
                        if (hasPendingOrProcessing)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isUpdating ? null : () => _handleUpdateAllItemsStatus('completed'),
                              icon: const Icon(Icons.done_all_rounded, size: 16),
                              label: const Text(
                                '⚡ Tandai Semua Pesanan Selesai',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF15803D),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          )
                        else if (allCompleted)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF15803D)),
                                SizedBox(width: 6),
                                Text(
                                  'Semua item pesanan sudah selesai dibuat & siap disajikan! ✨',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Daftar Item & Kontrol Status Kasir
                        if (_items.isEmpty && !_isLoading)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pesanan telah tercatat pada sistem kasir.',
                                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _items.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final itemId = item['id'] as int? ?? 0;
                              final prodName = item['product_name']?.toString() ?? 'Item Menu';
                              final qty = item['quantity'] ?? 1;
                              final station = (item['station']?.toString() ?? 'barista').toLowerCase();
                              final itemStatus = item['item_status']?.toString() ?? 'pending';
                              final processedBy = item['processed_by']?.toString();
                              final isBarista = station == 'barista';

                              final isCompleted = itemStatus == 'completed';
                              final isProcessing = itemStatus == 'processing';
                              final isPending = itemStatus == 'pending';

                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9F7F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isProcessing
                                        ? const Color(0xFF93C5FD)
                                        : isCompleted
                                            ? const Color(0xFF86EFAC)
                                            : const Color(0xFFECE4D9),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Station Icon
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: isBarista ? const Color(0xFFF3E8FF) : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            isBarista ? Icons.coffee_rounded : Icons.restaurant_rounded,
                                            size: 14,
                                            color: isBarista ? const Color(0xFF7E22CE) : const Color(0xFFB45309),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Product Name & Quantity
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '$qty x $prodName',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                isBarista ? 'Stasiun Barista (Minuman)' : 'Stasiun Kitchen (Makanan)',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Status Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isCompleted
                                                ? const Color(0xFFDCFCE7)
                                                : isProcessing
                                                    ? const Color(0xFFDBEAFE)
                                                    : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isCompleted
                                                ? 'SELESAI'
                                                : isProcessing
                                                    ? 'DIPROSES'
                                                    : 'MASUK',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: isCompleted
                                                  ? const Color(0xFF15803D)
                                                  : isProcessing
                                                      ? const Color(0xFF1D4ED8)
                                                      : const Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Processed By Detail
                                    if (isProcessing && processedBy != null && processedBy.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF1D4ED8)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Sedang diproses oleh: $processedBy',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 8),
                                    const Divider(height: 1, color: Color(0xFFEBE3D7)),
                                    const SizedBox(height: 6),

                                    // Cashier Action Buttons for this item
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Ubah status:',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (!isPending)
                                              InkWell(
                                                onTap: _isUpdating ? null : () => _handleUpdateSingleItemStatus(itemId, 'pending'),
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF3EEE7),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text('Masuk', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                                                ),
                                              ),
                                            if (!isPending) const SizedBox(width: 4),
                                            if (!isProcessing)
                                              InkWell(
                                                onTap: _isUpdating ? null : () => _handleUpdateSingleItemStatus(itemId, 'processing'),
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDBEAFE),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text('Proses', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
                                                ),
                                              ),
                                            if (!isProcessing) const SizedBox(width: 4),
                                            if (!isCompleted)
                                              InkWell(
                                                onTap: _isUpdating ? null : () => _handleUpdateSingleItemStatus(itemId, 'completed'),
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDCFCE7),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text('Selesai ✓', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  // Order Timeline Logs if available
                  if (_orderLogs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF8F5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFECE4D9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.history_rounded, size: 16, color: AppColors.textSecondary),
                              SizedBox(width: 6),
                              Text(
                                'RIWAYAT LOG WAKTU PENGERJAAN',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _orderLogs.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final log = _orderLogs[index];
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${log.productName} (${log.status})',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    log.formattedCreatedTime,
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onReprint();
                          },
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: const Text(
                            'Cetak Ulang Struk',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            side: const BorderSide(
                              color: Color(0xFF30221A),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Tutup',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    double valueSize = 13,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
