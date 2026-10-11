import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';
import '../utils/currency_formatter.dart';
import '../../models/cashier_session_model.dart';
import '../../models/recent_transaction_model.dart';

class SalesReportExportService {
  static final SalesReportExportService _instance = SalesReportExportService._internal();
  factory SalesReportExportService() => _instance;
  SalesReportExportService._internal();

  /// Menghasilkan dan menyimpan file Excel (.xlsx) dari riwayat transaksi kasir
  Future<File?> generateAndSaveXlsxReport({
    required CashierSessionModel session,
    required List<RecentTransactionModel> transactions,
    DateTime? reportDate,
  }) async {
    try {
      final now = reportDate ?? DateTime.now();
      String dateFormatted;
      try {
        dateFormatted = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(now);
      } catch (_) {
        dateFormatted = DateFormat('dd MMM yyyy, HH:mm').format(now);
      }

      final totalSales = transactions.fold<double>(0, (sum, t) => sum + t.totalAmount);
      final totalTrx = transactions.length;
      final cashSales = transactions
          .where((t) => t.paymentMethod == TransactionPaymentMethod.cash)
          .fold<double>(0, (sum, t) => sum + t.totalAmount);
      final nonCashSales = totalSales - cashSales;

      // 1. Inisialisasi Workbook Excel
      final excel = Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, 'Laporan Penjualan');
      final sheet = excel['Laporan Penjualan'];

      // Helper untuk mengisi sel
      void setCell(int col, int row, dynamic val, {bool isBold = false, Color? bgColor}) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        if (val is int) {
          cell.value = IntCellValue(val);
        } else if (val is double) {
          cell.value = DoubleCellValue(val);
        } else {
          cell.value = TextCellValue(val.toString());
        }

        if (isBold) {
          cell.cellStyle = CellStyle(
            bold: true,
            fontSize: 11,
          );
        }
      }

      // 2. Header Bisnis
      setCell(0, 0, 'LAPORAN PENJUALAN KASIR POSAN', isBold: true);
      setCell(0, 1, 'Outlet / Merchant');
      setCell(1, 1, session.merchantName, isBold: true);
      setCell(0, 2, 'Cabang / Lokasi');
      setCell(1, 2, session.outletLocation.isEmpty ? '-' : session.outletLocation);
      setCell(0, 3, 'Kasir Bertugas');
      setCell(1, 3, session.cashierName);
      setCell(0, 4, 'Shift Operasional');
      setCell(1, 4, session.shift);
      setCell(0, 5, 'Waktu Unduh Laporan');
      setCell(1, 5, '$dateFormatted WIB');

      // 3. Ringkasan Eksekutif
      setCell(0, 7, 'RINGKASAN PENJUALAN', isBold: true);
      setCell(0, 8, 'Total Omzet (Gross)');
      setCell(1, 8, totalSales, isBold: true);
      setCell(0, 9, 'Total Tiket / Transaksi');
      setCell(1, 9, totalTrx);
      setCell(0, 10, 'Pembayaran Tunai');
      setCell(1, 10, cashSales);
      setCell(0, 11, 'Pembayaran Non-Tunai');
      setCell(1, 11, nonCashSales);

      // 4. Header Tabel Transaksi
      final headers = [
        'No',
        'No Transaksi',
        'Waktu',
        'Metode Pembayaran',
        'Status',
        'Total Nominal (Rp)',
        'Rincian Menu Pesanan',
      ];

      const tableStartRow = 13;
      for (int c = 0; c < headers.length; c++) {
        setCell(c, tableStartRow, headers[c], isBold: true);
      }

      // 5. Data Transaksi
      for (int i = 0; i < transactions.length; i++) {
        final t = transactions[i];
        final rowIndex = tableStartRow + 1 + i;
        final statusStr = t.syncStatus == SyncStatus.synced ? 'LUNAS (SYNCED)' : 'PENDING';

        setCell(0, rowIndex, i + 1);
        setCell(1, rowIndex, t.id);
        setCell(2, rowIndex, t.time);
        setCell(3, rowIndex, t.paymentMethod.label);
        setCell(4, rowIndex, statusStr);
        setCell(5, rowIndex, t.totalAmount);
        setCell(6, rowIndex, t.itemSummary);
      }

      // 6. Simpan File ke Storage
      final fileBytes = excel.save();
      if (fileBytes == null) return null;

      final directory = await getApplicationDocumentsDirectory();
      final dateSlug = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/Laporan_Penjualan_POSAN_$dateSlug.xlsx';

      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      debugPrint('✅ Sales Report XLSX saved to: $filePath');
      return file;
    } catch (e) {
      debugPrint('❌ Error exporting XLSX report: $e');
      return null;
    }
  }

  /// Menampilkan modal dialog unduh laporan XLSX dan aksi Bagikan/Buka
  static Future<void> showExportReportModal(
    BuildContext context, {
    required CashierSessionModel session,
    required List<RecentTransactionModel> transactions,
  }) async {
    final totalSales = transactions.fold<double>(0, (sum, t) => sum + t.totalAmount);
    final totalTrx = transactions.length;
    final cashCount = transactions.where((t) => t.paymentMethod == TransactionPaymentMethod.cash).length;
    final nonCashCount = totalTrx - cashCount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCCFBE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.table_view_rounded,
                        color: Color(0xFF2E7D32),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unduh Laporan Excel (.xlsx)',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          () {
                            try {
                              return '${session.merchantName} • ${DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now())}';
                            } catch (_) {
                              return '${session.merchantName} • ${DateFormat('dd MMM yyyy').format(DateTime.now())}';
                            }
                          }(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Summary Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F5F0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFECE4D9), width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Omzet Tercatat',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(totalSales),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFFECE4D9), height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jumlah Transaksi',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          '$totalTrx Tiket Transaksi',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Rincian Pembayaran',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          '$cashCount Tunai • $nonCashCount QRIS/Bank',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Export XLSX Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final file = await SalesReportExportService().generateAndSaveXlsxReport(
                      session: session,
                      transactions: transactions,
                    );

                    if (context.mounted) {
                      if (file != null) {
                        // Tampilkan snackbar & bagikan file
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Laporan Excel (.xlsx) berhasil diunduh (${transactions.length} transaksi).',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF2E7D32),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 4),
                            action: SnackBarAction(
                              label: 'BAGIKAN',
                              textColor: Colors.white,
                              onPressed: () {
                                // ignore: deprecated_member_use
                                Share.shareXFiles(
                                  [XFile(file.path)],
                                  text: 'Laporan Penjualan POSAN - ${session.merchantName}',
                                );
                              },
                            ),
                          ),
                        );

                        // Trigger share dialog automatically for immediate access
                        // ignore: deprecated_member_use
                        await Share.shareXFiles(
                          [XFile(file.path)],
                          text: 'Laporan Penjualan POSAN - ${session.merchantName}',
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Gagal membuat file laporan Excel (.xlsx).'),
                            backgroundColor: Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text(
                    'Unduh & Bagikan Format Excel (.xlsx)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
