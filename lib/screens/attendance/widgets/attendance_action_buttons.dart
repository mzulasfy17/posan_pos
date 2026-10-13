import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/attendance_model.dart';
import 'attendance_confirm_dialog.dart';

class AttendanceActionButtons extends StatelessWidget {
  final AttendanceRecordModel record;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  const AttendanceActionButtons({
    super.key,
    required this.record,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  void _handleCheckInPress(BuildContext context) {
    AttendanceConfirmDialog.show(
      context,
      type: AttendanceDialogType.checkIn,
      onConfirm: () {
        onCheckIn();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Absen masuk berhasil dicatat. Selamat bertugas!'),
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
      },
    );
  }

  void _handleCheckOutPress(BuildContext context) {
    AttendanceConfirmDialog.show(
      context,
      type: AttendanceDialogType.checkOut,
      onConfirm: () {
        onCheckOut();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Absen keluar berhasil dicatat. Terima kasih atas kerja kerasmu!'),
                ),
              ],
            ),
            backgroundColor: AppColors.accentRust,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCheckIn = record.status == AttendanceStatus.notCheckedIn;
    final canCheckOut = record.status == AttendanceStatus.working;
    final isCompleted = record.status == AttendanceStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Tombol Absen Masuk
            Expanded(
              child: _buildButton(
                context: context,
                label: canCheckIn ? 'Absen Masuk' : 'Sudah Masuk',
                icon: Icons.login_rounded,
                isEnabled: canCheckIn,
                activeBgColor: AppColors.primaryDark,
                activeFgColor: Colors.white,
                onPressed: canCheckIn ? () => _handleCheckInPress(context) : null,
              ),
            ),
            const SizedBox(width: 12),

            // Tombol Absen Keluar
            Expanded(
              child: _buildButton(
                context: context,
                label: isCompleted
                    ? 'Sudah Keluar'
                    : 'Absen Keluar',
                icon: Icons.logout_rounded,
                isEnabled: canCheckOut,
                activeBgColor: AppColors.accentRust,
                activeFgColor: Colors.white,
                onPressed: canCheckOut ? () => _handleCheckOutPress(context) : null,
              ),
            ),
          ],
        ),

        // Keterangan status tombol
        const SizedBox(height: 8),
        Center(
          child: Text(
            canCheckIn
                ? 'Tekan "Absen Masuk" untuk memulai waktu kerja hari ini.'
                : (canCheckOut
                    ? 'Shift aktif. Tekan "Absen Keluar" saat sesi kerja berakhir.'
                    : 'Sesi kerja hari ini telah selesai.'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isEnabled,
    required Color activeBgColor,
    required Color activeFgColor,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? activeBgColor : const Color(0xFFECE7DE),
          foregroundColor: isEnabled ? activeFgColor : AppColors.textDisabled,
          disabledBackgroundColor: const Color(0xFFECE7DE),
          disabledForegroundColor: AppColors.textDisabled,
          elevation: isEnabled ? 2 : 0,
          shadowColor: activeBgColor.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isEnabled ? Colors.transparent : const Color(0xFFE2DDD3),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isEnabled ? activeFgColor : AppColors.textDisabled,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isEnabled ? activeFgColor : AppColors.textDisabled,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
