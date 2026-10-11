import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class RushHourTipBanner extends StatelessWidget {
  const RushHourTipBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.shiftBadgeBg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accentRust.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.mood_rounded,
            color: AppColors.shiftBadgeText,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF4A3528),
                ),
                children: [
                  TextSpan(
                    text:
                        'Sedang jam ramai pagi. Tips: Gunakan shortcut ',
                  ),
                  TextSpan(
                    text: 'Bayar Pas',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  TextSpan(
                    text: ' untuk antrean kasir lebih cepat!',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
