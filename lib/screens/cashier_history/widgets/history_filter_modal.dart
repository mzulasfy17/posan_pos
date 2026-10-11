import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HistoryFilterState {
  final String paymentMethod; // 'all', 'cash', 'qris', 'bank'
  final String orderType; // 'all', 'dine_in', 'takeaway'
  final String syncStatus; // 'all', 'pending', 'synced'
  final String timeRange; // 'all', 'today', 'yesterday', 'this_week'

  const HistoryFilterState({
    this.paymentMethod = 'all',
    this.orderType = 'all',
    this.syncStatus = 'all',
    this.timeRange = 'all',
  });

  bool get isDefault =>
      paymentMethod == 'all' &&
      orderType == 'all' &&
      syncStatus == 'all' &&
      timeRange == 'all';

  int get activeFilterCount {
    int count = 0;
    if (paymentMethod != 'all') count++;
    if (orderType != 'all') count++;
    if (syncStatus != 'all') count++;
    if (timeRange != 'all') count++;
    return count;
  }

  HistoryFilterState copyWith({
    String? paymentMethod,
    String? orderType,
    String? syncStatus,
    String? timeRange,
  }) {
    return HistoryFilterState(
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderType: orderType ?? this.orderType,
      syncStatus: syncStatus ?? this.syncStatus,
      timeRange: timeRange ?? this.timeRange,
    );
  }
}

class HistoryFilterModal extends StatefulWidget {
  final HistoryFilterState initialFilter;
  final ValueChanged<HistoryFilterState> onApply;

  const HistoryFilterModal({
    super.key,
    required this.initialFilter,
    required this.onApply,
  });

  static Future<HistoryFilterState?> show(
    BuildContext context, {
    required HistoryFilterState currentFilter,
  }) {
    return showModalBottomSheet<HistoryFilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HistoryFilterModal(
        initialFilter: currentFilter,
        onApply: (filter) => Navigator.pop(context, filter),
      ),
    );
  }

  @override
  State<HistoryFilterModal> createState() => _HistoryFilterModalState();
}

class _HistoryFilterModalState extends State<HistoryFilterModal> {
  late HistoryFilterState _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  void _reset() {
    setState(() {
      _filter = const HistoryFilterState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderMedium,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Riwayat Transaksi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (!_filter.isDefault)
                        InkWell(
                          onTap: _reset,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFBA6A34),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Saring transaksi berdasarkan periode, metode, tipe, dan status',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 1. Periode Waktu
                  _buildSectionTitle('Periode Transaksi'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip('Semua Waktu', 'all', _filter.timeRange,
                          (val) => setState(() => _filter = _filter.copyWith(timeRange: val))),
                      _buildFilterChip('Hari Ini', 'today', _filter.timeRange,
                          (val) => setState(() => _filter = _filter.copyWith(timeRange: val))),
                      _buildFilterChip('Kemarin', 'yesterday', _filter.timeRange,
                          (val) => setState(() => _filter = _filter.copyWith(timeRange: val))),
                      _buildFilterChip('7 Hari Terakhir', 'this_week', _filter.timeRange,
                          (val) => setState(() => _filter = _filter.copyWith(timeRange: val))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Metode Pembayaran
                  _buildSectionTitle('Metode Pembayaran'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip('Semua Metode', 'all', _filter.paymentMethod,
                          (val) => setState(() => _filter = _filter.copyWith(paymentMethod: val))),
                      _buildFilterChip('💵 Tunai (Cash)', 'cash', _filter.paymentMethod,
                          (val) => setState(() => _filter = _filter.copyWith(paymentMethod: val))),
                      _buildFilterChip('📱 QRIS', 'qris', _filter.paymentMethod,
                          (val) => setState(() => _filter = _filter.copyWith(paymentMethod: val))),
                      _buildFilterChip('💳 Debit / EDC', 'bank', _filter.paymentMethod,
                          (val) => setState(() => _filter = _filter.copyWith(paymentMethod: val))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Tipe Pesanan
                  _buildSectionTitle('Tipe Pesanan'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip('Semua Tipe', 'all', _filter.orderType,
                          (val) => setState(() => _filter = _filter.copyWith(orderType: val))),
                      _buildFilterChip('🍽️ Makan di Tempat (Dine In)', 'dine_in', _filter.orderType,
                          (val) => setState(() => _filter = _filter.copyWith(orderType: val))),
                      _buildFilterChip('🥡 Bawa Pulang (Take Away)', 'takeaway', _filter.orderType,
                          (val) => setState(() => _filter = _filter.copyWith(orderType: val))),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Status Sinkronisasi
                  _buildSectionTitle('Status Sinkronisasi Cloud'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip('Semua Status', 'all', _filter.syncStatus,
                          (val) => setState(() => _filter = _filter.copyWith(syncStatus: val))),
                      _buildFilterChip('⏳ Pending Sync', 'pending', _filter.syncStatus,
                          (val) => setState(() => _filter = _filter.copyWith(syncStatus: val))),
                      _buildFilterChip('☁️ Tersinkron (Synced)', 'synced', _filter.syncStatus,
                          (val) => setState(() => _filter = _filter.copyWith(syncStatus: val))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: Color(0xFFECE4D9)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Batal',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => widget.onApply(_filter),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Terapkan Filter',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = value == currentValue;
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF30221A) : const Color(0xFFF3EEE7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF30221A) : const Color(0xFFE5DFD5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
