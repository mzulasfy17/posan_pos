import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum AttendanceDialogType {
  checkIn,
  checkOut,
}

class AttendanceConfirmDialog extends StatelessWidget {
  final AttendanceDialogType type;
  final VoidCallback onConfirm;

  const AttendanceConfirmDialog({
    super.key,
    required this.type,
    required this.onConfirm,
  });

  static Future<bool?> show(
    BuildContext context, {
    required AttendanceDialogType type,
    required VoidCallback onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AttendanceConfirmDialog(
        type: type,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCheckIn = type == AttendanceDialogType.checkIn;
    final title = isCheckIn ? 'Konfirmasi Absen Masuk' : 'Konfirmasi Absen Keluar';
    final message = isCheckIn
        ? 'Apakah kamu yakin ingin mencatat waktu masuk sekarang?'
        : 'Apakah kamu yakin ingin mengakhiri sesi kerja hari ini?';
    final confirmButtonText = isCheckIn ? 'Ya, Absen Masuk' : 'Ya, Absen Keluar';
    final iconData = isCheckIn ? Icons.login_rounded : Icons.logout_rounded;
    final iconColor = isCheckIn ? const Color(0xFF278838) : AppColors.accentRust;
    final iconBgColor = isCheckIn ? AppColors.onlineBadgeBg : AppColors.cartIconBg;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon & Title Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCheckIn ? 'Mulai sesi kerja' : 'Akhiri sesi kerja',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 16),

            // Dialog Message Body
            Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons: Batal & Ya, Absen...
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.borderMedium),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCheckIn ? AppColors.primaryDark : AppColors.accentRust,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(
                      confirmButtonText,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
