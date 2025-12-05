import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/user_profile_repository.dart';
import '../dashboard_repository.dart';

// ============================================================================
// PUMP CONTROL CARD - Modern Visual Design with Animated Elements
// ============================================================================

class PumpControlCard extends ConsumerStatefulWidget {
  const PumpControlCard({
    super.key,
    required this.status,
    required this.pump,
    required this.controlMode,
    required this.runtimeLabel,
    required this.isSendingPump,
    required this.isUpdatingMode,
    required this.onPumpToggle,
    required this.onModeChange,
    required this.onRefresh,
  });

  final DeviceStatusData? status;
  final PumpStatusData pump;
  final ControlMode controlMode;
  final String? runtimeLabel;
  final bool isSendingPump;
  final bool isUpdatingMode;
  final ValueChanged<bool> onPumpToggle;
  final ValueChanged<ControlMode> onModeChange;
  final VoidCallback onRefresh;

  // Theme colors - Strawberry Rose (soft red-pink)
  static const _primaryRose = Color(0xFFE57373);

  @override
  ConsumerState<PumpControlCard> createState() => _PumpControlCardState();
}

class _PumpControlCardState extends ConsumerState<PumpControlCard> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(PumpControlCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate when pump is on
    if (widget.pump.isOn && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.pump.isOn && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = widget.status?.isDeviceOnline ?? false;

    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final canControlPump = profile?.role.canControlPump ?? false;
    final canTogglePump = !widget.isSendingPump && online && canControlPump;
    final isViewOnly = widget.controlMode == ControlMode.auto || !canControlPump;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.06).round()),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Hero Section - Visual Pump Status
          _buildHeroSection(context, theme, canControlPump, canTogglePump, isViewOnly),
          // Bottom Controls
          _buildBottomSection(context, theme, canControlPump),
        ],
      ),
    );
  }

  // ============================================================================
  // HERO SECTION - Big visual pump status
  // ============================================================================

  Widget _buildHeroSection(BuildContext context, ThemeData theme, 
      bool canControl, bool canToggle, bool isViewOnly) {
    final isPumpOn = widget.pump.isOn;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPumpOn
              ? [const Color(0xFF4CAF50), const Color(0xFF388E3C)]
              : [
                  theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.surfaceContainerHigh,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Mode badge row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status indicators
              Row(
                children: [
                  _buildStatusDot(
                    isActive: widget.status?.isDeviceOnline ?? false,
                    activeColor: const Color(0xFF66BB6A),
                    inactiveColor: const Color(0xFFEF5350),
                    activeLabel: 'Online',
                    inactiveLabel: 'Offline',
                    isPumpOn: isPumpOn,
                  ),
                  const SizedBox(width: 16),
                  _buildStatusDot(
                    isActive: widget.status?.autoLogicEnabled ?? false,
                    activeColor: const Color(0xFF9575CD),
                    inactiveColor: Colors.grey,
                    activeLabel: 'Fuzzy',
                    inactiveLabel: 'Fuzzy',
                    isPumpOn: isPumpOn,
                  ),
                ],
              ),
              // Mode badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPumpOn 
                      ? Colors.white.withAlpha((255 * 0.2).round())
                      : theme.colorScheme.outline.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.controlMode == ControlMode.auto ? 'AUTO' : 'MANUAL',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isPumpOn ? Colors.white : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Big pump button
          _buildBigPumpButton(context, theme, isPumpOn, canToggle, isViewOnly),
          const SizedBox(height: 16),
          // Status text
          Text(
            isPumpOn ? 'Pompa Aktif' : 'Pompa Mati',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: isPumpOn ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.runtimeLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.runtimeLabel!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isPumpOn ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBigPumpButton(BuildContext context, ThemeData theme, 
      bool isPumpOn, bool canToggle, bool isViewOnly) {
    
    final buttonSize = 100.0;
    final isInteractive = canToggle && !isViewOnly;
    
    return GestureDetector(
      onTapDown: isInteractive ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isInteractive ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isInteractive ? () => setState(() => _isPressed = false) : null,
      onTap: isInteractive
          ? () {
              HapticFeedback.mediumImpact();
              widget.onPumpToggle(!isPumpOn);
            }
          : null,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final baseScale = isPumpOn ? _pulseAnimation.value : 1.0;
          final pressScale = _isPressed ? 0.92 : 1.0;
          return Transform.scale(
            scale: baseScale * pressScale,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isPumpOn
                ? const LinearGradient(
                    colors: [Colors.white, Color(0xFFE8F5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: isInteractive
                        ? [
                            PumpControlCard._primaryRose.withAlpha((255 * 0.1).round()),
                            PumpControlCard._primaryRose.withAlpha((255 * 0.05).round()),
                          ]
                        : [
                            theme.colorScheme.surface,
                            theme.colorScheme.surfaceContainerLow,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: isInteractive && !isPumpOn
                ? Border.all(
                    color: PumpControlCard._primaryRose.withAlpha((255 * 0.5).round()),
                    width: 2,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: isPumpOn
                    ? const Color(0xFF4CAF50).withAlpha((255 * 0.4).round())
                    : isInteractive
                        ? PumpControlCard._primaryRose.withAlpha((255 * 0.2).round())
                        : Colors.black.withAlpha((255 * 0.1).round()),
                blurRadius: isPumpOn ? 24 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Water drops animation ring
              if (isPumpOn)
                ...List.generate(3, (index) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.8, end: 1.3),
                    duration: Duration(milliseconds: 1500 + (index * 300)),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Container(
                        width: buttonSize * value,
                        height: buttonSize * value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF4CAF50).withAlpha(
                              (255 * (1.3 - value) * 0.5).round().clamp(0, 255),
                            ),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  );
                }),
              // Icon
              Icon(
                isPumpOn ? Icons.waves_rounded : Icons.power_settings_new_rounded,
                size: 40,
                color: isPumpOn 
                    ? const Color(0xFF4CAF50)
                    : (canToggle && !isViewOnly)
                        ? PumpControlCard._primaryRose
                        : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // BOTTOM SECTION - Controls
  // ============================================================================

  Widget _buildBottomSection(BuildContext context, ThemeData theme, bool canControl) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Mode toggle
          if (canControl) _buildModeToggle(context, theme),
          if (!canControl) _buildViewOnlyBanner(context, theme),
        ],
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context, ThemeData theme) {
    final isAuto = widget.controlMode == ControlMode.auto;
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeOption(
              context, theme,
              icon: Icons.auto_awesome_rounded,
              label: 'Otomatis',
              isSelected: isAuto,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onModeChange(ControlMode.auto);
              },
            ),
          ),
          Expanded(
            child: _buildModeOption(
              context, theme,
              icon: Icons.touch_app_rounded,
              label: 'Manual',
              isSelected: !isAuto,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onModeChange(ControlMode.manual);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(BuildContext context, ThemeData theme, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: widget.isUpdatingMode ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.05).round()),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected 
                  ? PumpControlCard._primaryRose 
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected 
                    ? theme.colorScheme.onSurface 
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewOnlyBanner(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.visibility_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'Mode monitoring',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Status dot for hero section header
  Widget _buildStatusDot({
    required bool isActive,
    required Color activeColor,
    Color? inactiveColor,
    required String activeLabel,
    String? inactiveLabel,
    required bool isPumpOn,
  }) {
    final label = isActive ? activeLabel : (inactiveLabel ?? activeLabel);
    final dotColor = isActive 
        ? activeColor 
        : (isPumpOn 
            ? (inactiveColor ?? Colors.grey).withAlpha((255 * 0.7).round())
            : (inactiveColor ?? Colors.grey).withAlpha((255 * 0.5).round()));
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withAlpha((255 * 0.4).round()),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isPumpOn 
                ? (isActive ? Colors.white70 : Colors.white60)
                : (isActive ? Colors.grey[700] : Colors.grey[500]),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
