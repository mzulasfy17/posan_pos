import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/recent_transaction_model.dart';

class PaymentSuccessDialog extends StatelessWidget {
  final RecentTransactionModel transaction;
  final VoidCallback onPrintReceipt;
  final VoidCallback onFinish;

  const PaymentSuccessDialog({
    super.key,
    required this.transaction,
    required this.onPrintReceipt,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
          children: [
            // Success Checkmark Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.onlineBadgeBg,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.onlineDot,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            const Text(
              'Pembayaran Berhasil!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.chipInactiveBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    transaction.paymentMethod.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.shiftBadgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PENDING SYNC',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.shiftBadgeText,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Receipt Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.chipInactiveBg.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight, width: 1),
              ),
              child: Column(
                children: [
                  _buildReceiptRow('No. Transaksi', transaction.id,
                      isBold: true),
                  const SizedBox(height: 6),
                  _buildReceiptRow('Waktu', transaction.time),
                  const SizedBox(height: 6),
                  _buildReceiptRow('Ringkasan', transaction.itemSummary),
                  const SizedBox(height: 10),
                  const Divider(color: AppColors.borderMedium, height: 1),
                  const SizedBox(height: 10),
                  _buildReceiptRow(
                    'Total Tagihan',
                    CurrencyFormatter.format(transaction.totalAmount),
                    isBold: true,
                  ),
                  const SizedBox(height: 6),
                  _buildReceiptRow(
                    'Uang Diterima',
                    CurrencyFormatter.format(transaction.amountPaid),
                  ),
                  const SizedBox(height: 6),
                  _buildReceiptRow(
                    'Kembalian',
                    CurrencyFormatter.format(transaction.changeAmount),
                    valueColor: AppColors.onlineBadgeText,
                    isBold: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Print Receipt Button
            OutlinedButton.icon(
              onPressed: onPrintReceipt,
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text(
                'Cetak Struk (Printer Bluetooth)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primaryDark, width: 1.2),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Done / New Order Button
            ElevatedButton(
              onPressed: onFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Selesai / Transaksi Baru',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
}

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
