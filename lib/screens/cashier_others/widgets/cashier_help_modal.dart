import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CashierHelpModal extends StatelessWidget {
  const CashierHelpModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CashierHelpModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
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

              // Title
              const Text(
                'Pusat Bantuan & Panduan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Panduan operasional kasir, printer, dan layanan bantuan',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),

              // Help Topics Accordions / Cards
              _buildHelpTopic(
                icon: Icons.point_of_sale_rounded,
                title: 'Alur Transaksi & Kasir',
                desc:
                    'Pilih produk di katalog > Atur Dine In/Takeaway > Buka keranjang > Pilih metode bayar (Tunai/QRIS) > Konfirmasi pembayaran.',
              ),
              const SizedBox(height: 10),
              _buildHelpTopic(
                icon: Icons.print_rounded,
                title: 'Koneksi Printer Thermal Bluetooth',
                desc:
                    'Pastikan Bluetooth HP aktif dan printer menyala. Tekan "Ganti" pada kartu printer untuk memindai perangkat terdekat (RPP02N, PT-210, dll).',
              ),
              const SizedBox(height: 10),
              _buildHelpTopic(
                icon: Icons.cloud_sync_rounded,
                title: 'Mode Offline & Sinkronisasi',
                desc:
                    'Aplikasi tetap dapat mencatat transaksi saat internet mati. Data akan tersimpan lokal dan otomatis disinkronkan saat online.',
              ),
              const SizedBox(height: 10),
              _buildHelpTopic(
                icon: Icons.lock_clock_rounded,
                title: 'Rekonsiliasi Kas & Tutup Shift',
                desc:
                    'Hitung fisik uang tunai di laci kasir saat pergantian shift. Sistem akan mencocokkan modal awal dan total penjualan tunai.',
              ),
              const SizedBox(height: 20),

              // Contact Support WhatsApp Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF1E8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFF4D4BF),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFBA6A34),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Butuh Bantuan Mendesak?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8A461B),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Hubungi Tim Support POSAN 24/7 via WhatsApp: 0812-3456-7890',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF8A461B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _buildHelpTopic({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFECE4D9),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFEBE4D8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
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
