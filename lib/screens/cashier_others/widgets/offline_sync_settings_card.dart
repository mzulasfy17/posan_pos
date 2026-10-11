import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/cashier_session_model.dart';

class OfflineSyncSettingsCard extends StatelessWidget {
  final CashierSessionModel session;
  final VoidCallback onSyncTap;
  final VoidCallback onUpdateMenuTap;

  const OfflineSyncSettingsCard({
    super.key,
    required this.session,
    required this.onSyncTap,
    required this.onUpdateMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.chipInactiveBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.cloud_sync_rounded,
                        size: 18,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Pusat Data & Offline Sync',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: session.pendingSyncCount > 0
                      ? AppColors.shiftBadgeBg
                      : AppColors.onlineBadgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: session.pendingSyncCount > 0
                            ? AppColors.shiftBadgeText
                            : AppColors.onlineDot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      session.pendingSyncCount > 0
                          ? '${session.pendingSyncCount} PENDING'
                          : 'TERSINKRON',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: session.pendingSyncCount > 0
                            ? AppColors.shiftBadgeText
                            : AppColors.onlineBadgeText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Storage Info Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  'Penyimpanan Lokal',
                  '${session.localStorageCount} Transaksi tersimpan',
                  Icons.save_rounded,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Antrean Sinkronisasi',
                  session.pendingSyncCount > 0
                      ? '${session.pendingSyncCount} Transaksi belum sync'
                      : 'Semua data aman tersinkron',
                  Icons.sync_rounded,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Sinkronisasi Terakhir',
                  session.lastSyncTime,
                  Icons.access_time_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSyncTap,
                  icon: session.isAutoSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(
                    session.isAutoSyncing
                        ? 'Menyinkronkan...'
                        : 'Sinkronkan Data',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUpdateMenuTap,
                  icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                  label: const Text(
                    'Perbarui Menu',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(
                      color: AppColors.primaryDark,
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
