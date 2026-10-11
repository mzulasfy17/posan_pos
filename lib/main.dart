import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/auth_service.dart';
import 'core/services/offline_sync_manager.dart';
import 'core/services/screen_wakelock_service.dart';
import 'core/services/thermal_printer_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/auto_dim_wrapper.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi format tanggal bahasa Indonesia
  await initializeDateFormatting('id_ID', null);

  // Pulihkan sesi login kasir jika ada sesi yang tersimpan sebelumnya
  await AuthService().restoreSession();

  // Inisialisasi Database SQLite Lokal & 2-Menit Idle Auto-Sync Manager
  await OfflineSyncManager().initialize();

  // Inisialisasi Layar Tetap Aktif & Printer Thermal Service (non-blocking)
  ScreenWakelockService().init();
  ThermalPrinterService().init();

  // Set system UI overlay style for seamless status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const PosanApp());
}

class PosanApp extends StatelessWidget {
  const PosanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POSAN - Point of Sales',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        return AutoDimWrapper(child: child ?? const SizedBox.shrink());
      },
      home: const SplashScreen(),
    );
  }
}
