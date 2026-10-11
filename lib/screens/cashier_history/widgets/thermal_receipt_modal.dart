import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/posan_api_service.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/receipt_settings_model.dart';
import '../../../models/recent_transaction_model.dart';

class ThermalReceiptModal extends StatefulWidget {
  final RecentTransactionModel transaction;
  final VoidCallback? onPrint;
  final List<Map<String, dynamic>>? items;
  final String? cashierName;
  final String? orderType;

  const ThermalReceiptModal({
    super.key,
    required this.transaction,
    this.onPrint,
    this.items,
    this.cashierName,
    this.orderType,
  });

  static Future<void> show(
    BuildContext context, {
    required RecentTransactionModel transaction,
    VoidCallback? onPrint,
    List<Map<String, dynamic>>? items,
    String? cashierName,
    String? orderType,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ThermalReceiptModal(
        transaction: transaction,
        onPrint: onPrint,
        items: items,
        cashierName: cashierName,
        orderType: orderType,
      ),
    );
  }

  @override
  State<ThermalReceiptModal> createState() => _ThermalReceiptModalState();
}

class _ThermalReceiptModalState extends State<ThermalReceiptModal> {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final PosanApiService _api = PosanApiService();

  ReceiptSettingsModel _settings = const ReceiptSettingsModel();
  List<Map<String, dynamic>> _resolvedItems = [];

  @override
  void initState() {
    super.initState();
    _loadSettingsAndItems();
  }

