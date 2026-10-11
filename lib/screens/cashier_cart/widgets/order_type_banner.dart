import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../cashier_home/widgets/order_type_picker_modal.dart';

class OrderTypeBanner extends StatelessWidget {
  final String orderType;
  final String station;
  final ValueChanged<String>? onOrderTypeChanged;
  final VoidCallback? onEditOrderType;

  const OrderTypeBanner({
    super.key,
    required this.orderType,
    required this.station,
    this.onOrderTypeChanged,
    this.onEditOrderType,
  });

  bool get _isDineIn => orderType.toLowerCase().contains('dine in');

  void _openPicker(BuildContext context) async {
    final result = await OrderTypePickerModal.show(
      context,
      initialType: _isDineIn ? OrderType.dineIn : OrderType.takeaway,
      initialDetail: orderType,
    );
    if (result != null) {
      onOrderTypeChanged?.call(result.label);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFECE4D9),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon container (peach for Dine In / Takeaway)
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEEE6),
                  borderRadius: BorderRadius.circular(12),
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
              const SizedBox(width: 12),

              // Order Type info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TIPE PESANAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      orderType,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Change / Edit Button
              InkWell(
                onTap: () => _openPicker(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EEE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ubah',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFBA6A34),
                        ),
                      ),
                      SizedBox(width: 3),
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

          const SizedBox(height: 10),

          // Quick 2-Pill Switch (Dine In vs Takeaway)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (!_isDineIn) {
                      onOrderTypeChanged?.call('Dine In');
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _isDineIn
                          ? const Color(0xFF30221A)
                          : const Color(0xFFF8F5EE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isDineIn
                            ? const Color(0xFF30221A)
                            : const Color(0xFFE5DFD5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_rounded,
                          size: 15,
                          color: _isDineIn
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Dine In',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _isDineIn
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (_isDineIn) {
                      onOrderTypeChanged?.call('Takeaway');
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: !_isDineIn
                          ? const Color(0xFF30221A)
                          : const Color(0xFFF8F5EE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !_isDineIn
                            ? const Color(0xFF30221A)
                            : const Color(0xFFE5DFD5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.takeout_dining_rounded,
                          size: 15,
                          color: !_isDineIn
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Takeaway',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: !_isDineIn
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
