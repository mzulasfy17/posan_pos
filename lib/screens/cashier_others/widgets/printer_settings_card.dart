import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/theme/app_colors.dart';

class PrinterSettingsCard extends StatefulWidget {
  const PrinterSettingsCard({super.key});

  @override
  State<PrinterSettingsCard> createState() => _PrinterSettingsCardState();
}

class _PrinterSettingsCardState extends State<PrinterSettingsCard> {
  final ThermalPrinterService _printerService = ThermalPrinterService();

  @override
  void initState() {
    super.initState();
    _printerService.init();
    _printerService.checkConnectionStatus();
  }

  void _handleTestPrint() async {
    final isConnected = _printerService.isConnected;
    if (!isConnected && (_printerService.connectedDeviceMac == null || _printerService.connectedDeviceMac!.isEmpty)) {
      _showScanPrinterDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Hubungkan printer Bluetooth terlebih dahulu.'),
              ),
            ],
          ),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 10),
            Expanded(child: Text('Mengirim perintah cetak tes ke printer...')),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 1500),
      ),
    );

    final success = await _printerService.printTestReceipt();
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tes cetak struk berhasil dikirim ke ${_printerService.connectedDeviceName ?? "Printer"} (${_printerService.paperSize}).',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gagal mencetak struk tes. Pastikan printer Bluetooth menyala dan terhubung.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showScanPrinterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BluetoothScanModal(printerService: _printerService),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _printerService.isConnectedNotifier,
        _printerService.connectedDeviceNameNotifier,
        _printerService.connectedDeviceMacNotifier,
        _printerService.paperSizeNotifier,
        _printerService.autoPrintNotifier,
        _printerService.isPrintingNotifier,
      ]),
      builder: (context, _) {
        final isConnected = _printerService.isConnected;
        final printerName = _printerService.connectedDeviceName ?? 'Belum Terpilih';
        final paperSize = _printerService.paperSize;
        final autoPrint = _printerService.autoPrint;
        final isPrinting = _printerService.isPrintingNotifier.value;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.chipInactiveBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.print_rounded,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Printer Struk & Hardware',
                            style: TextStyle(
                              fontSize: 14.5,
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
                  // Pill: • Terhubung / Terputus
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? AppColors.onlineBadgeBg
                          : AppColors.shiftBadgeBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isConnected
                                ? AppColors.onlineDot
                                : Colors.red[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isConnected ? 'Terhubung' : 'Terputus',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isConnected
                                ? AppColors.onlineBadgeText
                                : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Connected Device Name Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isConnected
                        ? const Color(0xFFC4713B).withValues(alpha: 0.25)
                        : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
                            size: 22,
                            color: isConnected ? const Color(0xFFBA6A34) : AppColors.textPrimary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  printerName,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _printerService.connectedDeviceMac != null
                                      ? '${_printerService.connectedDeviceMac} • $paperSize'
                                      : 'Thermal Printer Bluetooth • $paperSize',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showScanPrinterDialog,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBA6A34).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Pindai / Ganti',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFBA6A34),
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Color(0xFFBA6A34),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Auto-detected Paper Size Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ukuran Kertas Struk',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Otomatis disesuaikan dengan tipe printer Bluetooth',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3ECE2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFD4A373).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: Color(0xFFBA6A34),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Otomatis ($paperSize)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7D4E2D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Auto print toggle Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cetak Otomatis Setelah Bayar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Langsung cetak struk tanpa perlu tekan tombol cetak',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: autoPrint,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF8A5943),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFE5E0D8),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) => _printerService.setAutoPrint(val),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Print Test Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isPrinting ? null : _handleTestPrint,
                  icon: isPrinting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.print_outlined,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                  label: Text(
                    isPrinting ? 'Mencetak Tes...' : 'Tes Cetak Struk',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(
                      color: Color(0xFF30221A),
                      width: 1.1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Modal BottomSheet untuk Memindai dan Menghubungkan Printer Bluetooth
class _BluetoothScanModal extends StatefulWidget {
  final ThermalPrinterService printerService;

  const _BluetoothScanModal({required this.printerService});

  @override
  State<_BluetoothScanModal> createState() => _BluetoothScanModalState();
}

class _BluetoothScanModalState extends State<_BluetoothScanModal> {
  List<BluetoothInfo> _devices = [];
  bool _isLoading = false;
  bool _bluetoothEnabled = true;
  String? _connectingMac;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _bluetoothEnabled = true;
    });

    // 1. Request permissions explicitly
    await widget.printerService.requestBluetoothPermissions();

    // 2. Scan paired bluetooth devices directly
    final list = await widget.printerService.scanDevices();
    final isBtOn = await widget.printerService.isBluetoothEnabled();

    if (mounted) {
      setState(() {
        _devices = list;
        _bluetoothEnabled = isBtOn || list.isNotEmpty;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleConnect(BluetoothInfo device) async {
    final mac = device.macAdress;
    setState(() {
      _connectingMac = mac;
    });

    final success = await widget.printerService.connect(mac, deviceName: device.name);
    if (!mounted) return;

    setState(() {
      _connectingMac = null;
    });

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Berhasil terhubung ke ${device.name} ($mac)'),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Gagal menghubungkan ke ${device.name}. Pastikan printer menyala.'),
              ),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentConnectedMac = widget.printerService.connectedDeviceMac;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderMedium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title and Scan CTA
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.bluetooth_searching_rounded,
                          color: Color(0xFFBA6A34),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Pindai Printer Bluetooth',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
                      onPressed: _isLoading ? null : _startScan,
                      tooltip: 'Pindai Ulang',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pastikan printer thermal dalam kondisi ON dan sudah dipasangkan (paired) di Pengaturan Bluetooth HP.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),

                // Bluetooth Off State
                if (!_bluetoothEnabled) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bluetooth_disabled_rounded, color: Colors.amber.shade900, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bluetooth Tidak Aktif',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Silakan aktifkan Bluetooth di perangkat Anda untuk menghubungkan printer.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Device List
                if (_isLoading && _devices.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: Color(0xFFBA6A34)),
                          SizedBox(height: 12),
                          Text(
                            'Mencari printer thermal Bluetooth...',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (_devices.isEmpty && _bluetoothEnabled) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.chipInactiveBg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.print_disabled_rounded,
                          size: 36,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Belum Ada Perangkat Printer',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '1. Masuk ke Pengaturan HP > Bluetooth\n2. Pasangkan (Pair) printer thermal kasir\n3. Kembali ke aplikasi dan tekan tombol Pindai Ulang',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => openAppSettings(),
                              icon: const Icon(Icons.settings_outlined, size: 15),
                              label: const Text('Izin HP', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.borderMedium),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _startScan,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Pindai Ulang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFBA6A34),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _devices.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final dev = _devices[index];
                        final isCurrentlyConnected =
                            widget.printerService.isConnected && currentConnectedMac == dev.macAdress;
                        final isConnectingThis = _connectingMac == dev.macAdress;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isCurrentlyConnected
                                ? AppColors.onlineBadgeBg
                                : AppColors.chipInactiveBg.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrentlyConnected
                                  ? AppColors.onlineBadgeText.withValues(alpha: 0.4)
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isCurrentlyConnected
                                      ? AppColors.onlineDot.withValues(alpha: 0.15)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.print_rounded,
                                  color: isCurrentlyConnected
                                      ? AppColors.onlineDot
                                      : AppColors.primaryDark,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dev.name.isNotEmpty ? dev.name : 'Unknown Bluetooth Device',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${dev.macAdress} • Auto ${widget.printerService.detectPaperSize(dev.name)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isConnectingThis)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFBA6A34),
                                  ),
                                )
                              else if (isCurrentlyConnected)
                                OutlinedButton(
                                  onPressed: () async {
                                    await widget.printerService.disconnect();
                                    setState(() {});
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red[700],
                                    side: BorderSide(color: Colors.red.shade300),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Putuskan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                )
                              else
                                ElevatedButton(
                                  onPressed: () => _handleConnect(dev),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFBA6A34),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Hubungkan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
