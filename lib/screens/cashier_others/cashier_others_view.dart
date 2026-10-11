import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_layout.dart';
import '../../models/cashier_session_model.dart';
import '../../models/recent_transaction_model.dart';
import 'widgets/account_actions_card.dart';
import 'widgets/others_profile_card.dart';
import 'widgets/printer_settings_card.dart';
import 'widgets/shift_management_card.dart';

class CashierOthersView extends StatelessWidget {
  final CashierSessionModel session;
  final List<RecentTransactionModel> transactions;
  final VoidCallback onSyncTap;
  final VoidCallback onUpdateMenuTap;
  final ValueChanged<double>? onStartingCashChanged;
  final VoidCallback onShiftClosed;
  final VoidCallback onLogout;

  const CashierOthersView({
    super.key,
    required this.session,
    required this.transactions,
    required this.onSyncTap,
    required this.onUpdateMenuTap,
    this.onStartingCashChanged,
    required this.onShiftClosed,
    required this.onLogout,
  });

  double get _totalCashSales {
    return transactions
        .where((t) => t.paymentMethod == TransactionPaymentMethod.cash)
        .fold<double>(0, (sum, t) => sum + t.totalAmount);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isWide(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Title
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pengaturan & Lainnya',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manajemen hardware, shift kasir, dan data',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isWide)
            // Wide Screen: 2-Column Responsive Layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Profil & Shift Management
                Expanded(
                  child: Column(
                    children: [
                      OthersProfileCard(session: session),
                      const SizedBox(height: 14),
                      ShiftManagementCard(
                        session: session,
                        totalCashSales: _totalCashSales,
                        transactions: transactions,
                        onStartingCashChanged: onStartingCashChanged,
                        onShiftClosed: onShiftClosed,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Right Column: Printer & System Actions
                Expanded(
                  child: Column(
                    children: [
                      const PrinterSettingsCard(),
                      const SizedBox(height: 14),
                      AccountActionsCard(
                        session: session,
                        onLogout: onLogout,
                      ),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            // Standard Phone 1-Column Layout
            OthersProfileCard(session: session),
            const SizedBox(height: 14),

            ShiftManagementCard(
              session: session,
              totalCashSales: _totalCashSales,
              transactions: transactions,
              onStartingCashChanged: onStartingCashChanged,
              onShiftClosed: onShiftClosed,
            ),
            const SizedBox(height: 14),

            const PrinterSettingsCard(),
            const SizedBox(height: 14),

            AccountActionsCard(
              session: session,
              onLogout: onLogout,
            ),
          ],

          const SizedBox(height: 24),

          // Version Info Footer
          const Center(
            child: Column(
              children: [
                Text(
                  'POSAN Mobile POS v2.4.0 (Build 240)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'PT Posan Digital Indonesia • Offline-First Engine',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
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
