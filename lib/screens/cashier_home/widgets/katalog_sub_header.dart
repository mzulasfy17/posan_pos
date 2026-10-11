import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/cashier_session_model.dart';

class KatalogSubHeader extends StatelessWidget {
  final CashierSessionModel session;
  final VoidCallback? onSyncTap;
  final bool isGridView;
  final VoidCallback? onToggleViewMode;

  const KatalogSubHeader({
    super.key,
    required this.session,
    this.onSyncTap,
    this.isGridView = true,
    this.onToggleViewMode,
  });

  @override
  Widget build(BuildContext context) {
    String displayShift = session.shift.trim();
    if (displayShift.contains('(')) {
      displayShift = displayShift.split('(').first.trim();
    }
    if (displayShift.isEmpty) {
      displayShift = 'Shift Utama';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Column: Catalog title & subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Katalog Menu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              const Text(
                'Pilih produk untuk menambah pesanan',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Right side: View Mode Toggle (Grid/List) + Shift Pill + Circular Sync
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // View Mode Toggle Button (Grid / List)
            if (onToggleViewMode != null)
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEE7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFECE4D9),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: isGridView ? null : onToggleViewMode,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isGridView ? const Color(0xFF30221A) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: isGridView ? Colors.white : AppColors.textMuted,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: !isGridView ? null : onToggleViewMode,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: !isGridView ? const Color(0xFF30221A) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                        ),
                        child: Icon(
                          Icons.view_list_rounded,
                          size: 16,
                          color: !isGridView ? Colors.white : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Shift Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF0E7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF7DAC7),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wb_sunny_outlined,
                    size: 13,
                    color: Color(0xFFB86634),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    displayShift,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB86634),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Circular Refresh Button
            InkWell(
              onTap: onSyncTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3EEE7),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: session.isAutoSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textSecondary,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.sync_rounded,
                          size: 17,
                          color: AppColors.textPrimary,
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
