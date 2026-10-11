import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class LoginHeader extends StatelessWidget {
  final bool isCompact;

  const LoginHeader({
    super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoSize = isCompact ? 56.0 : 72.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Container with soft glow
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isCompact ? 16 : 22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.accentRust.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isCompact ? 16 : 22),
            child: Image.asset(
              'assets/images/posan_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.primaryDark,
                  child: Center(
                    child: Icon(
                      Icons.point_of_sale_rounded,
                      color: Colors.white,
                      size: isCompact ? 28 : 36,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: isCompact ? 10 : 14),

        // Brand Name
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'POSAN',
              style: TextStyle(
                fontSize: isCompact ? 22 : 26,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: AppColors.onlineBadgeBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.onlineBadgeText.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.onlineDot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'ONLINE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onlineBadgeText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Subtitle / Tagline
        Text(
          'Point of Sales & Kasir Mobile Café',
          style: TextStyle(
            fontSize: isCompact ? 12 : 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