  Future<void> _loadSettingsAndItems() async {
    // 1. Load items
    if (widget.items != null && widget.items!.isNotEmpty) {
      _resolvedItems = widget.items!;
    } else {
      try {
        final dbItems = await _localDb.getTransactionItems(widget.transaction.id);
        if (dbItems.isNotEmpty) {
          _resolvedItems = dbItems.map((it) {
            final q = (it['quantity'] as num?)?.toInt() ?? 1;
            final price = (it['unit_price'] as num?)?.toDouble() ?? 0.0;
            final sub = (it['subtotal'] as num?)?.toDouble() ?? (q * price);
            return {
              'name': (it['product_name'] ?? it['name'] ?? 'Menu').toString(),
              'qty': q,
              'unit_price': price > 0 ? price : (sub / (q > 0 ? q : 1)),
              'subtotal': sub,
            };
          }).toList();
        }
      } catch (_) {}
    }

    // 2. Load from local database first
    final user = AuthService().currentUser;
    final mId = user?.merchantId;
    final local = await _localDb.getReceiptSettings(merchantId: mId);
    if (mounted) {
      setState(() {
        _settings = local;
      });
    }

    // 3. Fetch fresh online settings from PostgreSQL
    try {
      final onlineData = await _api.getReceiptSettings();
      if (onlineData != null) {
        final onlineSettings = ReceiptSettingsModel.fromJson(onlineData);
        await _localDb.saveReceiptSettings(onlineSettings);
        if (mounted) {
          setState(() {
            _settings = onlineSettings;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _handlePrintNow() async {
    Navigator.pop(context);
    if (widget.onPrint != null) {
      widget.onPrint!();
      return;
    }

    final printer = ThermalPrinterService();
    final isConnected = printer.isConnected;
    if (!isConnected && (printer.connectedDeviceMac == null || printer.connectedDeviceMac!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Printer Bluetooth belum terhubung. Atur di menu Pengaturan & Lainnya.'),
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
            Expanded(child: Text('Mencetak struk ke printer Bluetooth...')),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 1500),
      ),
    );

    final resolvedCashier = widget.cashierName ?? AuthService().currentUser?.name ?? AuthService().currentSession.cashierName;

    final success = await printer.printReceipt(
      transaction: widget.transaction,
      customSettings: _settings,
      cashierName: resolvedCashier,
      items: _resolvedItems.isNotEmpty ? _resolvedItems : null,
      orderType: widget.orderType,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Struk ${widget.transaction.id} berhasil dicetak ke ${printer.connectedDeviceName ?? "Printer"}.'),
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
                  child: Text('Gagal mencetak struk. Pastikan printer Bluetooth menyala dan dalam jangkauan.'),
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
  }

  List<Map<String, dynamic>> get _parsedItems {
    if (_resolvedItems.isNotEmpty) {
      return _resolvedItems;
    }

    final raw = widget.transaction.itemSummary;
    if (raw.isEmpty) return [];

    final parts = raw.split(',');
    return parts.map((part) {
      final trimmed = part.trim();
      final match = RegExp(r'^(\d+)x?\s*(.*)$').firstMatch(trimmed);
      if (match != null) {
        final qty = int.tryParse(match.group(1) ?? '1') ?? 1;
        final name = match.group(2) ?? trimmed;
        return {
          'name': name.isEmpty ? trimmed : name,
          'qty': qty,
          'unit_price': (widget.transaction.totalAmount / (parts.isNotEmpty ? parts.length : 1)) / (qty > 0 ? qty : 1),
          'subtotal': widget.transaction.totalAmount / (parts.isNotEmpty ? parts.length : 1),
        };
      }
      return {
        'name': trimmed,
        'qty': 1,
        'unit_price': widget.transaction.totalAmount / (parts.isNotEmpty ? parts.length : 1),
        'subtotal': widget.transaction.totalAmount / (parts.isNotEmpty ? parts.length : 1),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final items = _parsedItems;
    final isCash = t.paymentMethod == TransactionPaymentMethod.cash;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1712),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: Color(0xFFBA6A34), size: 18),
                          const SizedBox(width: 8),
                          const Text(
                            'Pratinjau Struk Cetak',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1E17),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF43281C)),
                        ),
                        child: Text(
                          _settings.paperSize,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Color(0xFFD4A373),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Realistic Thermal Paper Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFE),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cafe Logo at top
                        if (_settings.showLogo) ...[
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F6F0),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.black, width: 1.5),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildLogoWidget(),
                            ),
                          ),
                        ],

                        if (_settings.headerSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _settings.headerSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                        if (_settings.storeAddress.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _settings.storeAddress,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),

                        // Receipt Metadata: No. Struk, Waktu, Kasir, No. HP
                        _buildDashedLine(),
                        const SizedBox(height: 6),
                        _buildMonoRow('No. Struk :', t.id.startsWith('#') ? t.id : '#${t.id}'),
                        if (_settings.showDateTime)
                          _buildMonoRow('Waktu :', t.time),
                        if (_settings.showCashierName)
                          _buildMonoRow(
                            'Kasir :',
                            widget.cashierName ?? AuthService().currentUser?.name ?? AuthService().currentSession.cashierName,
                          ),
                        if (_settings.storePhone.isNotEmpty)
                          _buildMonoRow('No. HP :', _settings.storePhone),
                        const SizedBox(height: 6),

                        // Order Type Banner (DINE-IN)
                        if (_settings.showOrderType) ...[
                          _buildDashedLine(),
                          const SizedBox(height: 5),
                          Text(
                            (widget.orderType != null && widget.orderType!.isNotEmpty)
                                ? widget.orderType!.toUpperCase()
                                : 'DINE-IN',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 5),
                        ],

                        _buildDashedLine(),
                        const SizedBox(height: 8),

                        // Item rows
                        if (items.isNotEmpty)
                          ...items.map((it) {
                            final name = (it['name'] ?? it['product_name'] ?? 'Item').toString();
                            final qty = (it['qty'] ?? it['quantity'] as num?)?.toInt() ?? 1;
                            final subtotal = (it['subtotal'] as num?)?.toDouble() ?? 0.0;
                            final unitPrice = (it['unit_price'] != null && (it['unit_price'] as num) > 0)
                                ? (it['unit_price'] as num).toDouble()
                                : (subtotal / (qty > 0 ? qty : 1));
                            final options = (it['notes'] ?? it['options'] ?? it['variant'] ?? '').toString().trim();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                                  if (options.isNotEmpty) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      options,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                        color: Color(0xFF555555),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${CurrencyFormatter.format(unitPrice).replaceAll('Rp', '').trim()} x$qty',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          color: Color(0xFF444444),
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(subtotal > 0 ? subtotal : (qty * unitPrice)).replaceAll('Rp', '').trim(),
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          })
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Item Pesanan', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
                                Text(CurrencyFormatter.format(t.totalAmount), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),

                        const SizedBox(height: 4),
                        _buildDashedLine(),
                        const SizedBox(height: 6),

                        // Total & Payment Breakdown
                        _buildMonoRow(
                          'Total',
                          CurrencyFormatter.format(t.totalAmount),
                          isBold: true,
                          fontSize: 13,
                        ),
                        const SizedBox(height: 4),
                        _buildMonoRow(
                          t.paymentMethod.label.toUpperCase(),
                          CurrencyFormatter.format(t.totalAmount),
                          isBold: true,
                          fontSize: 12,
                        ),

                        if (isCash && t.amountPaid > 0) ...[
                          const SizedBox(height: 4),
                          _buildMonoRow('Uang Diterima', CurrencyFormatter.format(t.amountPaid)),
                          const SizedBox(height: 4),
                          _buildMonoRow('Kembalian', CurrencyFormatter.format(t.changeAmount), isBold: true),
                        ],

                        const SizedBox(height: 8),
                        _buildDashedLine(),
                        const SizedBox(height: 10),

                        // Footer Section: Bank Info
                        if (_settings.bankInfo.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              _settings.bankInfo,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF222222),
                                height: 1.35,
                              ),
                            ),
                          ),

                        // Thank you note
                        if (_settings.thankYouMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Text(
                              _settings.thankYouMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ),

                        // Powered by footer
                        if (_settings.footerNote.isNotEmpty)
                          Text(
                            _settings.footerNote.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9.5,
                              color: Color(0xFF777777),
                              letterSpacing: 0.6,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _handlePrintNow,
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: const Text('Cetak Sekarang', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBA6A34),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashedLine() {
    return const Text(
      '----------------------------------------',
      maxLines: 1,
      overflow: TextOverflow.clip,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        color: Color(0xFF777777),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildMonoRow(
    String left,
    String right, {
    bool isBold = false,
    double fontSize = 11,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          left,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w500,
            color: Colors.black,
          ),
        ),
        Text(
          right,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoWidget() {
    final logo = (_settings.logoUrl ?? '').trim();
    if (logo.isNotEmpty) {
      try {
        if (logo.startsWith('data:image')) {
          final commaIndex = logo.indexOf(',');
          final base64Str = commaIndex != -1 ? logo.substring(commaIndex + 1) : logo;
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.coffee_rounded, size: 22, color: Colors.black),
          );
        } else if (logo.startsWith('http://') || logo.startsWith('https://')) {
          return Image.network(
            logo,
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.coffee_rounded, size: 22, color: Colors.black),
          );
        }
      } catch (_) {}
    }
    return const Icon(
      Icons.coffee_rounded,
      size: 22,
      color: Colors.black,
    );
  }
}

