import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:posan/core/services/attendance_service.dart';
import 'package:posan/models/attendance_model.dart';
import 'package:posan/screens/attendance/attendance_screen.dart';
import 'package:posan/screens/attendance/widgets/attendance_action_buttons.dart';
import 'package:posan/screens/attendance/widgets/attendance_header.dart';
import 'package:posan/screens/attendance/widgets/attendance_history_section.dart';
import 'package:posan/screens/attendance/widgets/attendance_status_card.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('AttendanceService & Model Unit Tests', () {
    late AttendanceService service;

    setUp(() {
      service = AttendanceService();
      service.resetAttendanceForDemo();
    });

    test('Initial attendance state is Belum Absen', () {
      expect(service.todayRecord.status, AttendanceStatus.notCheckedIn);
      expect(service.todayRecord.status.label, 'Belum Absen');
      expect(service.todayRecord.checkInTime, isNull);
      expect(service.todayRecord.checkOutTime, isNull);
      expect(service.canCheckIn, isTrue);
      expect(service.canCheckOut, isFalse);
      expect(service.isCompleted, isFalse);
    });

    test('Check-in updates status to Sedang Bekerja and records time', () async {
      final success = await service.checkIn();
      expect(success, isTrue);
      expect(service.todayRecord.status, AttendanceStatus.working);
      expect(service.todayRecord.status.label, 'Sedang Bekerja');
      expect(service.todayRecord.checkInTime, isNotNull);
      expect(service.canCheckIn, isFalse); // Cannot check-in again
      expect(service.canCheckOut, isTrue);
      expect(service.isCompleted, isFalse);

      // Repeat check-in should fail
      final repeat = await service.checkIn();
      expect(repeat, isFalse);
    });

    test('Check-out updates status to Selesai Bekerja, calculates duration, and adds to history', () async {
      await service.checkIn();
      final initialHistoryCount = service.allHistory.length;

      final success = await service.checkOut();
      expect(success, isTrue);
      expect(service.todayRecord.status, AttendanceStatus.completed);
      expect(service.todayRecord.status.label, 'Selesai Bekerja');
      expect(service.todayRecord.checkOutTime, isNotNull);
      expect(service.canCheckIn, isFalse);
      expect(service.canCheckOut, isFalse); // Cannot check-out again
      expect(service.isCompleted, isTrue);

      // Duration should be non-empty string
      expect(service.todayRecord.formattedDuration, isNot('-'));

      // Added to history
      expect(service.allHistory.length, initialHistoryCount + 1);

      // Repeat check-out should fail
      final repeat = await service.checkOut();
      expect(repeat, isFalse);
    });

    test('History and period filters work properly', () {
      final now = DateTime.now();
      service.addSampleRecordsForTesting([
        AttendanceRecordModel(
          id: 'test-1',
          userId: 'test-user',
          userName: 'Tester',
          role: 'kasir',
          date: now,
          status: AttendanceStatus.completed,
        ),
        AttendanceRecordModel(
          id: 'test-2',
          userId: 'test-user',
          userName: 'Tester',
          role: 'kasir',
          date: now.subtract(const Duration(days: 2)),
          status: AttendanceStatus.completed,
        ),
      ]);

      expect(service.allHistory.length, 2);

      service.setFilterPeriod('all');
      expect(service.filteredHistory.length, service.allHistory.length);

      service.setFilterPeriod('week');
      expect(service.filteredHistory, isNotEmpty);

      service.setFilterPeriod('month');
      expect(service.filteredHistory, isNotEmpty);
    });
  });

  group('AttendanceScreen UI & Interaction Widget Tests', () {
    late AttendanceService service;

    setUp(() {
      service = AttendanceService();
      service.resetAttendanceForDemo();
    });

    testWidgets('AttendanceScreen renders Header, Status Card, Action Buttons and History',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AttendanceScreen(isStandalone: false),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.byType(AttendanceHeader), findsOneWidget);
      expect(find.text('Absensi'), findsOneWidget);
      expect(find.text('WIB • Waktu Perangkat'), findsOneWidget);

      // Verify Status Card
      expect(find.byType(AttendanceStatusCard), findsOneWidget);
      expect(find.text('Status Hari Ini'), findsOneWidget);
      expect(find.text('Belum Absen'), findsWidgets);
      expect(find.text('Jam Masuk'), findsOneWidget);
      expect(find.text('Jam Keluar'), findsOneWidget);
      expect(find.text('Durasi Kerja'), findsOneWidget);

      // Verify Action Buttons
      expect(find.byType(AttendanceActionButtons), findsOneWidget);
      expect(find.text('Absen Masuk'), findsOneWidget);
      expect(find.text('Absen Keluar'), findsOneWidget);

      // Verify History Section
      expect(find.byType(AttendanceHistorySection), findsOneWidget);
      expect(find.text('Riwayat Absensi'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Minggu Ini'), findsOneWidget);
      expect(find.text('Bulan Ini'), findsOneWidget);
    });

    testWidgets('Absen Masuk flow: Confirmation Dialog -> Sedang Bekerja -> Updates UI',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AttendanceScreen(isStandalone: false),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: Absen Masuk is enabled, tap it
      await tester.tap(find.text('Absen Masuk'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear with exact prompt requirements
      expect(find.text('Konfirmasi Absen Masuk'), findsOneWidget);
      expect(find.text('Apakah kamu yakin ingin mencatat waktu masuk sekarang?'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Ya, Absen Masuk'), findsOneWidget);

      // Confirm check-in
      await tester.tap(find.text('Ya, Absen Masuk'));
      await tester.pumpAndSettle();

      // Status should now be "Sedang Bekerja"
      expect(find.text('Sedang Bekerja'), findsWidgets);
      expect(find.text('Sudah Masuk'), findsOneWidget);
      expect(service.todayRecord.status, AttendanceStatus.working);
    });

    testWidgets('Absen Keluar flow: Confirmation Dialog -> Selesai Bekerja -> Updates Duration',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Perform check in first
      await service.checkIn();

      await tester.pumpWidget(
        const MaterialApp(
          home: AttendanceScreen(isStandalone: false),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Absen Keluar
      await tester.tap(find.text('Absen Keluar'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear with exact prompt requirements
      expect(find.text('Konfirmasi Absen Keluar'), findsOneWidget);
      expect(find.text('Apakah kamu yakin ingin mengakhiri sesi kerja hari ini?'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Ya, Absen Keluar'), findsOneWidget);

      // Confirm check-out
      await tester.tap(find.text('Ya, Absen Keluar'));
      await tester.pumpAndSettle();

      // Status should now be "Selesai Bekerja"
      expect(find.text('Selesai Bekerja'), findsWidgets);
      expect(find.text('Sudah Keluar'), findsOneWidget);
      expect(service.todayRecord.status, AttendanceStatus.completed);
    });

    testWidgets('Dialog Batal does not alter attendance status',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AttendanceScreen(isStandalone: false),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Absen Masuk -> dialog appears
      await tester.tap(find.text('Absen Masuk'));
      await tester.pumpAndSettle();

      // Tap Batal
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      // Dialog is dismissed and status remains Belum Absen
      expect(find.text('Konfirmasi Absen Masuk'), findsNothing);
      expect(service.todayRecord.status, AttendanceStatus.notCheckedIn);
    });

    testWidgets('AttendanceScreen renders properly on Tablet / Wide screen',
        (WidgetTester tester) async {
      // Tablet landscape resolution (1280 x 800)
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AttendanceScreen(isStandalone: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AttendanceHeader), findsOneWidget);
      expect(find.byType(AttendanceStatusCard), findsOneWidget);
      expect(find.byType(AttendanceActionButtons), findsOneWidget);
      expect(find.byType(AttendanceHistorySection), findsOneWidget);
    });

    testWidgets('Empty history displays "Belum ada riwayat absensi."',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      service.clearHistoryForDemo();

      await tester.pumpWidget(
        const MaterialApp(
          home: AttendanceScreen(isStandalone: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada riwayat absensi.'), findsOneWidget);
    });
  });
}

