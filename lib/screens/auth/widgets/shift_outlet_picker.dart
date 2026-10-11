import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ShiftOutletPicker extends StatelessWidget {
  final String selectedOutlet;
  final String selectedShift;
  final ValueChanged<String> onOutletChanged;
  final ValueChanged<String> onShiftChanged;

  const ShiftOutletPicker({
    super.key,
    required this.selectedOutlet,
    required this.selectedShift,
    required this.onOutletChanged,
    required this.onShiftChanged,
  });

  static const List<String> outlets = [
    'Kopi Senja - Senopati',
    'Kopi Senja - SCBD',
    'Kopi Senja - Kemang',
    'Kopi Senja - BSD City',
  ];

  static const List<String> shifts = [
    'Shift Pagi (07:00 - 15:00)',
    'Shift Sore (15:00 - 23:00)',
    'Shift Malam (23:00 - 07:00)',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Outlet Selector
          Row(
            children: [
              const Icon(
                Icons.storefront_rounded,
                size: 17,
                color: AppColors.accentRust,
              ),
              const SizedBox(width: 6),
              const Text(
                'Outlet:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedOutlet,
                      isDense: true,
                      isExpanded: true,
                      alignment: AlignmentDirectional.centerEnd,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: Colors.white,
                      items: outlets.map((outlet) {
                        return DropdownMenuItem<String>(
                          value: outlet,
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            outlet,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) onOutletChanged(val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 14, color: AppColors.borderLight),

          // Shift Selector
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 17,
                color: AppColors.accentRust,
              ),
              const SizedBox(width: 6),
              const Text(
                'Shift:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedShift,
                      isDense: true,
                      isExpanded: true,
                      alignment: AlignmentDirectional.centerEnd,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: Colors.white,
                      items: shifts.map((shift) {
                        return DropdownMenuItem<String>(
                          value: shift,
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            shift.split(' (').first,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) onShiftChanged(val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
