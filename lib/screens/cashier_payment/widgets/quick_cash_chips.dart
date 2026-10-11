import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class QuickCashChips extends StatelessWidget {
  final double totalAmount;
  final double currentReceivedAmount;
  final ValueChanged<double> onAmountSelected;

  const QuickCashChips({
    super.key,
    required this.totalAmount,
    required this.currentReceivedAmount,
    required this.onAmountSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 9 Preset amounts matching screenshot 2
    final presets = <_QuickAmountItem>[
      _QuickAmountItem(
        amount: totalAmount,
        subtitle: 'Uang Pas',
        isExact: true,
      ),
      const _QuickAmountItem(amount: 60000),
      const _QuickAmountItem(amount: 100000),
      const _QuickAmountItem(amount: 50000),
      const _QuickAmountItem(amount: 20000),
      const _QuickAmountItem(amount: 10000),
      const _QuickAmountItem(amount: 5000),
      const _QuickAmountItem(amount: 2000),
      const _QuickAmountItem(amount: 1000),
    ];

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
          // Header: Icon + "Nominal Cepat"
          const Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 18,
                color: AppColors.textPrimary,
              ),
              SizedBox(width: 8),
              Text(
                'Nominal Cepat',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3x3 Grid of Buttons
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: presets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.3,
            ),
            itemBuilder: (context, index) {
              final item = presets[index];
              final isSelected = currentReceivedAmount == item.amount;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onAmountSelected(item.amount),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryDark
                            : AppColors.borderMedium,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: item.isExact
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(item.amount),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Uang Pas',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.8)
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 11,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                            ],
                          )
                        : Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                CurrencyFormatter.format(item.amount),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAmountItem {
  final double amount;
  final String? subtitle;
  final bool isExact;

  const _QuickAmountItem({
    required this.amount,
    this.subtitle,
    this.isExact = false,
  });
}

