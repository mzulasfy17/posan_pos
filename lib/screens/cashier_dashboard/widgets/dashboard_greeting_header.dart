import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/cashier_session_model.dart';

class DashboardGreetingHeader extends StatelessWidget {
  final CashierSessionModel session;
  final VoidCallback? onSyncTap;

  const DashboardGreetingHeader({
    super.key,
    required this.session,
    this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.cashierGreeting,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 15,
              color: AppColors.accentRust,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                session.outletLocation,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
