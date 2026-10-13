import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/attendance_model.dart';

class AttendanceStatusCard extends StatelessWidget {
  final AttendanceRecordModel record;

  const AttendanceStatusCard({
    super.key,
    required this.record,
  });

  Color _getStatusThemeColor() {
    switch (record.status) {
      case AttendanceStatus.notCheckedIn:
        return const Color(0xFF8E8881);
      case AttendanceStatus.working:
        return AppColors.onlineBadgeText;
      case AttendanceStatus.completed:
        return AppColors.accentRust;
    }
  }

  Color _getStatusBgColor() {
    switch (record.status) {
      case AttendanceStatus.notCheckedIn:
        return Colors.white;
      case AttendanceStatus.working:
        return const Color(0xFFF6FBF7);
      case AttendanceStatus.completed:
        return const Color(0xFFFAF7F2);
    }
  }

  Color _getStatusBorderColor() {
    switch (record.status) {
      case AttendanceStatus.notCheckedIn:
        return AppColors.borderLight;
      case AttendanceStatus.working:
        return const Color(0xFFC7EBD0);
      case AttendanceStatus.completed:
        return const Color(0xFFEADBCE);
    }
  }

  IconData _getStatusIcon() {
    switch (record.status) {
      case AttendanceStatus.notCheckedIn:
        return Icons.timer_outlined;
      case AttendanceStatus.working:
        return Icons.work_history_rounded;
      case AttendanceStatus.completed:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusThemeColor();
    final cardBgColor = _getStatusBgColor();
    final borderColor = _getStatusBorderColor();
    final statusIcon = _getStatusIcon();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Baris Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, size: 16, color: statusColor),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Status Hari Ini',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Badge Status Utama
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      record.status.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Dua Kotak Metrik Jam: Jam Masuk & Jam Keluar
          Row(
            children: [
              // Kotak Jam Masuk
              Expanded(
                child: _buildTimeBox(
                  icon: Icons.login_rounded,
                  iconColor: const Color(0xFF2E9A40),
                  boxBg: const Color(0xFFF3F9F4),
                  label: 'Jam Masuk',
                  timeValue: record.formattedCheckIn,
                  statusText: record.checkInTime != null ? 'Tercatat' : 'Belum absen',
                  isRecorded: record.checkInTime != null,
                ),
              ),
              const SizedBox(width: 10),

              // Kotak Jam Keluar
              Expanded(
                child: _buildTimeBox(
                  icon: Icons.logout_rounded,
                  iconColor: const Color(0xFFBA6A34),
                  boxBg: const Color(0xFFFDF6F0),
                  label: 'Jam Keluar',
                  timeValue: record.formattedCheckOut,
                  statusText: record.checkOutTime != null
                      ? 'Tercatat'
                      : (record.checkInTime != null ? 'Menunggu selesai' : 'Belum selesai'),
                  isRecorded: record.checkOutTime != null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3. Banner Durasi Kerja
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.chipInactiveBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.timelapse_rounded,
                    size: 15,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Durasi Kerja',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.status == AttendanceStatus.notCheckedIn
                        ? '-'
                        : (record.checkOutTime != null
                            ? record.formattedDuration
                            : 'Sedang berjalan'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox({
    required IconData icon,
    required Color iconColor,
    required Color boxBg,
    required String label,
    required String timeValue,
    required String statusText,
    required bool isRecorded,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRecorded ? iconColor.withValues(alpha: 0.25) : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            timeValue,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isRecorded ? AppColors.textPrimary : AppColors.textDisabled,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isRecorded ? iconColor : AppColors.textMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
