import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';

class FloatingCartBar extends StatelessWidget {
  final int totalItemCount;
  final double totalPrice;
  final String orderType;
  final VoidCallback onTap;
  final VoidCallback? onOrderTypeTap;

  const FloatingCartBar({
    super.key,
    required this.totalItemCount,
    required this.totalPrice,
    this.orderType = 'Dine In',
    required this.onTap,
    this.onOrderTypeTap,
  });

  bool get _isDineIn => orderType.toLowerCase().contains('dine in');

  @override
  Widget build(BuildContext context) {
    if (totalItemCount <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF9F4),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFECE4D9),
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          // Shopping bag / Table icon inside peach container (tappable to switch Dine In / Takeaway)
          InkWell(
            onTap: onOrderTypeTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFDEEE6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(
                  _isDineIn
                      ? Icons.table_restaurant_rounded
                      : Icons.shopping_bag_outlined,
                  color: const Color(0xFFBA6A34),
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Product count & total price (tap orderType to change)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onOrderTypeTap,
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '$totalItemCount Produk  •  $orderType',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: Color(0xFFBA6A34),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  CurrencyFormatter.format(totalPrice),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // "Lihat Keranjang ->" CTA Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFBA6A34),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lihat Keranjang',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
