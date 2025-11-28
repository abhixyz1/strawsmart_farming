import 'package:flutter/material.dart';

/// Custom page route dengan animasi fade dan slide
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  FadeSlidePageRoute({
    required Widget page,
    super.settings,
  }) : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: curvedAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}

/// Custom page route dengan animasi scale untuk dialog-like screens
class ScalePageRoute<T> extends PageRouteBuilder<T> {
  ScalePageRoute({
    required Widget page,
    super.settings,
  }) : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            );

            return ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
              child: FadeTransition(
                opacity: curvedAnimation,
                child: child,
              ),
            );
          },
        );
}

/// Extension untuk navigasi dengan animasi
extension NavigatorExtension on BuildContext {
  /// Push dengan animasi fade slide
  Future<T?> pushFadeSlide<T>(Widget page) {
    return Navigator.push<T>(this, FadeSlidePageRoute(page: page));
  }

  /// Push dengan animasi scale
  Future<T?> pushScale<T>(Widget page) {
    return Navigator.push<T>(this, ScalePageRoute(page: page));
  }
}
