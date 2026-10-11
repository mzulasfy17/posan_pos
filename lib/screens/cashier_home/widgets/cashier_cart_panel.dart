import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/cart_order_model.dart';
import '../../../models/recent_transaction_model.dart';
import '../../cashier_cart/widgets/cart_item_card.dart';
import '../../cashier_payment/cash_payment_screen.dart';

class CashierCartPanel extends StatelessWidget {
  final List<CartItemModel> items;
  final String orderType;
  final VoidCallback onSelectOrderType;
  final ValueChanged<CartItemModel> onIncrementItem;
  final ValueChanged<CartItemModel> onDecrementItem;
  final ValueChanged<CartItemModel> onDeleteItem;
  final VoidCallback onClearCart;
  final ValueChanged<RecentTransactionModel> onPaymentSuccess;

  const CashierCartPanel({
    super.key,
    required this.items,
    required this.orderType,
    required this.onSelectOrderType,
    required this.onIncrementItem,
    required this.onDecrementItem,
    required this.onDeleteItem,
    required this.onClearCart,
    required this.onPaymentSuccess,
  });

  int get _totalItemCount =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get _subtotal =>
      items.fold<double>(0, (sum, item) => sum + item.subtotal);

  double get _taxAmount => _subtotal * 0.11; // 11% PPN

  double get _totalAmount => _subtotal + _taxAmount;

  void _handlePay(BuildContext context) async {
    if (items.isEmpty) return;

    final result = await Navigator.push<RecentTransactionModel>(
      context,
      MaterialPageRoute(
        builder: (context) => CashPaymentScreen(
          totalAmount: _totalAmount,
          cartItems: items,
          orderInfo: OrderInfoModel(
            orderType: orderType,
            station: 'Kasir Utama',
          ),
        ),
      ),
    );

    if (result != null) {
      onPaymentSuccess(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: const Border(
          left: BorderSide(
            color: Color(0xFFECE4D9),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Panel Header (Order Type & Clear Cart)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFECE4D9), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onSelectOrderType,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.chipInactiveBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.restaurant_rounded,
                            size: 16,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              orderType,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onClearCart,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.chipInactiveBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 2. Cart Items List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.chipInactiveBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                size: 30,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Pesanan Belum Ada',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pilih menu makanan/minuman di samping untuk menambahkan ke pesanan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return CartItemCard(
                        item: item,
                        onIncrement: () => onIncrementItem(item),
                        onDecrement: () => onDecrementItem(item),
                        onDelete: () => onDeleteItem(item),
                        onEditNote: () {},
                      );
                    },
                  ),
          ),

          // 3. Payment Breakdown & CTA
          if (items.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFECE4D9), width: 1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Subtotal & Tax Rows
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal ($_totalItemCount item)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(_subtotal),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PPN (11%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(_taxAmount),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFECE4D9), height: 16),

                  // Total Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Tagihan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(_totalAmount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pay Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => _handlePay(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payments_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Bayar ${CurrencyFormatter.format(_totalAmount)}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
