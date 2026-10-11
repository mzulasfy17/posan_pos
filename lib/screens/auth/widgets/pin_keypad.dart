import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PinKeypad extends StatelessWidget {
  final String pin;
  final int pinLength;
  final ValueChanged<String> onKeyPress;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  const PinKeypad({
    super.key,
    required this.pin,
    this.pinLength = 4,
    required this.onKeyPress,
    required this.onBackspace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PIN Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pinLength, (index) {
            final isFilled = index < pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: isFilled ? 18 : 14,
              height: isFilled ? 18 : 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? AppColors.accentRust : Colors.transparent,
                border: Border.all(
                  color: isFilled
                      ? AppColors.accentRust
                      : AppColors.borderMedium,
                  width: 2,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: AppColors.accentRust.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 18),

        // Keypad Grid
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 10),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 10),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 10),
        _buildBottomKeypadRow(),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) => _buildKeyBtn(key)).toList(),
    );
  }

  Widget _buildBottomKeypadRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Clear Button (C)
        _buildActionBtn(
          icon: null,
          label: 'C',
          onTap: onClear,
        ),
        const SizedBox(width: 12),

        // 0 Digit
        _buildKeyBtn('0', margin: EdgeInsets.zero),
        const SizedBox(width: 12),

        // Backspace
        _buildActionBtn(
          icon: Icons.backspace_outlined,
          label: null,
          onTap: onBackspace,
        ),
      ],
    );
  }

  Widget _buildKeyBtn(String digit, {EdgeInsetsGeometry? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onKeyPress(digit),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 66,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData? icon,
    required String? label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 66,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.chipInactiveBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: 20, color: AppColors.textSecondary)
                : Text(
                    label ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
