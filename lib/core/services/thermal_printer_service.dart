import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../models/cashier_session_model.dart';
import '../../models/receipt_settings_model.dart';
import '../../models/recent_transaction_model.dart';
import '../database/local_database_service.dart';
import '../utils/currency_formatter.dart';
import 'auth_service.dart';
import 'posan_api_service.dart';

class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();

  /// Decode base64 or raw image into an img.Image optimized for thermal raster printing
  img.Image? _decodeLogoImage(String? logoData, {bool is80mm = false}) {
    if (logoData == null || logoData.trim().isEmpty) return null;
    try {
      final cleanData = logoData.trim();
      Uint8List rawBytes;
      if (cleanData.startsWith('data:image')) {
        final commaIndex = cleanData.indexOf(',');
        final base64Str = commaIndex != -1 ? cleanData.substring(commaIndex + 1) : cleanData;
        rawBytes = base64Decode(base64Str);
      } else if (cleanData.startsWith('http://') || cleanData.startsWith('https://')) {
        return null;
      } else {
        rawBytes = base64Decode(cleanData);
      }

      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return null;

      // Desired width for thermal printer (176px is a multiple of 8, perfect for 58mm 384-dot head)
      final int targetWidth = is80mm ? 256 : 176;
      img.Image resized = decoded;
      if (decoded.width > targetWidth || decoded.width != targetWidth) {
        resized = img.copyResize(decoded, width: targetWidth);
      }

      // Fill transparent backgrounds with solid white
      final whiteCanvas = img.Image(width: resized.width, height: resized.height);
      img.fill(whiteCanvas, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(whiteCanvas, resized);

      // Convert to grayscale & enhance contrast for thermal dot sharpness
      final grayscale = img.grayscale(whiteCanvas);
      final contrasted = img.contrast(grayscale, contrast: 140);
      return contrasted;
    } catch (e) {
      debugPrint('ThermalPrinterService _decodeLogoImage error: $e');
      return null;
    }
  }



  // State Notifiers for UI binding
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> connectedDeviceNameNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> connectedDeviceMacNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPrintingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<List<BluetoothInfo>> availableDevicesNotifier = ValueNotifier<List<BluetoothInfo>>([]);
  final ValueNotifier<String> paperSizeNotifier = ValueNotifier<String>('58mm');
  final ValueNotifier<bool> autoPrintNotifier = ValueNotifier<bool>(true);

  bool _isInitialized = false;

  bool get isConnected => isConnectedNotifier.value;
  String? get connectedDeviceName => connectedDeviceNameNotifier.value;
  String? get connectedDeviceMac => connectedDeviceMacNotifier.value;
  String get paperSize => paperSizeNotifier.value;
  bool get autoPrint => autoPrintNotifier.value;

  /// Deteksi otomatis ukuran kertas berdasarkan nama/tipe hardware printer Bluetooth
  String detectPaperSize(String? deviceName) {
    if (deviceName == null || deviceName.trim().isEmpty) return '58mm';
    final nameLower = deviceName.toLowerCase();

    // 80mm printer models & keywords (POS-80, TM-T82, XP-80, XP-N160, MTP-III, JP-80, InnerPrinter, 3inch, etc.)
    if (nameLower.contains('80') ||
        nameLower.contains('rp80') ||
        nameLower.contains('pos-80') ||
        nameLower.contains('pos80') ||
        nameLower.contains('xp-80') ||
        nameLower.contains('xp80') ||
        nameLower.contains('xp-n160') ||
        nameLower.contains('xpn160') ||
        nameLower.contains('t80') ||
        nameLower.contains('tm-t82') ||
        nameLower.contains('tm-t88') ||
        nameLower.contains('mtp-3') ||
        nameLower.contains('mtp-iii') ||
        nameLower.contains('jp-80') ||
        nameLower.contains('innerprinter') ||
        nameLower.contains('3inch') ||
        nameLower.contains('3-inch') ||
        nameLower.contains('3 inch')) {
      return '80mm';
    }

    // Default for standard mobile Bluetooth thermal printers (MPT-II, RPP02N, POS-58, GOOJPRT, PT-210, etc.)
    return '58mm';
  }

  /// Inisialisasi service: memuat setting printer yang tersimpan di SQLite & auto-detect ukuran kertas
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final settings = await _localDb.getReceiptSettings();
      connectedDeviceMacNotifier.value = settings.printerMac;
      connectedDeviceNameNotifier.value = settings.printerName;

      // Auto-detect paper size dari hardware printer yang tersimpan
      final autoSize = (settings.printerName != null && settings.printerName!.isNotEmpty)
          ? detectPaperSize(settings.printerName)
          : (settings.paperSize.isNotEmpty ? settings.paperSize : '58mm');

      paperSizeNotifier.value = autoSize;
      autoPrintNotifier.value = settings.autoPrint;

      // Check current connection status
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final bool status = await PrintBluetoothThermal.connectionStatus;
        isConnectedNotifier.value = status;
      }
    } catch (e) {
      debugPrint('ThermalPrinterService init error: $e');
    }
  }

  /// Meminta dan memeriksa izin Bluetooth (Android 12+ scan/connect & legacy location)
  Future<bool> requestBluetoothPermissions() async {
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        final Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetooth,
          Permission.location,
        ].request();

        final connectStatus = statuses[Permission.bluetoothConnect];
        final scanStatus = statuses[Permission.bluetoothScan];
        final isGranted = (connectStatus?.isGranted ?? false) ||
            (scanStatus?.isGranted ?? false) ||
            (statuses[Permission.bluetooth]?.isGranted ?? false) ||
            (statuses[Permission.location]?.isGranted ?? false);

        debugPrint('Bluetooth permissions result: connect=$connectStatus, scan=$scanStatus, isGranted=$isGranted');

        try {
          final pluginGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
          debugPrint('PrintBluetoothThermal.isPermissionBluetoothGranted: $pluginGranted');
          return isGranted || pluginGranted;
        } catch (_) {}

        return isGranted;
      } else if (Platform.isIOS) {
        final status = await Permission.bluetooth.request();
        return status.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting Bluetooth permissions: $e');
      return false;
    }
  }

  /// Cek apakah Bluetooth pada perangkat sudah aktif (ON)
  Future<bool> isBluetoothEnabled() async {
    if (kIsWeb) return false;
    try {
      final bool enabled = await PrintBluetoothThermal.bluetoothEnabled;
      return enabled;
    } catch (e) {
      debugPrint('Error checking bluetooth enabled: $e');
      return true; // Fallback to true so UI does not get unnecessarily blocked
    }
  }

  /// Memindai perangkat printer Bluetooth yang telah dipasangkan (paired)
  Future<List<BluetoothInfo>> scanDevices() async {
    if (kIsWeb) return [];
    isScanningNotifier.value = true;

    try {
      // 1. Request permissions explicitly
      await requestBluetoothPermissions();

      // 2. Query paired bluetooth list
      final List<BluetoothInfo> list = await PrintBluetoothThermal.pairedBluetooths;
      debugPrint('Found ${list.length} paired Bluetooth devices: ${list.map((d) => "${d.name} (${d.macAdress})").toList()}');
      
      availableDevicesNotifier.value = list;
      isScanningNotifier.value = false;
      return list;
    } catch (e) {
      debugPrint('Error scanning Bluetooth devices: $e');
      isScanningNotifier.value = false;
      return [];
    }
  }

  /// Hubungkan ke Printer Thermal berdasarkan MAC Address
  Future<bool> connect(String macAddress, {String? deviceName}) async {
    if (kIsWeb) return false;

    try {
      await requestBluetoothPermissions();
      final isEnabled = await isBluetoothEnabled();
      if (!isEnabled) {
        debugPrint('Bluetooth must be enabled to connect.');
        return false;
      }

      // If already connected, disconnect first
      if (isConnectedNotifier.value) {
        await PrintBluetoothThermal.disconnect;
      }

      final bool result = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      );

      if (result) {
        isConnectedNotifier.value = true;
        connectedDeviceMacNotifier.value = macAddress;
        final finalDeviceName = deviceName ?? 'Thermal Printer';
        connectedDeviceNameNotifier.value = finalDeviceName;

        // Otomatis deteksi ukuran kertas dari nama model printer
        final autoSize = detectPaperSize(finalDeviceName);
        paperSizeNotifier.value = autoSize;

        // Simpan printer terpilih & ukuran kertas otomatis ke database SQLite
        final currentSettings = await _localDb.getReceiptSettings();
        final updated = currentSettings.copyWith(
          printerMac: macAddress,
          printerName: finalDeviceName,
          paperSize: autoSize,
        );
        await _localDb.saveReceiptSettings(updated);
        debugPrint('Connected to Thermal Printer: $finalDeviceName ($macAddress) -> Auto Paper Size: $autoSize');
      } else {
        isConnectedNotifier.value = false;
        debugPrint('Failed to connect to printer: $macAddress');
      }

      return result;
    } catch (e) {
      debugPrint('Error connecting to thermal printer: $e');
      isConnectedNotifier.value = false;
      return false;
    }
  }

  /// Putuskan koneksi Bluetooth printer
  Future<bool> disconnect() async {
    if (kIsWeb) return false;
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      isConnectedNotifier.value = false;
      return result;
    } catch (e) {
      debugPrint('Error disconnecting printer: $e');
      isConnectedNotifier.value = false;
      return false;
    }
  }

  /// Cek status koneksi printer secara berkala
  Future<bool> checkConnectionStatus() async {
    if (kIsWeb) return false;
    try {
      final bool status = await PrintBluetoothThermal.connectionStatus;
      isConnectedNotifier.value = status;
      return status;
    } catch (e) {
      debugPrint('Error checking connection status: $e');
      return false;
    }
  }

  /// Update preferensi ukuran kertas ('58mm' atau '80mm')
  Future<void> setPaperSize(String size) async {
    paperSizeNotifier.value = size;
    final current = await _localDb.getReceiptSettings();
    final updated = current.copyWith(paperSize: size);
    await _localDb.saveReceiptSettings(updated);
  }

  /// Update toggle cetak otomatis setelah transaksi berhasil
  Future<void> setAutoPrint(bool value) async {
    autoPrintNotifier.value = value;
    final current = await _localDb.getReceiptSettings();
    final updated = current.copyWith(autoPrint: value);
    await _localDb.saveReceiptSettings(updated);
  }

  // ==================== ESC/POS PRINTING GENERATORS ====================

  /// Cetak Struk Transaksi Penjualan Lengkap
  Future<bool> printReceipt({
    required RecentTransactionModel transaction,
    ReceiptSettingsModel? customSettings,
    String? cashierName,
    List<Map<String, dynamic>>? items,
    String? orderType,
  }) async {
    if (kIsWeb) return false;
    isPrintingNotifier.value = true;

    try {
      // 1. Check connection or attempt auto-reconnect to saved printer
      bool connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected && connectedDeviceMac != null && connectedDeviceMac!.isNotEmpty) {
        debugPrint('Printer disconnected, trying to auto-reconnect to $connectedDeviceMac...');
        connected = await connect(connectedDeviceMac!, deviceName: connectedDeviceName);
      }

      if (!connected) {
        debugPrint('Printer is not connected.');
        isPrintingNotifier.value = false;
        return false;
      }

      // 2. Load latest settings (fetch from backend when online, fallback to SQLite)
      final user = AuthService().currentUser;
      final mId = user?.merchantId;
      ReceiptSettingsModel settings;
      if (customSettings != null) {
        settings = customSettings;
      } else {
        ReceiptSettingsModel? onlineSettings;
        try {
          final onlineData = await PosanApiService().getReceiptSettings();
          if (onlineData != null) {
            onlineSettings = ReceiptSettingsModel.fromJson(onlineData);
            await _localDb.saveReceiptSettings(onlineSettings);
          }
        } catch (_) {}
        settings = onlineSettings ?? await _localDb.getReceiptSettings(merchantId: mId);
      }

      final is80mm = settings.paperSize == '80mm';
      final PaperSize size = is80mm ? PaperSize.mm80 : PaperSize.mm58;

      final profile = await CapabilityProfile.load();
      final generator = Generator(size, profile);
      List<int> bytes = [];

      // Reset printer
      bytes += generator.reset();

      // 1. Cafe Logo (if enabled and present)
      if (settings.showLogo && settings.logoUrl != null && settings.logoUrl!.isNotEmpty) {
        final logoImg = _decodeLogoImage(settings.logoUrl, is80mm: is80mm);
        if (logoImg != null) {
          try {
            bytes += generator.imageRaster(logoImg, align: PosAlign.center);
            bytes += generator.feed(1);
          } catch (e) {
            debugPrint('Error printing logo raster: $e');
          }
        }
      }

      // 2. Subtitle / Slogan (if present)
      if (settings.headerSubtitle.trim().isNotEmpty) {
        bytes += generator.text(
          settings.headerSubtitle.trim(),
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
          ),
        );
      }

      // 3. Address (if present)
      if (settings.storeAddress.trim().isNotEmpty) {
        bytes += generator.text(
          settings.storeAddress.trim(),
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      // Dashed Line Divider
      bytes += generator.hr(ch: '-');

      // Transaction Metadata: No. Struk, Waktu, Kasir, No. HP
      final receiptNo = transaction.id.startsWith('#') ? transaction.id : '#${transaction.id}';
      bytes += generator.row([
        PosColumn(text: 'No. Struk :', width: 4),
        PosColumn(
          text: receiptNo,
          width: 8,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      if (settings.showDateTime) {
        bytes += generator.row([
          PosColumn(text: 'Waktu :', width: 4),
          PosColumn(
            text: transaction.time,
            width: 8,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      if (settings.showCashierName) {
        final activeCashier = cashierName ?? transaction.cashierName ?? user?.name ?? AuthService().currentSession.cashierName;
        final resolvedCashier = (activeCashier.isNotEmpty) ? activeCashier : 'Kasir Utama';
        bytes += generator.row([
          PosColumn(text: 'Kasir :', width: 4),
          PosColumn(
            text: resolvedCashier,
            width: 8,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      if (settings.storePhone.trim().isNotEmpty) {
        bytes += generator.row([
          PosColumn(text: 'No. HP :', width: 4),
          PosColumn(
            text: settings.storePhone.trim(),
            width: 8,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      // Order Type Banner (DINE-IN / TAKEAWAY) with Dashed borders
      if (settings.showOrderType) {
        bytes += generator.hr(ch: '-');
        final rawOrderType = (orderType != null && orderType.isNotEmpty)
            ? orderType.toUpperCase()
            : (transaction.orderType?.toUpperCase() ?? 'DINE-IN');
        final displayOrderType = rawOrderType == 'DINE-IN' ? 'D I N E - I N' : (rawOrderType == 'TAKEAWAY' ? 'T A K E A W A Y' : rawOrderType);
        bytes += generator.text(
          displayOrderType,
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
          ),
        );
      }

      bytes += generator.hr(ch: '-');

      // Resolve actual items from parameter or SQLite transaction_items table
      List<Map<String, dynamic>> resolvedItems = items ?? [];
      if (resolvedItems.isEmpty) {
        try {
          final dbItems = await _localDb.getTransactionItems(transaction.id);
          if (dbItems.isNotEmpty) {
            resolvedItems = dbItems.map((it) {
              final q = (it['quantity'] as num?)?.toInt() ?? 1;
              final price = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
              final sub = (it['subtotal'] as num?)?.toDouble() ?? (q * price);
              return {
                'name': (it['product_name'] ?? it['name'] ?? 'Menu').toString(),
                'qty': q,
                'unit_price': price > 0 ? price : (sub / (q > 0 ? q : 1)),
                'subtotal': sub,
                'notes': it['notes'] ?? it['options'] ?? it['variant'] ?? '',
              };
            }).toList();
          }
        } catch (_) {}
      }

      if (resolvedItems.isEmpty) {
        resolvedItems = _parseItemSummary(transaction.itemSummary, transaction.totalAmount);
      }

      for (int i = 0; i < resolvedItems.length; i++) {
        final item = resolvedItems[i];
        final String name = (item['name'] ?? item['product_name'] ?? 'Item').toString();
        final int qty = (item['qty'] ?? item['quantity'] as num?)?.toInt() ?? 1;
        final double subtotal = (item['subtotal'] as num?)?.toDouble() ?? 0.0;
        final double unitPrice = (item['unit_price'] != null && (item['unit_price'] as num) > 0)
            ? (item['unit_price'] as num).toDouble()
            : (subtotal / (qty > 0 ? qty : 1));
        final String notes = (item['notes'] ?? item['options'] ?? item['variant'] ?? '').toString().trim();

        // 1. Item Name (Bold)
        bytes += generator.text(
          name,
          styles: const PosStyles(bold: true),
        );

        // 2. Item Options / Notes (e.g. Cold, Dine in)
        if (notes.isNotEmpty) {
          bytes += generator.text(
            notes,
            styles: const PosStyles(align: PosAlign.left),
          );
        }

        // 3. Qty x Price and Subtotal
        final leftText = '${CurrencyFormatter.format(unitPrice).replaceAll('Rp', '').trim()} x$qty';
        final rightText = CurrencyFormatter.format(subtotal > 0 ? subtotal : (qty * unitPrice)).replaceAll('Rp', '').trim();

        bytes += generator.row([
          PosColumn(text: leftText, width: 6),
          PosColumn(
            text: rightText,
            width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]);

        if (i < resolvedItems.length - 1) {
          bytes += generator.feed(1);
        }
      }

      bytes += generator.hr(ch: '-');

      // Totals & Payment Summary
      bytes += generator.row([
        PosColumn(
          text: 'Total',
          width: 5,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: 'Rp ${CurrencyFormatter.format(transaction.totalAmount).replaceAll('Rp', '').trim()}',
          width: 7,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      // Payment method row
      bytes += generator.row([
        PosColumn(
          text: transaction.paymentMethod.label.toUpperCase(),
          width: 5,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: 'Rp ${CurrencyFormatter.format(transaction.totalAmount).replaceAll('Rp', '').trim()}',
          width: 7,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      // Cash breakdown (Tunai Diterima & Kembalian)
      if (transaction.paymentMethod == TransactionPaymentMethod.cash && transaction.amountPaid > 0) {
        bytes += generator.row([
          PosColumn(text: 'Tunai Diterima', width: 6),
          PosColumn(
            text: 'Rp ${CurrencyFormatter.format(transaction.amountPaid).replaceAll('Rp', '').trim()}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
        bytes += generator.row([
          PosColumn(text: 'Kembalian', width: 6, styles: const PosStyles(bold: true)),
          PosColumn(
            text: 'Rp ${CurrencyFormatter.format(transaction.changeAmount).replaceAll('Rp', '').trim()}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]);
      }

      bytes += generator.hr(ch: '-');

      // Footer: Bank Info (multi-line)
      if (settings.bankInfo.isNotEmpty) {
        final lines = settings.bankInfo.split('\n');
        for (final l in lines) {
          if (l.trim().isNotEmpty) {
            bytes += generator.text(
              l.trim(),
              styles: const PosStyles(align: PosAlign.center),
            );
          }
        }
      }

      // Footer: Thank you message
      if (settings.thankYouMessage.isNotEmpty) {
        bytes += generator.feed(1);
        bytes += generator.text(
          settings.thankYouMessage,
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
          ),
        );
      }

      // Footer Note (Brand)
      if (settings.footerNote.isNotEmpty) {
        bytes += generator.feed(1);
        bytes += generator.text(
          settings.footerNote.toUpperCase(),
          styles: const PosStyles(
            align: PosAlign.center,
          ),
        );
      }

      // Feed lines & Cut paper
      bytes += generator.feed(3);
      bytes += generator.cut();

      // Write bytes to Bluetooth Thermal Printer
      final bool printResult = await PrintBluetoothThermal.writeBytes(bytes);
      isPrintingNotifier.value = false;
      return printResult;
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      isPrintingNotifier.value = false;
      return false;
    }
  }

  /// Tes Cetak Struk Printer Bluetooth
  Future<bool> printTestReceipt() async {
    if (kIsWeb) return false;
    isPrintingNotifier.value = true;

    try {
      bool connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected && connectedDeviceMac != null && connectedDeviceMac!.isNotEmpty) {
        connected = await connect(connectedDeviceMac!, deviceName: connectedDeviceName);
      }

      if (!connected) {
        isPrintingNotifier.value = false;
        return false;
      }

      final settings = await _localDb.getReceiptSettings();
      final is80mm = settings.paperSize == '80mm';
      final PaperSize size = is80mm ? PaperSize.mm80 : PaperSize.mm58;

      final profile = await CapabilityProfile.load();
      final generator = Generator(size, profile);
      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.text(
        'POSAN TEST PRINT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        'Thermal Printer OK',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.hr(ch: '=');

      bytes += generator.text('Printer: ${connectedDeviceName ?? "Bluetooth Thermal"}');
      bytes += generator.text('MAC: ${connectedDeviceMac ?? "-"}');
      bytes += generator.text('Paper Size: ${settings.paperSize}');
      bytes += generator.text('Waktu: ${DateTime.now().toLocal().toString().substring(0, 19)}');
      bytes += generator.hr(ch: '-');

      bytes += generator.text(
        'Sistem kasir siap mencetak transaksi penjualan.',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(1);
      bytes += generator.text(
        '*** BERHASIL TERHUBUNG ***',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      bytes += generator.feed(3);
      bytes += generator.cut();

      final bool printResult = await PrintBluetoothThermal.writeBytes(bytes);
      isPrintingNotifier.value = false;
      return printResult;
    } catch (e) {
      debugPrint('Error printing test receipt: $e');
      isPrintingNotifier.value = false;
      return false;
    }
  }

  /// Cetak Laporan Tutup Shift / Rekonsiliasi Kas Kasir
  Future<bool> printShiftReport({
    required CashierSessionModel session,
    required double totalCashSales,
    required List<RecentTransactionModel> transactions,
    double? initialCashAmount,
    double? physicalCash,
    double? difference,
    String? notes,
  }) async {
    if (kIsWeb) return false;
    isPrintingNotifier.value = true;

    try {
      bool connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected && connectedDeviceMac != null && connectedDeviceMac!.isNotEmpty) {
        connected = await connect(connectedDeviceMac!, deviceName: connectedDeviceName);
      }

      if (!connected) {
        isPrintingNotifier.value = false;
        return false;
      }

      final settings = await _localDb.getReceiptSettings();
      final is80mm = settings.paperSize == '80mm';
      final PaperSize size = is80mm ? PaperSize.mm80 : PaperSize.mm58;

      final profile = await CapabilityProfile.load();
      final generator = Generator(size, profile);
      List<int> bytes = [];

      final double totalSales = transactions.fold<double>(0, (sum, t) => sum + t.totalAmount);
      final double totalQris = transactions
          .where((t) => t.paymentMethod == TransactionPaymentMethod.qris)
          .fold<double>(0, (sum, t) => sum + t.totalAmount);
      final double totalBank = transactions
          .where((t) => t.paymentMethod == TransactionPaymentMethod.bank)
          .fold<double>(0, (sum, t) => sum + t.totalAmount);

      final double initialCash = initialCashAmount ?? session.initialCash;
      final double expectedCash = initialCash + totalCashSales;

      bytes += generator.reset();
      bytes += generator.text(
        settings.storeName,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
      );
      bytes += generator.text(
        'LAPORAN TUTUP SHIFT KASIR',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.hr(ch: '=');

      bytes += generator.row([
        PosColumn(text: 'Kasir', width: 4),
        PosColumn(text: session.cashierName, width: 8, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Shift', width: 4),
        PosColumn(text: '${session.shift} (${session.shiftNumber})', width: 8, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Waktu Cetak', width: 4),
        PosColumn(text: DateTime.now().toLocal().toString().substring(0, 16), width: 8, styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.hr(ch: '-');
      bytes += generator.text('RINGKASAN PENJUALAN', styles: const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(text: 'Total Transaksi', width: 6),
        PosColumn(text: '${transactions.length} trx', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Penjualan Tunai', width: 6),
        PosColumn(text: CurrencyFormatter.format(totalCashSales), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Penjualan QRIS', width: 6),
        PosColumn(text: CurrencyFormatter.format(totalQris), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Penjualan Transfer', width: 6),
        PosColumn(text: CurrencyFormatter.format(totalBank), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.hr(ch: '-');
      bytes += generator.row([
        PosColumn(text: 'TOTAL OMSET', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: CurrencyFormatter.format(totalSales), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);

      bytes += generator.hr(ch: '-');
      bytes += generator.text('REKONSILIASI KAS LACI', styles: const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(text: 'Modal Awal Kas', width: 6),
        PosColumn(text: CurrencyFormatter.format(initialCash), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Kas Masuk Penjualan', width: 6),
        PosColumn(text: CurrencyFormatter.format(totalCashSales), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Total Kas Seharusnya', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: CurrencyFormatter.format(expectedCash), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);

      if (physicalCash != null) {
        bytes += generator.row([
          PosColumn(text: 'Uang Fisik di Laci', width: 6),
          PosColumn(text: CurrencyFormatter.format(physicalCash), width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
        final diffVal = difference ?? (physicalCash - expectedCash);
        final isMatch = diffVal == 0;
        final diffStr = isMatch
            ? 'Rp0 (Imbang)'
            : (diffVal > 0 ? '+${CurrencyFormatter.format(diffVal)} (Lebih)' : '${CurrencyFormatter.format(diffVal)} (Kurang)');
        bytes += generator.row([
          PosColumn(text: 'Selisih Kas', width: 6, styles: const PosStyles(bold: true)),
          PosColumn(text: diffStr, width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
      }

      if (notes != null && notes.trim().isNotEmpty) {
        bytes += generator.hr(ch: '-');
        bytes += generator.text('Catatan: ${notes.trim()}', styles: const PosStyles(fontType: PosFontType.fontB));
      }

      bytes += generator.feed(2);
      bytes += generator.text('Tanda Tangan Kasir:', styles: const PosStyles(align: PosAlign.left));
      bytes += generator.feed(3);
      bytes += generator.text('( ${session.cashierName} )', styles: const PosStyles(align: PosAlign.left));

      bytes += generator.feed(3);
      bytes += generator.cut();

      final bool printResult = await PrintBluetoothThermal.writeBytes(bytes);
      isPrintingNotifier.value = false;
      return printResult;
    } catch (e) {
      debugPrint('Error printing shift report: $e');
      isPrintingNotifier.value = false;
      return false;
    }
  }

  /// Helper untuk mem-parse ringkasan item menjadi list item berkuantitas
  List<Map<String, dynamic>> _parseItemSummary(String summary, double totalAmount) {
    if (summary.isEmpty) {
      return [
        {'name': 'Pesanan Kasir', 'qty': 1, 'subtotal': totalAmount}
      ];
    }

    final parts = summary.split(',');
    final list = <Map<String, dynamic>>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      final match = RegExp(r'^(\d+)x?\s*(.*)$').firstMatch(trimmed);
      if (match != null) {
        final qty = int.tryParse(match.group(1) ?? '1') ?? 1;
        final name = match.group(2) ?? trimmed;
        final estSubtotal = totalAmount / (parts.isNotEmpty ? parts.length : 1);
        list.add({
          'name': name.isEmpty ? trimmed : name,
          'qty': qty,
          'subtotal': estSubtotal,
        });
      } else {
        final estSubtotal = totalAmount / (parts.isNotEmpty ? parts.length : 1);
        list.add({
          'name': trimmed,
          'qty': 1,
          'subtotal': estSubtotal,
        });
      }
    }

    return list.isNotEmpty
        ? list
        : [
            {'name': 'Pesanan Kasir', 'qty': 1, 'subtotal': totalAmount}
          ];
  }
}
