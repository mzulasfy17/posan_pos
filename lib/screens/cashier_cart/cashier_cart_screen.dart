import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/responsive_layout.dart';
import '../../models/cart_order_model.dart';
import '../../models/recent_transaction_model.dart';
import '../cashier_payment/cash_payment_screen.dart';
import 'widgets/cart_header.dart';
import 'widgets/order_type_banner.dart';
import 'widgets/cart_item_card.dart';
import 'widgets/add_order_note_banner.dart';
import 'widgets/payment_breakdown_card.dart';
import 'widgets/cart_bottom_cta.dart';

class CashierCartScreen extends StatefulWidget {
  final List<CartItemModel> initialItems;
  final OrderInfoModel initialOrderInfo;
  final ValueChanged<List<CartItemModel>>? onCartUpdated;

  const CashierCartScreen({
    super.key,
    required this.initialItems,
    this.initialOrderInfo = const OrderInfoModel(),
    this.onCartUpdated,
  });

  @override
  State<CashierCartScreen> createState() => _CashierCartScreenState();
}

class _CashierCartScreenState extends State<CashierCartScreen> {
  late List<CartItemModel> _cartItems;
  late OrderInfoModel _orderInfo;

  @override
  void initState() {
    super.initState();
    _cartItems = List.from(widget.initialItems);
    _orderInfo = widget.initialOrderInfo;
  }

  int get _totalItemCount =>
      _cartItems.fold<int>(0, (sum, item) => sum + item.quantity);

  double get _subtotal =>
      _cartItems.fold<double>(0, (sum, item) => sum + item.subtotal);

  double get _discountAmount => _orderInfo.discount;

  double get _taxAmount => (_subtotal - _discountAmount) * _orderInfo.taxRate;

  double get _totalAmount => (_subtotal - _discountAmount) + _taxAmount;

  void _notifyCartUpdate() {
    widget.onCartUpdated?.call(_cartItems);
  }

  void _incrementItem(CartItemModel item) {
    setState(() {
      item.quantity += 1;
      item.product.cartQuantity = item.quantity;
    });
    _notifyCartUpdate();
  }

  void _decrementItem(CartItemModel item) {
    setState(() {
      if (item.quantity > 1) {
        item.quantity -= 1;
        item.product.cartQuantity = item.quantity;
      } else {
        _deleteItem(item);
        return;
      }
    });
    _notifyCartUpdate();
  }

