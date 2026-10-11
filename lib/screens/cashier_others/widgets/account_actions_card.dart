import 'package:flutter/material.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auto_dim_service.dart';
import '../../../core/services/screen_wakelock_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/cashier_session_model.dart';
import 'cashier_help_modal.dart';

class AccountActionsCard extends StatelessWidget {
  final CashierSessionModel session;
  final VoidCallback onLogout;

  const AccountActionsCard({
    super.key,
    required this.session,
    required this.onLogout,
  });

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFD32F2F)),
            SizedBox(width: 8),
            Text(
              'Keluar Sesi Kasir?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin mengakhiri sesi kasir? Pastikan shift kasir Anda telah ditutup.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Ya, Keluar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wakelockService = ScreenWakelockService();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        children: [
          // 1. Layar Selalu Aktif (Cegah Sleep / Wake Lock)
          ListenableBuilder(
            listenable: wakelockService,
            builder: (context, _) {
              return _buildSwitchItem(
                context: context,
                icon: Icons.stay_current_portrait_rounded,
                iconBg: const Color(0xFFFEF3E8),
                iconColor: const Color(0xFFBA6A34),
                title: 'Layar Selalu Aktif',
                subtitle: wakelockService.isKeepScreenOn
                    ? 'Layar tidak mati saat kasir terbuka (Aktif)'
                    : 'Mengikuti batas waktu layar perangkat (Mati)',
                value: wakelockService.isKeepScreenOn,
                onChanged: (val) async {
                  await wakelockService.setKeepScreenOn(val);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              val
                                  ? Icons.brightness_high_rounded
                                  : Icons.brightness_auto_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                val
                                    ? 'Mode Layar Selalu Aktif dinyalakan'
                                    : 'Mode Layar Selalu Aktif dimatikan',
                                style: const TextStyle(fontSize: 13),
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
                  }
                },
              );
            },
          ),
          const Divider(color: Color(0xFFECE4D9), height: 1, indent: 16, endIndent: 16),

          // 2. Redup Layar Otomatis saat Idle (Hemat Daya & Cegah Burn-in)
          ListenableBuilder(
            listenable: AutoDimService(),
            builder: (context, _) {
              final autoDim = AutoDimService();
              return _buildSwitchItem(
                context: context,
                icon: Icons.brightness_auto_rounded,
                iconBg: const Color(0xFFF3EEE7),
                iconColor: AppColors.primaryDark,
                title: 'Redup Layar Otomatis',
                subtitle: autoDim.isAutoDimEnabled
                    ? 'Layar meredup otomatis saat tidak digunakan (60 detik)'
                    : 'Kecerahan layar tetap stabil tanpa peredupan',
                value: autoDim.isAutoDimEnabled,
                onChanged: (val) {
                  autoDim.setAutoDimEnabled(val);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              val
                                  ? Icons.brightness_auto_rounded
                                  : Icons.brightness_high_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                val
                                    ? 'Redup Layar Otomatis diaktifkan (60s idle)'
                                    : 'Redup Layar Otomatis dimatikan',
                                style: const TextStyle(fontSize: 13),
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
                  }
                },
              );
            },
          ),
          const Divider(color: Color(0xFFECE4D9), height: 1, indent: 16, endIndent: 16),

          // 3. Bersihkan Cache & Padatkan Data (Reclaim Storage)
          _buildActionItem(
            icon: Icons.cleaning_services_rounded,
            iconBg: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            title: 'Bersihkan Cache & Padatkan Data',
            subtitle: 'Hapus transaksi tersinkron & padatkan penyimpanan lokal',
            onTap: () async {
              try {
                PaintingBinding.instance.imageCache.clear();
                PaintingBinding.instance.imageCache.clearLiveImages();
                await LocalDatabaseService().deleteAllSyncedTransactions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('Penyimpanan lokal & cache berhasil dibersihkan!'),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF2E7D32),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Gagal membersihkan cache: $e'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
          const Divider(color: Color(0xFFECE4D9), height: 1, indent: 16, endIndent: 16),

          // 4. Pusat Bantuan & Panduan
          _buildActionItem(
            icon: Icons.help_outline_rounded,
            iconBg: const Color(0xFFFDEEE6),
            iconColor: const Color(0xFFBA6A34),
            title: 'Pusat Bantuan & Panduan',
            subtitle: 'Panduan kasir, printer & CS WhatsApp 24/7',
            onTap: () => CashierHelpModal.show(context),
          ),
          const Divider(color: Color(0xFFECE4D9), height: 1, indent: 16, endIndent: 16),

          // 5. Keluar Sesi Kasir (Logout)
          _buildActionItem(
            icon: Icons.logout_rounded,
            iconBg: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFD32F2F),
            title: 'Keluar Sesi Kasir',
            titleColor: const Color(0xFFD32F2F),
            subtitle: 'Akhiri sesi kasir ${session.cashierName}',
            onTap: () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchItem({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primaryDark,
              activeTrackColor: AppColors.primaryDark.withValues(alpha: 0.25),
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    Color? titleColor,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: titleColor ?? AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
