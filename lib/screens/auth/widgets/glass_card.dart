import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/login_constants.dart';

/// Glass morphism card dengan backdrop filter
/// Menggunakan RepaintBoundary untuk optimasi performa
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LoginConstants.cardBorderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: LoginConstants.blurSigma,
            sigmaY: LoginConstants.blurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(LoginConstants.glassOpacity),
              borderRadius: BorderRadius.circular(LoginConstants.cardBorderRadius),
              border: Border.all(color: Colors.white.withOpacity(0.7)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: LoginConstants.shadowBlurRadius,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
