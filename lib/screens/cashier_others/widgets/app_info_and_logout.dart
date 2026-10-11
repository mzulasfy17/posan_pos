import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AppInfoAndLogout extends StatelessWidget {
  final int pendingSyncCount;
  final VoidCallback onLogout;

  const AppInfoAndLogout({
    super.key,
    required this.pendingSyncCount,
    required this.onLogout,
  });

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.outOfStockBadgeText),
            SizedBox(width: 8),
            Text(
              'Keluar Sesi Kasir?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apakah Anda yakin ingin mengakhiri sesi kasir saat ini?',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
            if (pendingSyncCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.shiftBadgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: AppColors.shiftBadgeText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Peringatan: Terdapat $pendingSyncCount transaksi offline yang belum disinkronkan ke server.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.shiftBadgeText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.outOfStockBadgeText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // App Version info
        const Center(
          child: Column(
            children: [
              Text(
                'POSAN (Point of Sales) Mobile',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Versi 1.0.0 • Offline-First Engine v2.4',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Logout Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showLogoutConfirmDialog(context),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text(
              'Keluar dari Sesi Kasir',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.outOfStockBadgeText,
              side: const BorderSide(
                color: AppColors.outOfStockBadgeText,
                width: 1.2,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
