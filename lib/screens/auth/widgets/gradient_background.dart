import 'package:flutter/material.dart';

/// Gradient background dengan image overlay dan glow effects
/// Menggunakan RepaintBoundary untuk optimasi performa
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/images/homestrawberry.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: const Color(0xFF0F2027));
            },
          ),
          // Gradient overlay
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xEE0F2027),
                  Color(0xCC203A43),
                  Color(0xDD2C5364),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Glow effects
          Positioned(
            top: -60,
            right: -20,
            child: _GlowBlob(
              size: 220,
              color: const Color(0xFF5EFCE8).withOpacity(0.45),
              intensity: 0.04,
            ),
          ),
          Positioned(
            bottom: -40,
            left: -30,
            child: _GlowBlob(
              size: 260,
              color: const Color(0xFF736EFE).withOpacity(0.4),
              intensity: 0.04,
            ),
          ),
        ],
      ),
    );
  }
}

/// Glow blob effect untuk background
class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.size,
    required this.color,
    this.intensity = 0.04,
  });

  final double size;
  final Color color;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withOpacity(intensity),
            ],
          ),
        ),
      ),
    );
  }
}
