import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HistoryFilterChips extends StatelessWidget {
  final String selectedFilter;
  final int totalCount;
  final int pendingCount;
  final ValueChanged<String> onFilterSelected;

  const HistoryFilterChips({
    super.key,
    required this.selectedFilter,
    required this.totalCount,
    required this.pendingCount,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'id': 'all', 'label': 'Semua', 'badge': '$totalCount'},
      {'id': 'cash', 'label': 'Tunai', 'icon': Icons.payments_outlined},
      {'id': 'qris', 'label': 'QRIS', 'icon': Icons.qr_code_scanner_rounded},
      {'id': 'bank', 'label': 'Debit / EDC', 'icon': Icons.credit_card_rounded},
      {
        'id': 'pending',
        'label': 'Pending Sync',
        'badge': pendingCount > 0 ? '$pendingCount' : null,
        'icon': Icons.hourglass_top_rounded
      },
      {'id': 'synced', 'label': 'Tersinkron', 'icon': Icons.cloud_done_rounded},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final id = f['id'] as String;
          final label = f['label'] as String;
          final badge = f['badge'] as String?;
          final icon = f['icon'] as IconData?;
          final isSelected = selectedFilter == id;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onFilterSelected(id),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7.5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF30221A)
                      : const Color(0xFFF3EEE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF4A382E)
                              : id == 'pending' && pendingCount > 0
                                  ? const Color(0xFFFDEEE6)
                                  : const Color(0xFFE2DCD3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : id == 'pending' && pendingCount > 0
                                    ? const Color(0xFFBA6A34)
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
