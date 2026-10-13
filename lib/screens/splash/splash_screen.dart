import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/offline_sync_manager.dart';
import '../../core/services/posan_api_service.dart';
import '../../core/services/screen_wakelock_service.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_layout.dart';
import '../auth/login_screen.dart';
import '../barista_station/barista_station_screen.dart';
import '../kitchen_station/kitchen_station_screen.dart';
import '../cashier_home/cashier_home_screen.dart';

class SplashScreen extends StatefulWidget {
  final Duration duration;
  final bool autoNavigate;

  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 1000),
    this.autoNavigate = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _statusText = 'Memuat data lokal...';
  double _progressValue = 0.25;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();

    // Inisialisasi cepat modul aplikasi selama splash
    _initAppServices();
  }

  Future<void> _initAppServices() async {
    final startTime = DateTime.now();

    // Visual progression halus di detik awal
    Timer(const Duration(milliseconds: 300), () {
      if (mounted && _progressValue < 0.75) {
        setState(() {
          _statusText = 'Menyiapkan modul aplikasi...';
          _progressValue = 0.75;
        });
      }
    });

    try {
      // 1. Muat environment (.env)
      try {
        await dotenv.load(fileName: ".env");
        debugPrint('Environment loaded: BASE_URL=${dotenv.env['BASE_URL']}');
      } catch (e) {
        debugPrint('Notice: .env file not loaded ($e). Using default/fallback.');
      }
      PosanApiService().resetBaseUrl();

      // 2. Inisialisasi tanggal, sesi akun, dan penyimpanan offline dengan timeout maksimal 1.2 detik
      await Future.wait([
        initializeDateFormatting('id_ID', null),
        AuthService().restoreSession(),
        OfflineSyncManager().initialize(),
      ]).timeout(const Duration(milliseconds: 1200), onTimeout: () {
        debugPrint('Init timeout guard reached, continuing...');
        return [];
      });

      // 3. Service hardware dijalankan asinkron tanpa menahan navigasi
      unawaited(ScreenWakelockService().init());
      unawaited(ThermalPrinterService().init());

      if (mounted) {
        setState(() {
          _statusText = 'Sistem kasir siap!';
          _progressValue = 1.0;
        });
      }
    } catch (e) {
      debugPrint('Startup initialization notice: $e');
    }

    // Pastikan durasi splash tampil konsisten 1 - 1.2 detik
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    final minDuration = widget.duration.inMilliseconds;
    if (elapsed < minDuration) {
      await Future.delayed(Duration(milliseconds: minDuration - elapsed));
    }

    if (mounted && widget.autoNavigate) {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    final user = AuthService().currentUser;
    Widget destination;
    if (user != null) {
      if (user.isBarista) {
        destination = const BaristaStationScreen();
      } else if (user.isKitchen) {
        destination = const KitchenStationScreen();
      } else {
        destination = const CashierHomeScreen();
      }
    } else {
      destination = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = Responsive.isLandscape(context);
    final screenH = MediaQuery.sizeOf(context).height;
    final isShortScreen = screenH < 520;
    final logoSize = isShortScreen ? 90.0 : (isLandscape ? 120.0 : 160.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Background ambient glow circles
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentRust.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBrown.withValues(alpha: 0.06),
                ),
              ),
            ),

            // Main Content Center
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: isShortScreen ? 12 : 24,
                ),
                child: MaxContentWidth(
                  maxWidth: 500,
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Logo Container with soft shadow
                              Container(
                                width: logoSize,
                                height: logoSize,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(isShortScreen ? 20 : 28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryDark.withValues(alpha: 0.12),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: AppColors.accentRust.withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(isShortScreen ? 20 : 28),
                                  child: Image.asset(
                                    'assets/images/posan_logo.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: AppColors.primaryDark,
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.point_of_sale_rounded,
                                                color: Colors.white,
                                                size: isShortScreen ? 32 : 44,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'posan',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: isShortScreen ? 16 : 20,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(height: isShortScreen ? 14 : 22),

                              // Brand Name & Tagline
                              Text(
                                'POSAN',
                                style: TextStyle(
                                  fontSize: isShortScreen ? 22 : 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.chipInactiveBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'POS MOBILE CAFÉ & COFFEE SHOP',
                                  style: TextStyle(
                                    fontSize: isShortScreen ? 9.5 : 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              SizedBox(height: isShortScreen ? 18 : 28),

                              // Progress Bar
                              SizedBox(
                                width: 170,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 0.0,
                                      end: _progressValue,
                                    ),
                                    duration: const Duration(milliseconds: 400),
                                    builder: (context, val, _) {
                                      return LinearProgressIndicator(
                                        value: val,
                                        minHeight: 5,
                                        backgroundColor: AppColors.chipInactiveBg,
                                        valueColor: const AlwaysStoppedAnimation<Color>(
                                          AppColors.accentRust,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Animated status label
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Text(
                                  _statusText,
                                  key: ValueKey<String>(_statusText),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),

                              if (isShortScreen) ...[
                                const SizedBox(height: 14),
                                _buildFooterWidget(),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Fixed Footer for normal screens
            if (!isShortScreen)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildFooterWidget(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.onlineDot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Offline-First Mode Active',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.onlineBadgeText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'v1.0.0 • Role Kasir',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
