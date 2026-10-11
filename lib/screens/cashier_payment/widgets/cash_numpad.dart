import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CashNumpad extends StatelessWidget {
  final ValueChanged<String> onKeyPress;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  const CashNumpad({
    super.key,
    required this.onKeyPress,
    required this.onDelete,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 8),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 8),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 8),
        _buildBottomRow(),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      children: keys
          .map(
            (k) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildKey(
                  child: Text(
                    k,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onTap: () => onKeyPress(k),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      children: [
        // 'C' Clear key
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildKey(
              child: const Text(
                'C',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD32F2F),
                ),
              ),
              onTap: onClear,
            ),
          ),
        ),

        // '0' key
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildKey(
              child: const Text(
                '0',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () => onKeyPress('0'),
            ),
          ),
        ),

        // '000' key
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildKey(
              child: const Text(
                '000',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () => onKeyPress('000'),
            ),
          ),
        ),

        // Backspace key
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildKey(
              child: const Icon(
                Icons.backspace_outlined,
                size: 18,
                color: AppColors.textPrimary,
              ),
              onTap: onDelete,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKey({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

