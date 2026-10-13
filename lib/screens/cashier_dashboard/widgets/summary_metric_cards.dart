import 'package:flutter/material.dart';
import '../../../core/services/offline_sync_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/cashier_session_model.dart';

class SummaryMetricCards extends StatelessWidget {
  final CashierSessionModel session;
  final VoidCallback? onSalesTap;
  final VoidCallback? onSyncTap;

  const SummaryMetricCards({
    super.key,
    required this.session,
    this.onSalesTap,
    this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    final syncManager = OfflineSyncManager();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Card: Penjualan Hari Ini
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSalesTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Icon + Label
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.cartIconBg,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.bar_chart_rounded,
                                size: 15,
                                color: AppColors.cartIconColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'Penjualan Hari Ini',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Middle Row: Amount
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(session.todaySalesAmount),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Bottom Row: Subtitle
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${session.todayTransactionCount} transaksi (Lokal)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
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

          const SizedBox(width: 12),

          // Right Card: Sinkronisasi Data Cloud & Offline (with live 2-min countdown)
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: syncManager.pendingSyncCountNotifier,
              builder: (context, pendingCount, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: syncManager.remainingSecondsNotifier,
                  builder: (context, remainingSecs, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: syncManager.isSyncingNotifier,
                      builder: (context, isSyncing, _) {
                        final isPending = pendingCount > 0;
                        final mins = remainingSecs ~/ 60;
                        final secs = remainingSecs % 60;
                        final countdownStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onSyncTap,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: isPending
                                    ? AppColors.alertPeachBg
                                    : const Color(0xFFEAF7EE),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPending
                                      ? AppColors.alertPeachBorder
                                      : const Color(0xFFC3E6CB),
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Top Row: Icon + Label
                                  Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: isPending
                                              ? AppColors.alertPeachIconBg
                                              : const Color(0xFFD4EDDA),
                                          borderRadius: BorderRadius.circular(7),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            isPending
                                                ? Icons.cloud_upload_outlined
                                                : Icons.cloud_done_rounded,
                                            size: 15,
                                            color: isPending
                                                ? AppColors.alertPeachText
                                                : const Color(0xFF2E7D32),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          isPending ? 'Perlu Sinkron' : 'Cloud Sync',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: isPending
                                                ? AppColors.alertPeachText
                                                : const Color(0xFF2E7D32),
                                            letterSpacing: -0.2,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Middle Row: Status Value & Countdown
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      isPending
                                          ? '$pendingCount Pending ($countdownStr)'
                                          : 'Lokal Aktif ($countdownStr)',
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                        color: isPending
                                            ? AppColors.alertPeachText
                                            : const Color(0xFF2E7D32),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Bottom Row: Sinkronkan Action
                                  Row(
                                    children: [
                                      isSyncing
                                          ? SizedBox(
                                              width: 12,
                                              height: 12,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.8,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  isPending
                                                      ? AppColors.alertPeachText
                                                      : const Color(0xFF2E7D32),
                                                ),
                                              ),
                                            )
                                          : Icon(
                                              Icons.sync_rounded,
                                              size: 13,
                                              color: isPending
                                                  ? AppColors.alertPeachText
                                                  : const Color(0xFF2E7D32),
                                            ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          isSyncing
                                              ? 'Menyinkronkan...'
                                              : 'Auto 2 mnt • Ketuk sync',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isPending
                                                ? AppColors.alertPeachText
                                                : const Color(0xFF2E7D32),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 15,
                                        color: isPending
                                            ? AppColors.alertPeachText
                                            : const Color(0xFF2E7D32),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
