import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SmoothSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: _SmoothSlidePageTransitionsBuilder(),
          TargetPlatform.linux: _SmoothSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: _SmoothSlidePageTransitionsBuilder(),
          TargetPlatform.windows: _SmoothSlidePageTransitionsBuilder(),
          TargetPlatform.fuchsia: _SmoothSlidePageTransitionsBuilder(),
        },
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFBE3A34),
        brightness: Brightness.light,
        primary: const Color(0xFFBE3A34),
        secondary: const Color(0xFFE46852),
        tertiary: const Color(0xFFFFF0E8),
        surface: Colors.white,
        surfaceContainerHighest: const Color(0xFFFFF4EA),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFF5F0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBE3A34), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textTheme: GoogleFonts.urbanistTextTheme().apply(
        bodyColor: const Color(0xFF3D1B16),
        displayColor: const Color(0xFF3D1B16),
      ),
    );
  }

  // ==================== DARK THEME ====================
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SmoothSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: _SmoothSlidePageTransitionsBuilder(),
          TargetPlatform.linux: _SmoothSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: _SmoothSlidePageTransitionsBuilder(),
          TargetPlatform.windows: _SmoothSlidePageTransitionsBuilder(),
          TargetPlatform.fuchsia: _SmoothSlidePageTransitionsBuilder(),
        },
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFBE3A34),
        brightness: Brightness.dark,
        primary: const Color(0xFFFF8B6F),
        secondary: const Color(0xFFFFB796),
        tertiary: const Color(0xFF3B201F),
        surface: const Color(0xFF1A1B1C),
        surfaceContainerHighest: const Color(0xFF2B1F1E),
        onSurface: const Color(0xFFE6E0DD),
        onSurfaceVariant: const Color(0xFFB8ADA8),
        outline: const Color(0xFF4C3C3A),
      ),
      // Card theme for dark mode
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF2B2D30), // Dark card background
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Input decoration for dark mode
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A1D1C), // Dark input background
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF8B6F), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      // Button themes for dark mode
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF8B6F),
          foregroundColor: const Color(0xFF1A1B1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF8B6F),
          side: const BorderSide(color: Color(0xFFFF8B6F)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      // App bar theme for dark mode
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1C1E),
        foregroundColor: Color(0xFFE3E3E3),
        elevation: 0,
      ),
      // Bottom navigation theme for dark mode
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF2B2D30),
        selectedItemColor: Color(0xFF88B39E),
        unselectedItemColor: Color(0xFF888888),
        elevation: 0,
      ),
      // Text theme with Poppins font
      textTheme: GoogleFonts.urbanistTextTheme(ThemeData.dark().textTheme)
          .apply(
            bodyColor: const Color(0xFFF4EAE6),
            displayColor: const Color(0xFFF4EAE6),
          ),
      // Icon theme
      iconTheme: const IconThemeData(color: Color(0xFFE3E3E3)),
    );
  }
}

class _SmoothSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Use a more pronounced curve for better visibility
    const curve = Curves.easeOutQuart;

    final slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Slide from right
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: curve));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeIn));

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(opacity: fadeAnimation, child: child),
    );
  }
}
