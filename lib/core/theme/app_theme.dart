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
        seedColor: const Color(0xFF6B9080), // Soft green
        brightness: Brightness.light,
        primary: const Color(0xFF6B9080),
        secondary: const Color(0xFFA4C3B2),
        tertiary: const Color(0xFFEAF4F4),
        surface: Colors.white,
        surfaceContainerHighest: const Color(0xFFF6F8F7),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF6F8F7),
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
          borderSide: const BorderSide(color: Color(0xFF6B9080), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      textTheme: GoogleFonts.poppinsTextTheme(),
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
        seedColor: const Color(0xFF6B9080), // Soft green
        brightness: Brightness.dark,
        // Dark mode specific colors
        primary: const Color(0xFF88B39E), // Lighter green for better contrast
        secondary: const Color(0xFFB5D4C6),
        tertiary: const Color(0xFF2C3E3A),
        surface: const Color(0xFF1A1C1E), // Dark background
        surfaceContainerHighest: const Color(0xFF2B2D30), // Slightly lighter for cards
        onSurface: const Color(0xFFE3E3E3), // Light text
        onSurfaceVariant: const Color(0xFFB8B8B8), // Secondary text
        outline: const Color(0xFF4A4A4A), // Borders
      ),
      // Card theme for dark mode
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF2B2D30), // Dark card background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      // Input decoration for dark mode
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2B2D30), // Dark input background
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
          borderSide: const BorderSide(color: Color(0xFF88B39E), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      // Button themes for dark mode
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF88B39E),
          foregroundColor: const Color(0xFF1A1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF88B39E),
          side: const BorderSide(color: Color(0xFF88B39E)),
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
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: const Color(0xFFE3E3E3),
        displayColor: const Color(0xFFE3E3E3),
      ),
      // Icon theme
      iconTheme: const IconThemeData(
        color: Color(0xFFE3E3E3),
      ),
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
    ).animate(CurvedAnimation(
      parent: animation,
      curve: curve,
    ));

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeIn,
    ));

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: child,
      ),
    );
  }
}