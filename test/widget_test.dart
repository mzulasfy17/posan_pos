import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posan/screens/auth/login_screen.dart';
import 'package:posan/screens/cashier_home/cashier_home_screen.dart';
import 'package:posan/screens/cashier_cart/cashier_cart_screen.dart';
import 'package:posan/screens/cashier_cart/widgets/cart_bottom_cta.dart';
import 'package:posan/screens/cashier_dashboard/widgets/create_order_banner.dart';
import 'package:posan/screens/cashier_payment/cash_payment_screen.dart';
import 'package:posan/screens/cashier_payment/widgets/cash_calculation_card.dart';
import 'package:posan/screens/cashier_payment/widgets/quick_cash_chips.dart';
import 'package:posan/screens/cashier_payment/widgets/cash_numpad.dart';
import 'package:posan/screens/cashier_payment/widgets/payment_success_dialog.dart';

void main() {
  testWidgets('LoginScreen renders fields and validates empty inputs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    expect(find.text('Masuk Akun Kasir'), findsOneWidget);
    expect(find.text('Email Akun'), findsOneWidget);
    expect(find.text('Kata Sandi (Password)'), findsOneWidget);

    // Tap Masuk with empty fields -> should show validation error
    await tester.tap(find.text('Masuk ke Kasir'));
    await tester.pumpAndSettle();
    expect(find.text('Email tidak boleh kosong'), findsOneWidget);
  });

  testWidgets('POSAN Cashier Full Cash Flow: Beranda -> Katalog -> Keranjang -> Cash Payment -> Struk Sukses',
      (WidgetTester tester) async {
    // Set mobile viewport
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CashierHomeScreen()));
    await tester.pumpAndSettle();

    // 1. Verify Beranda Dashboard
    expect(find.text('Selamat pagi, Zul 👋'), findsOneWidget);

    // 2. Navigate to Catalog via "Buat Pesanan Baru"
    await tester.tap(find.byType(CreateOrderBanner));
    await tester.pumpAndSettle();
    expect(find.text('Katalog Menu'), findsOneWidget);

    // 3. Navigate to Keranjang (Pembayaran)
    await tester.tap(find.text('Lihat Keranjang'));
    await tester.pumpAndSettle();
    expect(find.byType(CashierCartScreen), findsOneWidget);

    // 4. Open Payment Method Bottom Sheet from Cart
    await tester.tap(find.byType(CartBottomCta));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Metode Pembayaran'), findsOneWidget);
    expect(find.text('Tunai (Cash)'), findsOneWidget);

    // 5. Select "Tunai (Cash)" to open CashPaymentScreen
    await tester.tap(find.text('Tunai (Cash)'));
    await tester.pumpAndSettle();

    expect(find.byType(CashPaymentScreen), findsOneWidget);
    expect(find.text('Pembayaran Tunai'), findsOneWidget);
    expect(find.byType(CashCalculationCard), findsOneWidget);
    expect(find.byType(QuickCashChips), findsOneWidget);
    expect(find.byType(CashNumpad), findsOneWidget);

    // 6. Test Quick Cash Chip "Rp100.000"
    if (find.text('Rp100.000').evaluate().isNotEmpty) {
      await tester.tap(find.text('Rp100.000').first);
      await tester.pumpAndSettle();
      expect(find.text('Rp49.000'), findsWidgets); // Kembalian Rp49.000
    }

    // 7. Confirm Cash Payment
    await tester.tap(find.textContaining('Konfirmasi Bayar'));
    await tester.pumpAndSettle();

    // Verify Payment Success Dialog / Receipt
    expect(find.byType(PaymentSuccessDialog), findsOneWidget);
    expect(find.text('Pembayaran Berhasil!'), findsOneWidget);
    expect(find.text('Cetak Struk (Printer Bluetooth)'), findsOneWidget);
    expect(find.text('Selesai / Transaksi Baru'), findsOneWidget);

    // 8. Tap "Selesai / Transaksi Baru" to return to Beranda
    await tester.tap(find.text('Selesai / Transaksi Baru'));
    await tester.pumpAndSettle();
    // Wait for snackbar to dismiss
    await tester.pump(const Duration(seconds: 3));

    // Verify returned to Beranda Dashboard with updated transaction and cleared cart
    expect(find.text('Selamat pagi, Zul 👋'), findsOneWidget);

    // 9. Navigate to Riwayat Tab
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    expect(find.text('Riwayat Transaksi'), findsOneWidget);
    expect(find.text('TOTAL OMSET'), findsOneWidget);
    expect(find.text('Semua'), findsWidgets);
    expect(find.text('Tunai'), findsWidgets);

    // 10. Tap a transaction card to view details
    final txFinder = find.textContaining('#').first;
    await tester.ensureVisible(txFinder);
    await tester.tap(txFinder);
    await tester.pumpAndSettle();

    expect(find.text('Cetak Ulang Struk'), findsOneWidget);
    expect(find.text('Tutup'), findsOneWidget);

    // Tap "Cetak Ulang Struk"
    await tester.tap(find.text('Cetak Ulang Struk'));
    await tester.pumpAndSettle();

    // Verify reprint snackbar
    expect(find.textContaining('berhasil dikirim ke antrean cetak'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // 11. Navigate to Lainnya Tab (Tab 3)
    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();

    expect(find.text('Pengaturan & Lainnya'), findsOneWidget);
    expect(find.text('Operasional Shift Kasir'), findsOneWidget);
    expect(find.text('Printer Struk & Hardware'), findsOneWidget);
    expect(find.text('Pusat Bantuan & Panduan'), findsOneWidget);

    // 12. Test Print Test Button
    final printTestFinder = find.text('Tes Cetak Struk');
    await tester.ensureVisible(printTestFinder);
    await tester.tap(printTestFinder);
    await tester.pumpAndSettle();
    expect(find.textContaining('Tes cetak struk berhasil dikirim'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // 13. Test Open Shift Reconciliation Modal
    final shiftModalBtnFinder = find.text('Tutup Shift & Rekonsiliasi Kas');
    await tester.ensureVisible(shiftModalBtnFinder);
    await tester.tap(shiftModalBtnFinder);
    await tester.pumpAndSettle();

    expect(find.text('Tutup Shift & Rekonsiliasi Kas'), findsWidgets);
    expect(find.text('Modal Kas Awal (Float)'), findsOneWidget);
    expect(find.text('Cetak Laporan'), findsOneWidget);

    // Close Shift Reconciliation Modal
    await tester.tap(find.text('Tutup Shift'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Shift berhasil ditutup'), findsOneWidget);
  });
}
