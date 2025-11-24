import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/login_constants.dart';

/// Success toast dengan auto-dismiss dan subtle animation
/// Otomatis hilang setelah 6 detik (lebih lama dari error untuk baca instruksi)
class SuccessToast extends StatefulWidget {
  const SuccessToast({
    required this.message,
    this.onDismiss,
    super.key,
  });

  final String message;
  final VoidCallback? onDismiss;

  @override
  State<SuccessToast> createState() => _SuccessToastState();
}

class _SuccessToastState extends State<SuccessToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    // Setup fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Trigger fade-in animation
    _fadeController.forward();

    // Auto-dismiss setelah 6 detik (lebih lama untuk success message)
    _dismissTimer = Timer(const Duration(seconds: 6), () {
      widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Semantics(
        liveRegion: true,
        label: 'Sukses: ${widget.message}',
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LoginConstants.inputBorderRadius),
            border: Border.all(
              color: Colors.green.shade300.withValues(alpha: 0.4),
              width: 1.5,
            ),
            gradient: LinearGradient(
              colors: [
                Colors.green.shade50.withValues(alpha: 0.9),
                Colors.teal.shade50.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.shade100.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.green.shade700,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
