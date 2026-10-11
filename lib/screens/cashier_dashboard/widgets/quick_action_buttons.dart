import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class QuickActionButtons extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onOrderHistoryTap;
  final VoidCallback onSyncTap;

  const QuickActionButtons({
    super.key,
    required this.pendingCount,
    required this.onOrderHistoryTap,
    required this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left Button: Riwayat Order
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOrderHistoryTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 17,
                      color: AppColors.accentRust,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Riwayat Order',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Right Button: Sinkronkan (3)
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSyncTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.chipInactiveBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sync_rounded,
                      size: 17,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        pendingCount > 0
                            ? 'Sinkronkan ($pendingCount)'
                            : 'Sinkronkan',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
