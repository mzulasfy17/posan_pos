import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum OrderType { dineIn, takeaway }

class OrderTypeSelectionResult {
  final OrderType type;
  final String label; // "Dine In" or "Takeaway"
  final String detail; // "Dine In" or "Takeaway"

  const OrderTypeSelectionResult({
    required this.type,
    required this.label,
    required this.detail,
  });
}

class OrderTypePickerModal extends StatefulWidget {
  final OrderType initialType;
  final String? initialDetail;
  final ValueChanged<OrderTypeSelectionResult> onSelected;

  const OrderTypePickerModal({
    super.key,
    this.initialType = OrderType.dineIn,
    this.initialDetail,
    required this.onSelected,
  });

  static Future<OrderTypeSelectionResult?> show(
    BuildContext context, {
    OrderType initialType = OrderType.dineIn,
    String? initialDetail,
  }) {
    return showModalBottomSheet<OrderTypeSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderTypePickerModal(
        initialType: initialType,
        initialDetail: initialDetail,
        onSelected: (result) {
          Navigator.pop(context, result);
        },
      ),
    );
  }

  @override
  State<OrderTypePickerModal> createState() => _OrderTypePickerModalState();
}

class _OrderTypePickerModalState extends State<OrderTypePickerModal> {
  late OrderType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  void _handleConfirm() {
    final isDineIn = _selectedType == OrderType.dineIn;
    final label = isDineIn ? 'Dine In' : 'Takeaway';

    widget.onSelected(OrderTypeSelectionResult(
      type: _selectedType,
      label: label,
      detail: label,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderMedium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header Title
                const Text(
                  'Pilih Tipe Pesanan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tentukan apakah pesanan disantap di tempat atau dibawa pulang',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Segmented 2-Card Selection
                Row(
                  children: [
                    // Dine In Card
                    Expanded(
                      child: _buildTypeCard(
                        type: OrderType.dineIn,
                        title: 'Dine In',
                        subtitle: 'Makan di Tempat',
                        icon: Icons.table_restaurant_rounded,
                        isSelected: _selectedType == OrderType.dineIn,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Takeaway Card
                    Expanded(
                      child: _buildTypeCard(
                        type: OrderType.takeaway,
                        title: 'Takeaway',
                        subtitle: 'Bawa Pulang',
                        icon: Icons.takeout_dining_rounded,
                        isSelected: _selectedType == OrderType.takeaway,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Confirm CTA Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Terapkan Tipe Pesanan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard({
    required OrderType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() => _selectedType = type);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFDF1E8)
              : const Color(0xFFF8F5EE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFBA6A34)
                : const Color(0xFFE5DFD5),
            width: isSelected ? 1.8 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFBA6A34).withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFBA6A34)
                        : const Color(0xFFEAE3D9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    size: 20,
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFFBA6A34),
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? const Color(0xFF8A461B)
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? const Color(0xFF8A461B).withValues(alpha: 0.85)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
