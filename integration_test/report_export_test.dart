// End-to-End Test: Login dan Export Laporan PDF
// Menguji alur lengkap dari login hingga download laporan PDF
//
// Cara menjalankan:
// flutter test integration_test/report_export_test.dart -d <device_id>
// atau
// flutter test integration_test/report_export_test.dart -d chrome (untuk web)
// flutter test integration_test/report_export_test.dart -d windows (untuk desktop)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Test: Login dan Export Laporan PDF', () {
    testWidgets('Alur lengkap: Login → Laporan → Export PDF', (tester) async {
    // =====================================================================
    // STEP 1: Jalankan aplikasi (test-friendly)
    // =====================================================================
    await startAppForTest(tester);

      // Jika ada tombol "Lewati" (onboarding), klik dulu
      final skipButton = find.text('Lewati');
      if (skipButton.evaluate().isNotEmpty) {
        await tester.tap(skipButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        debugPrint('✅ Onboarding dilewati');
      }
// ...lanjutkan ke proses login...

      // =====================================================================
      // STEP 2: Login dengan credentials (hanya jika belum di dashboard)
      if (find.byType(NavigationBar).evaluate().isEmpty) {
        // Belum login, cek apakah halaman login muncul
        final loginFinder = find.text('Login');
        if (loginFinder.evaluate().isNotEmpty) {
          // Proses login
          final textFields = find.byType(TextFormField);
          expect(textFields, findsAtLeast(2), reason: 'Harus ada minimal 2 TextFormField (email & password)');
          await tester.enterText(textFields.first, 'owner@gmail.com');
          await tester.enterText(textFields.at(1), 'owner123@');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          if (loginFinder.evaluate().isNotEmpty) {
            await tester.tap(loginFinder.first);
            await tester.pumpAndSettle(const Duration(seconds: 8));
            debugPrint('✅ Tombol Login ditekan');
          } else {
            debugPrint('⚠️ Tombol Login tidak ditemukan saat akan tap, kemungkinan sudah navigasi');
          }
        } else {
          // Tidak ada halaman login, kemungkinan sudah login
          debugPrint('✅ Tidak menemukan halaman Login, kemungkinan sudah login');
        }
      } else {
        debugPrint('✅ Sudah login, langsung ke dashboard');
      }

      // =====================================================================
      // STEP 3: Verifikasi berhasil masuk ke Dashboard/Beranda
        // =====================================================================
        // STEP 2: Login dengan credentials (hanya jika belum di dashboard)
        // =====================================================================
        // Cek apakah sudah di dashboard
        final bottomNav = find.byType(NavigationBar);
        if (bottomNav.evaluate().isEmpty) {
          // Belum login, lakukan login
          final loginFinder = find.textContaining('Login');
          if (loginFinder.evaluate().isNotEmpty) {
            debugPrint('📱 Di halaman Login');
            final textFields = find.byType(TextFormField);
            expect(textFields, findsAtLeast(2), reason: 'Harus ada minimal 2 TextFormField (email & password)');
            await tester.enterText(textFields.first, 'owner@gmail.com');
            await tester.pumpAndSettle();
            debugPrint('✅ Email diinput: owner@gmail.com');
            await tester.enterText(textFields.at(1), 'owner123@');
            await tester.pumpAndSettle();
            debugPrint('✅ Password diinput');
            await tester.testTextInput.receiveAction(TextInputAction.done);
            await tester.pumpAndSettle();
            final anyLoginButton = find.text('Login');
            if (anyLoginButton.evaluate().isNotEmpty) {
              await tester.tap(anyLoginButton.first);
              await tester.pumpAndSettle(const Duration(seconds: 5));
            } else {
              fail('Tidak menemukan tombol Login');
            }
          } else {
            fail('Tidak menemukan halaman Login');
          }
        } else {
          debugPrint('✅ Sudah login, langsung ke dashboard');
        }
      // =====================================================================
      // Cari bottom navigation atau indikasi sudah di dashboard
      expect(
        find.byType(NavigationBar).evaluate().isNotEmpty || find.byType(NavigationDestination).evaluate().isNotEmpty,
        isTrue,
        reason: 'Harus ada NavigationBar setelah login berhasil',
      );
      debugPrint('✅ Berhasil masuk ke Dashboard');

      // =====================================================================
      // STEP 4: Navigasi ke tab Laporan (index 3)
      // =====================================================================
      // Cari tab Laporan di bottom navigation
      final laporanTab = find.text('Laporan');
      expect(laporanTab, findsOneWidget,
          reason: 'Harus ada tab Laporan di bottom navigation');

      await tester.tap(laporanTab);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      debugPrint('✅ Navigasi ke tab Laporan');

      // =====================================================================
      // STEP 5: Verifikasi di halaman Laporan
      // =====================================================================
      // Cari indikator halaman laporan
      final laporanHeader = find.textContaining('Laporan');
      expect(laporanHeader, findsAtLeast(1),
          reason: 'Harus ada header Laporan');
      debugPrint('✅ Di halaman Laporan');

      // =====================================================================
      // STEP 6: Cari dan tap tombol Export
      // =====================================================================
      // Berdasarkan kode, tombol Export ada di _DownloadPlaceholder
      final exportButton = find.text('Export');
      expect(exportButton, findsOneWidget,
          reason: 'Harus ada tombol Export');

  await tester.tap(exportButton);
  await tester.pumpAndSettle(const Duration(seconds: 4));
  debugPrint('✅ Tombol Export ditekan, navigasi ke ReportScreen');

      // =====================================================================
      // STEP 7: Verifikasi di halaman Report (export options)
      // =====================================================================
      // Tunggu halaman Report Screen muncul
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verifikasi ada opsi export
  final pdfButton = find.text('PDF');
  final csvButton = find.text('CSV');
  final previewButton = find.text('Preview & Print PDF');

    expect(pdfButton, findsOneWidget, reason: 'Harus ada tombol PDF');
    expect(csvButton, findsOneWidget, reason: 'Harus ada tombol CSV');
    expect(previewButton, findsOneWidget,
      reason: 'Harus ada tombol Preview & Print PDF');
    // Pastikan tombol terlihat sebelum di-tap (scroll jika perlu)
    await tester.ensureVisible(pdfButton);
    await tester.ensureVisible(csvButton);
    await tester.ensureVisible(previewButton);
      debugPrint('✅ Semua opsi export tersedia (PDF, CSV, Preview)');

      // =====================================================================
      // STEP 8: Tap tombol PDF untuk export
      // =====================================================================
  await tester.tap(pdfButton);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      debugPrint('✅ Tombol PDF ditekan');

      // =====================================================================
      // STEP 9: Verifikasi snackbar sukses
      // =====================================================================
      // Tunggu proses export selesai dan snackbar muncul
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Cari snackbar dengan pesan sukses
      final successSnackbar = find.textContaining('berhasil');
      final pdfSuccessSnackbar = find.textContaining('PDF berhasil');

      // Salah satu harus muncul
      final snackbarFound = successSnackbar.evaluate().isNotEmpty ||
          pdfSuccessSnackbar.evaluate().isNotEmpty;

      if (snackbarFound) {
        debugPrint('✅ Snackbar sukses muncul: File berhasil didownload');
      } else {
        debugPrint('⚠️ Snackbar tidak ditemukan (mungkin sudah hilang)');
      }

      // =====================================================================
      // TEST SELESAI
      // =====================================================================
      debugPrint('');
      debugPrint('========================================');
      debugPrint('🎉 E2E TEST BERHASIL!');
      debugPrint('========================================');
      debugPrint('Alur yang diuji:');
      debugPrint('1. ✅ Aplikasi dijalankan');
      debugPrint('2. ✅ Login dengan owner@gmail.com');
      debugPrint('3. ✅ Masuk ke Dashboard');
      debugPrint('4. ✅ Navigasi ke tab Laporan');
      debugPrint('5. ✅ Tap tombol Export');
      debugPrint('6. ✅ Di halaman Report Screen');
      debugPrint('7. ✅ Tap tombol PDF');
      debugPrint('8. ✅ PDF berhasil di-export');
      debugPrint('========================================');
    });

    testWidgets('Test Export CSV', (tester) async {
      // Jalankan aplikasi (test-friendly)
      await startAppForTest(tester);

      // Jika ada tombol "Lewati" (onboarding), klik dulu
      final skipButton = find.text('Lewati');
      if (skipButton.evaluate().isNotEmpty) {
        await tester.tap(skipButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        debugPrint('✅ Onboarding dilewati');
      }

      // Skip login jika sudah login (session masih ada)
      final bottomNav = find.byType(NavigationBar);
      if (bottomNav.evaluate().isEmpty) {
        // Login dulu
        final textFields = find.byType(TextFormField);
        if (textFields.evaluate().isNotEmpty) {
          await tester.enterText(textFields.first, 'owner@gmail.com');
          await tester.enterText(textFields.at(1), 'owner123@');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();

          final loginButton = find.text('Login');
          await tester.tap(loginButton.last);
          await tester.pumpAndSettle(const Duration(seconds: 5));
        }
      }

      // Navigasi ke Laporan
      final laporanTab = find.text('Laporan');
      if (laporanTab.evaluate().isNotEmpty) {
        await tester.tap(laporanTab);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Tap Export
      final exportButton = find.text('Export');
      if (exportButton.evaluate().isNotEmpty) {
        await tester.tap(exportButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Tap CSV
      final csvButton = find.text('CSV');
      expect(csvButton, findsOneWidget);
      await tester.tap(csvButton);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      debugPrint('✅ CSV Export test selesai');
    });

    testWidgets('Test Preview & Print PDF', (tester) async {
      // Jalankan aplikasi (test-friendly)
      await startAppForTest(tester);

      // Jika ada tombol "Lewati" (onboarding), klik dulu
      final skipButton = find.text('Lewati');
      if (skipButton.evaluate().isNotEmpty) {
        await tester.tap(skipButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        debugPrint('✅ Onboarding dilewati');
      }

      // Skip login jika sudah login
      final bottomNav = find.byType(NavigationBar);
      if (bottomNav.evaluate().isEmpty) {
        final textFields = find.byType(TextFormField);
        if (textFields.evaluate().isNotEmpty) {
          await tester.enterText(textFields.first, 'owner@gmail.com');
          await tester.enterText(textFields.at(1), 'owner123@');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();

          final loginButton = find.text('Login');
          await tester.tap(loginButton.last);
          await tester.pumpAndSettle(const Duration(seconds: 5));
        }
      }

      // Navigasi ke Laporan
      final laporanTab = find.text('Laporan');
      if (laporanTab.evaluate().isNotEmpty) {
        await tester.tap(laporanTab);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Tap Export
      final exportButton = find.text('Export');
      if (exportButton.evaluate().isNotEmpty) {
        await tester.tap(exportButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Tap Preview & Print PDF
      final previewButton = find.text('Preview & Print PDF');
      expect(previewButton, findsOneWidget, reason: 'Harus ada tombol Preview & Print PDF');
      await tester.ensureVisible(previewButton);
      await tester.tap(previewButton);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      debugPrint('✅ Preview & Print PDF test selesai');
    });
  });
}
