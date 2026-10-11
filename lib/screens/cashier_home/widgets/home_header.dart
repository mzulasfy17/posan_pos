import 'package:flutter/material.dart';
import '../../../core/services/offline_sync_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/cashier_session_model.dart';

class HomeHeader extends StatelessWidget {
  final CashierSessionModel session;
  final VoidCallback? onProfileTap;
  final VoidCallback? onStatusTap;

  const HomeHeader({
    super.key,
    required this.session,
    this.onProfileTap,
    this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    final syncManager = OfflineSyncManager();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Brand logo icon box
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFEFE8DE),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset(
              'assets/images/posan_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.primaryDark,
                child: const Center(
                  child: Icon(
                    Icons.coffee_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Brand name & merchant outlet
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'POSAN',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                session.merchantName,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Online & 2-Minute Idle Auto-Sync Status Badge
        ValueListenableBuilder<bool>(
          valueListenable: syncManager.isOnlineNotifier,
          builder: (context, isOnline, _) {
            return ValueListenableBuilder<int>(
              valueListenable: syncManager.remainingSecondsNotifier,
              builder: (context, remainingSecs, _) {
                final mins = remainingSecs ~/ 60;
                final secs = remainingSecs % 60;
                final countdownStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

                return ValueListenableBuilder<int>(
                  valueListenable: syncManager.pendingSyncCountNotifier,
                  builder: (context, pendingCount, _) {
                    return InkWell(
                      onTap: onStatusTap,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOnline
                              ? (pendingCount > 0 ? AppColors.alertPeachBg : AppColors.onlineBadgeBg)
                              : AppColors.chipInactiveBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isOnline
                                ? (pendingCount > 0 ? AppColors.alertPeachBorder : const Color(0xFFC3E6CB))
                                : AppColors.borderLight,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isOnline
                                    ? (pendingCount > 0 ? AppColors.accentRust : AppColors.onlineDot)
                                    : AppColors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline
                                  ? (pendingCount > 0 ? '$pendingCount pending ($countdownStr)' : 'Postgre • $countdownStr')
                                  : 'SQLite Offline',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isOnline
                                    ? (pendingCount > 0 ? AppColors.accentRust : AppColors.onlineBadgeText)
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        const SizedBox(width: 10),

        // Profile Avatar Button
        InkWell(
          onTap: onProfileTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