  void _deleteItem(CartItemModel item) {
    setState(() {
      item.product.cartQuantity = 0;
      _cartItems.remove(item);
    });
    _notifyCartUpdate();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.product.name} dihapus dari keranjang.'),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearCart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Kosongkan Keranjang?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Semua produk yang ada di keranjang akan dihapus.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                for (final item in _cartItems) {
                  item.product.cartQuantity = 0;
                }
                _cartItems.clear();
              });
              _notifyCartUpdate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.outOfStockBadgeText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Kosongkan',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNoteDialog({CartItemModel? item}) {
    final isOrderNote = item == null;
    final controller = TextEditingController(
      text: isOrderNote ? (_orderInfo.orderNote ?? '') : (item.note ?? ''),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isOrderNote
              ? 'Catatan Pesanan'
              : 'Catatan: ${item.product.name}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isOrderNote
                ? 'Contoh: Jangan terlalu manis / piring terpisah'
                : 'Contoh: Less ice, gula aren 50%',
            hintStyle: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.chipInactiveBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newNote = controller.text.trim();
              setState(() {
                if (isOrderNote) {
                  _orderInfo = _orderInfo.copyWith(
                    orderNote: newNote.isEmpty ? null : newNote,
                  );
                } else {
                  item.note = newNote.isEmpty ? null : newNote;
                }
              });
              Navigator.pop(ctx);
              _notifyCartUpdate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Simpan',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentModal() {
    if (_cartItems.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih Metode Pembayaran',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total Tagihan: ${CurrencyFormatter.format(_totalAmount)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),

            // Cash
            _buildPaymentMethodTile(
              icon: Icons.payments_rounded,
              title: 'Tunai (Cash)',
              subtitle: 'Terima uang kertas/koin, hitung kembalian cepat',
              onTap: () => _processPayment('Tunai'),
            ),
            const SizedBox(height: 10),

            // QRIS
            _buildPaymentMethodTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'QRIS Dinamis',
              subtitle: 'Scan QRIS BCA / Mandiri / GoPay / OVO / ShopeePay',
              onTap: () => _processPayment('QRIS'),
            ),
            const SizedBox(height: 10),

            // Debit / Transfer
            _buildPaymentMethodTile(
              icon: Icons.credit_card_rounded,
              title: 'Transfer Bank / Debit EDC',
              subtitle: 'BCA, Mandiri, BRI, BNI mesin EDC',
              onTap: () => _processPayment('Transfer Bank'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  ),
);
}

  Widget _buildPaymentMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.chipInactiveBg.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _processPayment(String method) async {
    Navigator.pop(context); // Close bottom sheet

    if (method == 'Tunai') {
      final result = await Navigator.push<RecentTransactionModel>(
        context,
        MaterialPageRoute(
          builder: (context) => CashPaymentScreen(
            totalAmount: _totalAmount,
            cartItems: _cartItems,
            orderInfo: _orderInfo,
          ),
        ),
      );

      if (result != null && mounted) {
        // Return completed transaction to HomeScreen
        Navigator.pop(context, result);
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pembayaran $method ${CurrencyFormatter.format(_totalAmount)} Berhasil (Status: PAID)',
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isWide(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: MaxContentWidth(
          maxWidth: 1000,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: CartHeader(
                  onBack: () => Navigator.pop(context),
                  onProfileTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Kasir: Zul (Shift Pagi)'),
                        backgroundColor: AppColors.primaryDark,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),

              // Body Content
              Expanded(
                child: _cartItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.remove_shopping_cart_outlined,
                              size: 54,
                              color: AppColors.textMuted.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Keranjang belanja kosong',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Silakan pilih produk dari katalog menu.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                'Kembali ke Katalog',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      )
                    : isWide
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left column: Cart Items
                                Expanded(
                                  flex: 6,
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      children: [
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: _cartItems.length,
                                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final item = _cartItems[index];
                                            return CartItemCard(
                                              item: item,
                                              onIncrement: () => _incrementItem(item),
                                              onDecrement: () => _decrementItem(item),
                                              onDelete: () => _deleteItem(item),
                                              onEditNote: () =>
                                                  _showEditNoteDialog(item: item),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        AddOrderNoteBanner(
                                          currentNote: _orderInfo.orderNote,
                                          onTap: () => _showEditNoteDialog(),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),

                                // Right column: Order Info & Payment Breakdown & CTA
                                Expanded(
                                  flex: 4,
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      children: [
                                        OrderTypeBanner(
                                          orderType: _orderInfo.orderType,
                                          station: _orderInfo.station,
                                          onOrderTypeChanged: (newType) {
                                            setState(() {
                                              _orderInfo = _orderInfo.copyWith(orderType: newType);
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 14),
                                        PaymentBreakdownCard(
                                          totalItems: _totalItemCount,
                                          subtotal: _subtotal,
                                          discount: _discountAmount,
                                          taxAmount: _taxAmount,
                                          totalAmount: _totalAmount,
                                        ),
                                        const SizedBox(height: 16),
                                        CartBottomCta(
                                          totalItems: _totalItemCount,
                                          totalAmount: _totalAmount,
                                          onProceedToPayment: _showPaymentModal,
                                          onClearCart: _clearCart,
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              // Order Type Banner
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  child: OrderTypeBanner(
                                    orderType: _orderInfo.orderType,
                                    station: _orderInfo.station,
                                    onOrderTypeChanged: (newType) {
                                      setState(() {
                                        _orderInfo = _orderInfo.copyWith(orderType: newType);
                                      });
                                    },
                                  ),
                                ),
                              ),

                              const SliverToBoxAdapter(
                                child: SizedBox(height: 16),
                              ),

                              // Cart Items
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final item = _cartItems[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: CartItemCard(
                                          item: item,
                                          onIncrement: () => _incrementItem(item),
                                          onDecrement: () => _decrementItem(item),
                                          onDelete: () => _deleteItem(item),
                                          onEditNote: () =>
                                              _showEditNoteDialog(item: item),
                                        ),
                                      );
                                    },
                                    childCount: _cartItems.length,
                                  ),
                                ),
                              ),

                              // Add Order Note Banner
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  child: AddOrderNoteBanner(
                                    currentNote: _orderInfo.orderNote,
                                    onTap: () => _showEditNoteDialog(),
                                  ),
                                ),
                              ),

                              const SliverToBoxAdapter(
                                child: SizedBox(height: 16),
                              ),

                              // Payment Breakdown Card
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  child: PaymentBreakdownCard(
                                    totalItems: _totalItemCount,
                                    subtotal: _subtotal,
                                    discount: _discountAmount,
                                    taxAmount: _taxAmount,
                                    totalAmount: _totalAmount,
                                  ),
                                ),
                              ),

                              const SliverToBoxAdapter(
                                child: SizedBox(height: 24),
                              ),
                            ],
                          ),
              ),

              // Fixed Bottom CTA for mobile portrait only
              if (_cartItems.isNotEmpty && !isWide)
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: CartBottomCta(
                    totalItems: _totalItemCount,
                    totalAmount: _totalAmount,
                    onProceedToPayment: _showPaymentModal,
                    onClearCart: _clearCart,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
