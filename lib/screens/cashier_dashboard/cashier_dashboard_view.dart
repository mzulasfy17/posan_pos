import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive_layout.dart';
import '../../models/cashier_session_model.dart';
import '../../models/recent_transaction_model.dart';
import '../cashier_home/widgets/home_header.dart';
import 'widgets/dashboard_greeting_header.dart';
import 'widgets/summary_metric_cards.dart';
import 'widgets/create_order_banner.dart';
import 'widgets/recent_transactions_section.dart';

class CashierDashboardView extends StatelessWidget {
  final CashierSessionModel session;
  final List<RecentTransactionModel> transactions;
  final VoidCallback onCreateOrderTap;
  final VoidCallback onOrderHistoryTap;
  final VoidCallback onSyncTap;
  final VoidCallback? onProfileTap;
  final ValueChanged<RecentTransactionModel>? onTransactionTap;

  const CashierDashboardView({
    super.key,
    required this.session,
    required this.transactions,
    required this.onCreateOrderTap,
    required this.onOrderHistoryTap,
    required this.onSyncTap,
    this.onProfileTap,
    this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isWide(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Top App Header: POSAN logo, merchant outlet, Online badge, Profile
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: HomeHeader(
              session: session,
              onProfileTap: onProfileTap,
              onStatusTap: onSyncTap,
            ),
          ),
        ),

        // Greeting Header: "Selamat pagi, Zul 👋"
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 16),
            child: DashboardGreetingHeader(
              session: session,
              onSyncTap: onSyncTap,
            ),
          ),
        ),

        if (isWide)
          // Wide Screen (Tablet / Landscape): 2-Column Responsive Dashboard
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side: Create Order CTA + Metrics
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CreateOrderBanner(
                          onTap: onCreateOrderTap,
                        ),
                        const SizedBox(height: 14),
                        SummaryMetricCards(
                          session: session,
                          onSalesTap: onOrderHistoryTap,
                          onSyncTap: onSyncTap,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right side: Recent Transactions
                  Expanded(
                    flex: 5,
                    child: RecentTransactionsSection(
                      transactions: transactions,
                      onViewAllTap: onOrderHistoryTap,
                      onTransactionTap: onTransactionTap ??
                          (tx) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Detail ${tx.id} (${tx.paymentMethod.label}) - ${tx.itemSummary}',
                                ),
                                backgroundColor: AppColors.primaryDark,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Standard Mobile Portrait Layout
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: CreateOrderBanner(
                onTap: onCreateOrderTap,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 14),
          ),

          // Summary Metric Cards (Penjualan Hari Ini & Alert Sync)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SummaryMetricCards(
                session: session,
                onSalesTap: onOrderHistoryTap,
                onSyncTap: onSyncTap,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 18),
          ),

          // Recent Transactions Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: RecentTransactionsSection(
                transactions: transactions,
                onViewAllTap: onOrderHistoryTap,
                onTransactionTap: onTransactionTap ??
                    (tx) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Detail ${tx.id} (${tx.paymentMethod.label}) - ${tx.itemSummary}',
                          ),
                          backgroundColor: AppColors.primaryDark,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
              ),
            ),
          ),
        ],

        // Bottom Safe Spacing
        const SliverToBoxAdapter(
          child: SizedBox(height: 40),
        ),
      ],
    );
  }
}
