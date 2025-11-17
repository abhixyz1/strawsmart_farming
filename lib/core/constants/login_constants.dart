import 'package:flutter/material.dart';

/// Login screen constants untuk spacing, sizing, dan durations
/// Menggunakan responsive breakpoints untuk mobile, tablet, dan desktop
class LoginConstants {
  LoginConstants._();

  // Screen breakpoints
  static const double smallScreenHeight = 700.0;
  static const double mediumScreenHeight = 900.0;
  static const double largeScreenWidth = 1024.0;

  // Logo sizes (responsive)
  static const double logoSizeSmall = 70.0;
  static const double logoSizeMedium = 90.0;
  static const double logoSizeLarge = 112.0;

  // Spacing (responsive)
  static const double spacingXSmall = 8.0;
  static const double spacingSmall = 12.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 20.0;
  static const double spacingXLarge = 24.0;

  // Padding
  static const double paddingSmall = 16.0;
  static const double paddingMedium = 20.0;
  static const double paddingLarge = 24.0;

  // Card styling
  static const double cardBorderRadius = 24.0;
  static const double cardPaddingSmall = 20.0;
  static const double cardPaddingMedium = 24.0;
  static const double cardPaddingLarge = 30.0;

  // Input field styling
  static const double inputBorderRadius = 18.0;
  static const double inputFieldHeight = 56.0;

  // Button styling
  static const double buttonHeight = 48.0;
  static const double buttonBorderRadius = 16.0;

  // Animation durations
  static const Duration shortDuration = Duration(milliseconds: 180);
  static const Duration mediumDuration = Duration(milliseconds: 220);
  static const Duration longDuration = Duration(milliseconds: 300);
  static const Duration errorToastDuration = Duration(seconds: 4);

  // Constraints
  static const double maxCardWidth = 480.0;
  static const double maxLayoutWidth = 1200.0;

  // Shadow
  static const double shadowBlurRadius = 28.0;
  static const double shadowOpacity = 0.26;

  // Glassmorphism
  static const double blurSigma = 16.0;
  static const double glassOpacity = 0.96;

  // Helper methods untuk responsive sizing
  static double getLogoSize(double screenHeight) {
    if (screenHeight < smallScreenHeight) return logoSizeSmall;
    if (screenHeight < mediumScreenHeight) return logoSizeMedium;
    return logoSizeLarge;
  }

  static double getVerticalPadding(double screenHeight) {
    if (screenHeight < smallScreenHeight) return paddingSmall;
    if (screenHeight < mediumScreenHeight) return paddingMedium;
    return paddingLarge;
  }

  static double getHorizontalPadding(double screenWidth) {
    if (screenWidth < 400) return paddingSmall;
    return paddingLarge;
  }

  static double getCardPadding(double screenHeight) {
    if (screenHeight < smallScreenHeight) return cardPaddingSmall;
    if (screenHeight < mediumScreenHeight) return cardPaddingMedium;
    return cardPaddingLarge;
  }

  static double getSpacing(double screenHeight) {
    if (screenHeight < smallScreenHeight) return spacingSmall;
    if (screenHeight < mediumScreenHeight) return spacingMedium;
    return spacingLarge;
  }

  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }

  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide >= 600;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= largeScreenWidth;
  }
}
