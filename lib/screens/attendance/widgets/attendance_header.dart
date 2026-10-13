import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/offline_sync_manager.dart';
import '../../../core/theme/app_colors.dart';

class AttendanceHeader extends StatefulWidget {
  final bool isStandalone;
  final VoidCallback? onBackTap;
  final VoidCallback? onProfileTap;

  const AttendanceHeader({
    super.key,
    this.isStandalone = false,
    this.onBackTap,
    this.onProfileTap,
  });

  @override
  State<AttendanceHeader> createState() => _AttendanceHeaderState();
}

class _AttendanceHeaderState extends State<AttendanceHeader> {
  late DateTime _currentTime;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String _getGreeting() {
    final hour = _currentTime.hour;
    if (hour >= 4 && hour < 11) {
      return 'Selamat pagi';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat siang';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat sore';
    } else {
      return 'Selamat malam';
    }
  }

  String _getUserName() {
    final user = AuthService().currentUser;
    if (user != null && user.name.trim().isNotEmpty) {
      return user.name.trim();
    }
    final session = AuthService().currentSession;
    if (session.cashierName.trim().isNotEmpty) {
      return session.cashierName.trim();
    }
    return 'Karyawan POSAN';
  }

  String _getStationName() {
    final user = AuthService().currentUser;
    if (user != null) {
      if (user.isBarista) return 'Stasiun Barista (Minuman)';
      if (user.isKitchen) return 'Stasiun Dapur (Kitchen)';
      if (user.isCashier) return 'Kasir Utama';
      return user.roleDisplayTitle;
    }
    final session = AuthService().currentSession;
    if (session.activeStation.isNotEmpty) {
      return session.activeStation;
    }
    return 'Stasiun Kasir';
  }

  String _getMerchantOutlet() {
    final user = AuthService().currentUser;
    if (user?.merchantName?.isNotEmpty == true) {
      return user!.merchantName!;
    }
    final session = AuthService().currentSession;
    if (session.merchantName.isNotEmpty) {
      return session.merchantName;
    }
    return 'POSAN Café';
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();
    final userName = _getUserName();
    final stationName = _getStationName();
    final merchantName = _getMerchantOutlet();
    final syncManager = OfflineSyncManager();

    final dateString = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_currentTime);
    final timeString = DateFormat('HH:mm:ss').format(_currentTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Kasir Top Bar (Logo, Merchant & Online Status) - Hanya tampil jika Kasir / Mode Tab
        if (!widget.isStandalone) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo POSAN
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEFE8DE), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
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
                          Icons.event_available_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info Merchant & Judul Halaman
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Absensi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$merchantName • $stationName',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Status Sinkronisasi
              ValueListenableBuilder<bool>(
                valueListenable: syncManager.isOnlineNotifier,
                builder: (context, isOnline, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.onlineBadgeBg : AppColors.chipInactiveBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOnline ? const Color(0xFFC3E6CB) : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isOnline ? AppColors.onlineDot : AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOnline ? AppColors.onlineBadgeText : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Profile Avatar
              InkWell(
                onTap: widget.onProfileTap,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.person, color: Colors.white, size: 19),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // 2. Greeting & Live Clock Card
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderLight, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Sapaan & Tanggal Hari Ini
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting,',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$userName 👋',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 12.5,
                          color: AppColors.accentRust,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            dateString,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
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

              const SizedBox(width: 12),

              // Jam Digital Aktif (Real-time Clock Badge)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: Color(0xFFD4C7B8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          timeString,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'WIB • Waktu Perangkat',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFFB8A99A),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
