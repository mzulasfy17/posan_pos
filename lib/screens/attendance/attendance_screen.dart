import 'package:flutter/material.dart';
import '../../core/services/attendance_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_layout.dart';
import 'widgets/attendance_action_buttons.dart';
import 'widgets/attendance_header.dart';
import 'widgets/attendance_history_section.dart';
import 'widgets/attendance_status_card.dart';

class AttendanceScreen extends StatefulWidget {
  final bool isStandalone;
  final VoidCallback? onBackTap;

  const AttendanceScreen({
    super.key,
    this.isStandalone = false,
    this.onBackTap,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceService _service = AttendanceService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.loadAttendanceData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isWide(context);
    final canPop = widget.isStandalone || Navigator.of(context).canPop();

    final user = AuthService().currentUser;
    final isBarista = user?.isBarista ?? false;
    final isKitchen = user?.isKitchen ?? false;

    Color appBarBg = AppColors.primaryDark;
    String stationTitle = 'Absensi Karyawan';
    String stationSubtitle = 'Pencatatan Kehadiran Karyawan';

    if (isBarista) {
      appBarBg = const Color(0xFF1E1712);
      stationTitle = 'Absensi Stasiun Barista';
      stationSubtitle = 'Minuman & Kopi • POSAN';
    } else if (isKitchen) {
      appBarBg = const Color(0xFF24140E);
      stationTitle = 'Absensi Stasiun Dapur';
      stationSubtitle = 'Makanan & Pastry • POSAN';
    }

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final today = _service.todayRecord;
        final history = _service.filteredHistory;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: canPop
              ? AppBar(
                  backgroundColor: appBarBg,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    tooltip: 'Kembali',
                    onPressed: widget.onBackTap ?? () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stationTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        stationSubtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB5A99B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: _service.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync_rounded, color: Colors.white70),
                      tooltip: 'Sinkronkan Database',
                      onPressed: _service.isLoading
                          ? null
                          : () async {
                              await _service.refresh();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Data absensi berhasil disinkronkan dengan database.'),
                                    backgroundColor: AppColors.primaryDark,
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                )
              : null,
          body: SafeArea(
            top: !canPop,
            bottom: false,
            child: MaxContentWidth(
              maxWidth: 960,
              child: RefreshIndicator(
                onRefresh: () => _service.refresh(),
                color: AppColors.accentRust,
                child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Header (Sapaan Karyawan, Tanggal, & Jam Real-Time)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: AttendanceHeader(
                        isStandalone: canPop,
                        onBackTap: widget.onBackTap ?? () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ),
                  ),

                  if (isWide)
                    // Tata Letak Tablet / Layar Lebar: 2 Kolom
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kolom Kiri: Kartu Status & Tombol Aksi
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AttendanceStatusCard(record: today),
                                  const SizedBox(height: 14),
                                  AttendanceActionButtons(
                                    record: today,
                                    onCheckIn: () => _service.checkIn(),
                                    onCheckOut: () => _service.checkOut(),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDemoToolsFooter(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 18),

                            // Kolom Kanan: Riwayat Absensi
                            Expanded(
                              flex: 5,
                              child: AttendanceHistorySection(
                                records: history,
                                selectedPeriod: _service.selectedFilterPeriod,
                                onPeriodChanged: (p) => _service.setFilterPeriod(p),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // Tata Letak Standar Ponsel Portrait: 1 Kolom
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AttendanceStatusCard(record: today),
                            const SizedBox(height: 14),
                            AttendanceActionButtons(
                              record: today,
                              onCheckIn: () => _service.checkIn(),
                              onCheckOut: () => _service.checkOut(),
                            ),
                            const SizedBox(height: 20),
                            AttendanceHistorySection(
                              records: history,
                              selectedPeriod: _service.selectedFilterPeriod,
                              onPeriodChanged: (p) => _service.setFilterPeriod(p),
                            ),
                            const SizedBox(height: 14),
                            _buildDemoToolsFooter(),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Ruang Aman Bawah
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 32),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

  /// Indikator status sinkronisasi database
  Widget _buildDemoToolsFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.onlineDot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Flexible(
              child: Text(
                'Terhubung ke Database • Tarik untuk segarkan',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
