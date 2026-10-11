import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/utils/transaction_code_generator.dart';
import '../../models/cart_order_model.dart';
import '../../models/recent_transaction_model.dart';
import 'widgets/quick_cash_chips.dart';
import 'widgets/cash_calculation_card.dart';
import 'widgets/cash_numpad.dart';
import 'widgets/payment_success_dialog.dart';
import '../cashier_history/widgets/thermal_receipt_modal.dart';

class CashPaymentScreen extends StatefulWidget {
  final double totalAmount;
  final List<CartItemModel> cartItems;
  final OrderInfoModel orderInfo;

  const CashPaymentScreen({
    super.key,
    required this.totalAmount,
    required this.cartItems,
    required this.orderInfo,
  });

  @override
  State<CashPaymentScreen> createState() => _CashPaymentScreenState();
}

class _CashPaymentScreenState extends State<CashPaymentScreen> {
  String _inputAmountStr = '';

  @override
  void initState() {
    super.initState();
    // Default to exact amount (Uang Pas)
    _inputAmountStr = widget.totalAmount.toInt().toString();
  }

  double get _receivedAmount => double.tryParse(_inputAmountStr) ?? 0.0;

  bool get _isSufficient => _receivedAmount >= widget.totalAmount;

  double get _changeAmount => _receivedAmount - widget.totalAmount;

  void _handleNumpadKey(String key) {
    setState(() {
      if (_inputAmountStr == '0' || _inputAmountStr.isEmpty) {
        if (key == '000') return;
        _inputAmountStr = key;
      } else {
        if (_inputAmountStr.length < 9) {
          _inputAmountStr += key;
        }
      }
    });
  }

  void _handleDelete() {
    setState(() {
      if (_inputAmountStr.isNotEmpty) {
        _inputAmountStr =
            _inputAmountStr.substring(0, _inputAmountStr.length - 1);
      }
    });
  }

  void _handleClear() {
    setState(() {
      _inputAmountStr = '';
    });
  }

  void _handleSelectQuickAmount(double amount) {
    setState(() {
      _inputAmountStr = amount.toInt().toString();
    });
  }

  void _confirmPayment() async {
    if (!_isSufficient) return;

    final now = DateTime.now();
    final timeFormatted = '${DateFormat('HH:mm').format(now)} WIB';
    final trxId = TransactionCodeGenerator.generate(dateTime: now);

    final summary = widget.cartItems
        .map((e) => '${e.quantity} ${e.product.name}')
        .join(', ');

    final newTransaction = RecentTransactionModel(
      id: trxId,
      paymentMethod: TransactionPaymentMethod.cash,
      time: timeFormatted,
      itemSummary: summary.isNotEmpty ? summary : 'Pesanan Kasir',
      totalAmount: widget.totalAmount,
      amountPaid: _receivedAmount,
      changeAmount: _changeAmount,
      status: 'PAID',
      syncStatus: SyncStatus.pending,
      createdAt: now,
      createdAtMillis: now.millisecondsSinceEpoch,
      orderType: widget.orderInfo.orderType,
    );

    final printerItems = widget.cartItems.map((e) => {
      'name': e.product.name,
      'product_name': e.product.name,
      'qty': e.quantity,
      'quantity': e.quantity,
      'unit_price': e.product.price,
      'subtotal': e.quantity * e.product.price,
    }).toList();

    // If auto-print is enabled, trigger printer in background
    final printer = ThermalPrinterService();
    if (printer.autoPrint && printer.connectedDeviceMac != null && printer.connectedDeviceMac!.isNotEmpty) {
      printer.printReceipt(
        transaction: newTransaction,
        items: printerItems,
        orderType: widget.orderInfo.orderType,
      );
    }

    // Show Payment Success Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentSuccessDialog(
        transaction: newTransaction,
        onPrintReceipt: () {
          ThermalReceiptModal.show(
            context,
            transaction: newTransaction,
            items: printerItems,
            orderType: widget.orderInfo.orderType,
          );
        },
        onFinish: () {
          Navigator.pop(ctx); // Close dialog
          Navigator.pop(context, newTransaction); // Return to cart and home
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isWide(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Row(
                children: [
                  // Back button
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.chipInactiveBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title
                  const Expanded(
                    child: Text(
                      'Pembayaran Tunai',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),

                  // Order Type Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.chipInactiveBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.orderInfo.orderType,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Body (Adaptive 2-column on Wide screens, 1-column on Phone)
            Expanded(
              child: isWide
                  ? Center(
                      child: MaxContentWidth(
                        maxWidth: 960,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column: Calculation breakdown & quick cash chips
                              Expanded(
                                flex: 5,
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    children: [
                                      CashCalculationCard(
                                        totalAmount: widget.totalAmount,
                                        receivedAmount: _receivedAmount,
                                        onClear: _handleClear,
                                      ),
                                      const SizedBox(height: 12),
                                      QuickCashChips(
                                        totalAmount: widget.totalAmount,
                                        currentReceivedAmount: _receivedAmount,
                                        onAmountSelected: _handleSelectQuickAmount,
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),

                              // Right column: Numpad & Confirm CTA Button
                              Expanded(
                                flex: 5,
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    children: [
                                      CashNumpad(
                                        onKeyPress: _handleNumpadKey,
                                        onDelete: _handleDelete,
                                        onClear: _handleClear,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildConfirmButton(),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        children: [
                          // Calculation breakdown card
                          CashCalculationCard(
                            totalAmount: widget.totalAmount,
                            receivedAmount: _receivedAmount,
                            onClear: _handleClear,
                          ),

                          const SizedBox(height: 12),

                          // Quick cash chips (3x3 grid)
                          QuickCashChips(
                            totalAmount: widget.totalAmount,
                            currentReceivedAmount: _receivedAmount,
                            onAmountSelected: _handleSelectQuickAmount,
                          ),

                          const SizedBox(height: 12),

                          // POS Cashier Numpad
                          CashNumpad(
                            onKeyPress: _handleNumpadKey,
                            onDelete: _handleDelete,
                            onClear: _handleClear,
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
            ),

            // Bottom Confirm Button (Only shown at bottom for narrow/mobile screens)
            if (!isWide)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: _buildConfirmButton(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSufficient ? _confirmPayment : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: _isSufficient
                ? AppColors.primaryDark
                : AppColors.primaryDark.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isSufficient
                ? [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isSufficient ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _isSufficient
                      ? 'Konfirmasi Bayar (${CurrencyFormatter.format(_receivedAmount)})'
                      : 'Uang Kurang (${CurrencyFormatter.format(widget.totalAmount - _receivedAmount)})',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
