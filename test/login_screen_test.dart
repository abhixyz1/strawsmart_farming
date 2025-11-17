// Login Screen Widget Test
// Uncomment dan jalankan test ini untuk memvalidasi responsive behavior

/*
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawsmart_farming/screens/auth/login_screen.dart';

void main() {
  testWidgets('Login screen should fit in viewport on iPhone SE portrait', (WidgetTester tester) async {
    // Set screen size to iPhone SE (375x667)
    tester.binding.window.physicalSizeTestValue = const Size(375, 667);
    tester.binding.window.devicePixelRatioTestValue = 2.0;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verifikasi tidak ada overflow
    expect(tester.takeException(), isNull);
    
    // Verifikasi widget penting terlihat
    expect(find.text('StrawSmart Farming'), findsOneWidget);
    expect(find.text('Masuk ke StrawSmart'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Login screen should use landscape layout on wide screens', (WidgetTester tester) async {
    // Set screen size to landscape tablet (900x500)
    tester.binding.window.physicalSizeTestValue = const Size(900, 500);
    tester.binding.window.devicePixelRatioTestValue = 1.0;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi layout horizontal (2 Row dengan Expanded)
    expect(find.byType(Row), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login screen should handle keyboard overlay', (WidgetTester tester) async {
    // Set screen size
    tester.binding.window.physicalSizeTestValue = const Size(375, 667);
    tester.binding.window.devicePixelRatioTestValue = 2.0;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Tap pada email field
    await tester.tap(find.byType(TextFormField).first);
    await tester.pumpAndSettle();

    // Simulate keyboard (300px)
    tester.binding.window.viewInsetsTestValue = const EdgeInsets.only(bottom: 300);
    await tester.pumpAndSettle();

    // Verifikasi tidak ada overflow
    expect(tester.takeException(), isNull);
  });
}
*/
