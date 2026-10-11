import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/cashier_session_model.dart';

class OthersProfileCard extends StatelessWidget {
  final CashierSessionModel session;

  const OthersProfileCard({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEFE8DD),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar (Dark Espresso with white person icon)
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name and Outlet details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.cashierName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleBadgeColor(session.role),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getRoleBadgeLabel(session.role),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  session.merchantName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  session.shift,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleBadgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'super_admin':
        return const Color(0xFF6B38A8);
      case 'admin':
        return const Color(0xFF1E5B8C);
      case 'kasir':
      default:
        return const Color(0xFFC4713B);
    }
  }

  String _getRoleBadgeLabel(String role) {
    switch (role.toLowerCase()) {
      case 'super_admin':
        return 'SUPER ADMIN';
      case 'admin':
        return 'ADMIN';
      case 'kasir':
      default:
        return 'KASIR';
    }
  }
}


