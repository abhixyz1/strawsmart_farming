import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/login_constants.dart';

/// Error toast dengan auto-dismiss dan shake animation
/// Otomatis hilang setelah 4 detik
class ErrorToast extends StatefulWidget {
  const ErrorToast({
    required this.message,
    this.onDismiss,
    super.key,
  });

  final String message;
  final VoidCallback? onDismiss;

  @override
  State<ErrorToast> createState() => _ErrorToastState();
}

class _ErrorToastState extends State<ErrorToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    // Setup shake animation
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticIn,
      ),
    );

    // Trigger shake animation
    _shakeController.forward();

    // Auto-dismiss setelah 4 detik
    _dismissTimer = Timer(LoginConstants.errorToastDuration, () {
      widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value * (1 - _shakeController.value), 0),
          child: child,
        );
      },
      child: Semantics(
        liveRegion: true,
        label: 'Error: ${widget.message}',
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LoginConstants.inputBorderRadius),
            border: Border.all(color: Colors.redAccent.withOpacity(0.45)),
            gradient: LinearGradient(
              colors: [
                Colors.redAccent.withOpacity(0.14),
                Colors.red.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
