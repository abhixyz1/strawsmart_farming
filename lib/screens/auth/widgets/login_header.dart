import 'package:flutter/material.dart';
import '../../../core/constants/login_constants.dart';

/// Header logo dan title untuk login screen
/// Ukuran logo responsif berdasarkan tinggi layar
class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final logoSize = LoginConstants.getLogoSize(screenHeight);
    final spacing = LoginConstants.getSpacing(screenHeight);

    return Semantics(
      label: 'StrawSmart Farming Login Header',
      child: Column(
        children: [
          // Logo dengan shadow dan border
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 22,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Hero(
              tag: 'logo',
              child: ClipOval(
                child: Image.asset(
                  'assets/images/icon.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.cover,
                  semanticLabel: 'StrawSmart Logo',
                ),
              ),
            ),
          ),
          SizedBox(height: spacing),
          // Title
          Text(
            'StrawSmart Farming',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing * 0.3),
          // Subtitle - hanya tampil di layar medium/large
          if (screenHeight >= LoginConstants.smallScreenHeight)
            Text(
              'Satu pintu untuk memantau nutrisi, iklim, dan panen stroberi.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
