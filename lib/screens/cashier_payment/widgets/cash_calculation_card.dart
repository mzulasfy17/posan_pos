import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class CashCalculationCard extends StatelessWidget {
  final double totalAmount;
  final double receivedAmount;
  final VoidCallback? onClear;

  const CashCalculationCard({
    super.key,
    required this.totalAmount,
    required this.receivedAmount,
    this.onClear,
  });

  double get changeAmount => receivedAmount - totalAmount;

  @override
  Widget build(BuildContext context) {
    final isSufficient = receivedAmount >= totalAmount;
    final isExact = isSufficient && changeAmount == 0;
    final shortage = totalAmount - receivedAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
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
          // Total Tagihan Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Tagihan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                CurrencyFormatter.format(totalAmount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Uang Diterima Label
          const Text(
            'Uang Diterima',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),

          // Uang Diterima Input Box
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderMedium, width: 1),
            ),
            child: Row(
              children: [
                // "Rp" Prefix Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  child: const Text(
                    'Rp',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.borderMedium,
                ),
                const SizedBox(width: 12),

                // Amount value / Placeholder
                Expanded(
                  child: Text(
                    receivedAmount > 0
                        ? CurrencyFormatter.format(receivedAmount)
                            .replaceAll('Rp', '')
                            .trim()
                        : 'Masukkan nominal...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: receivedAmount > 0
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: receivedAmount > 0
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Clear button (X)
                if (receivedAmount > 0)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: onClear,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Uang Kembalian Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Uang Kembalian',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (receivedAmount > 0 && isExact)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.onlineBadgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: AppColors.onlineBadgeText,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Uang Pas',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onlineBadgeText,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (receivedAmount > 0 && !isSufficient)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.outOfStockBadgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Kurang ${CurrencyFormatter.format(shortage)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.outOfStockBadgeText,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isSufficient
                      ? CurrencyFormatter.format(changeAmount)
                      : 'Rp0',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isSufficient
                        ? AppColors.onlineBadgeText
                        : AppColors.textMuted,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

