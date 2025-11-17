import 'package:flutter/material.dart';
import '../../../core/constants/login_constants.dart';

/// Primary button dengan gradient dan loading state
/// Mendukung accessibility dengan semantic labels
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.loadingLabel,
    required this.loading,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String loadingLabel;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Colors.white,
        );

    return Semantics(
      button: true,
      enabled: !loading,
      label: loading ? loadingLabel : label,
      child: SizedBox(
        height: LoginConstants.buttonHeight,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LoginConstants.buttonBorderRadius),
            ),
            padding: EdgeInsets.zero,
            elevation: 0,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: loading
                    ? [Colors.grey.shade400, Colors.grey.shade500]
                    : [const Color(0xFFB31217), const Color(0xFFED213A)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(LoginConstants.buttonBorderRadius),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: LoginConstants.shortDuration,
                child: loading
                    ? Row(
                        key: const ValueKey('loading'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(loadingLabel, style: textStyle),
                        ],
                      )
                    : Row(
                        key: const ValueKey('idle'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.login_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(label, style: textStyle),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
