import 'package:flutter/material.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/cashier_session_model.dart';
import '../../../models/recent_transaction_model.dart';

class ShiftReconciliationModal extends StatefulWidget {
  final CashierSessionModel session;
  final double initialStartingCash;
  final double totalCashSales;
  final List<RecentTransactionModel> transactions;
  final VoidCallback onShiftClosed;

  const ShiftReconciliationModal({
    super.key,
    required this.session,
    this.initialStartingCash = 200000,
    required this.totalCashSales,
    required this.transactions,
    required this.onShiftClosed,
  });

  @override
  State<ShiftReconciliationModal> createState() =>
      _ShiftReconciliationModalState();
}

class _ShiftReconciliationModalState extends State<ShiftReconciliationModal> {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final ThermalPrinterService _printerService = ThermalPrinterService();
  late TextEditingController _physicalCashController;
  final TextEditingController _noteController = TextEditingController();
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    final expectedTotal = widget.initialStartingCash + widget.totalCashSales;
    _physicalCashController =
        TextEditingController(text: expectedTotal.toInt().toString());
  }

  @override
  void dispose() {
    _physicalCashController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _expectedTotal =>
      widget.initialStartingCash + widget.totalCashSales;

  double get _physicalCash =>
      double.tryParse(_physicalCashController.text.trim()) ?? 0.0;

  double get _difference => _physicalCash - _expectedTotal;

  void _handlePrintReport() async {
    final success = await _printerService.printShiftReport(
      session: widget.session,
      totalCashSales: widget.totalCashSales,
      transactions: widget.transactions,
      initialCashAmount: widget.initialStartingCash,
      physicalCash: _physicalCash,
      difference: _difference,
      notes: _noteController.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.print_rounded : Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                success
                    ? 'Laporan Rekonsiliasi Kas berhasil dikirim ke printer thermal.'
                    : 'Laporan siap dicetak (Hubungkan printer bluetooth di Pengaturan).',
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

  void _handleConfirmCloseShift() async {
    setState(() => _isClosing = true);

    final double totalSales = widget.transactions.fold<double>(0, (sum, t) => sum + t.totalAmount);
    final double totalQris = widget.transactions
        .where((t) => t.paymentMethod == TransactionPaymentMethod.qris)
        .fold<double>(0, (sum, t) => sum + t.totalAmount);
    final double totalBank = widget.transactions
        .where((t) => t.paymentMethod == TransactionPaymentMethod.bank)
        .fold<double>(0, (sum, t) => sum + t.totalAmount);

    try {
      await _localDb.recordCloseShift(
        merchantId: widget.session.merchantId,
        cashierName: widget.session.cashierName,
        startingCash: widget.initialStartingCash,
        cashSales: widget.totalCashSales,
        qrisSales: totalQris,
        bankSales: totalBank,
        totalSales: totalSales,
        physicalCash: _physicalCash,
        difference: _difference,
        notes: _noteController.text.trim(),
      );
    } catch (e) {
      debugPrint('Error recording closed shift: $e');
    }

    if (!mounted) return;
    setState(() => _isClosing = false);
    Navigator.pop(context);
    widget.onShiftClosed();
  }

  @override
  Widget build(BuildContext context) {
    final diff = _difference;
    final isMatched = diff == 0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
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

                // Header Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.shiftBadgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_clock_rounded,
                        color: AppColors.shiftBadgeText,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tutup Shift & Rekonsiliasi Kas',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Hitung uang fisik di laci kasir sebelum serah terima',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Calculation Breakdown Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight, width: 1.2),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        'Modal Kas Awal (Float)',
                        CurrencyFormatter.format(widget.initialStartingCash),
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Total Penjualan Tunai',
                        CurrencyFormatter.format(widget.totalCashSales),
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: AppColors.borderLight, height: 1),
                      const SizedBox(height: 10),
                      _buildSummaryRow(
                        'Total Kas Seharusnya (Sistem)',
                        CurrencyFormatter.format(_expectedTotal),
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Physical Cash Input Field
                const Text(
                  'Uang Fisik Kasir di Laci (Rp)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderMedium, width: 1.2),
                  ),
                  child: TextField(
                    controller: _physicalCashController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      prefixIcon: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Text(
                          'Rp',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      prefixIconConstraints: BoxConstraints(minWidth: 40),
                      hintText: '0',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Difference Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMatched
                        ? AppColors.onlineBadgeBg
                        : AppColors.shiftBadgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isMatched
                                ? Icons.check_circle_rounded
                                : Icons.info_outline_rounded,
                            size: 18,
                            color: isMatched
                                ? AppColors.onlineBadgeText
                                : AppColors.shiftBadgeText,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isMatched ? 'Kas Sesuai (Imbang)' : 'Selisih Kas:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isMatched
                                  ? AppColors.onlineBadgeText
                                  : AppColors.shiftBadgeText,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isMatched
                            ? 'Rp0'
                            : (diff > 0
                                ? '+${CurrencyFormatter.format(diff)} (Lebih)'
                                : '${CurrencyFormatter.format(diff)} (Kurang)'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isMatched
                              ? AppColors.onlineBadgeText
                              : AppColors.shiftBadgeText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Notes field
                const Text(
                  'Catatan Tambahan (Opsional)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Contoh: Modal kembalian pecahan 2rb habis...',
                    hintStyle: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handlePrintReport,
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: const Text(
                          'Cetak Laporan',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(
                            color: AppColors.primaryDark,
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isClosing ? null : _handleConfirmCloseShift,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isClosing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Tutup Shift',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
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
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
