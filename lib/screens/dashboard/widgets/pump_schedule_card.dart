import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/user_profile_repository.dart';
import '../dashboard_repository.dart';

// ============================================================================
// PUMP + SCHEDULE CARD - Integrated Modern Design
// ============================================================================

class PumpScheduleCard extends ConsumerStatefulWidget {
  const PumpScheduleCard({
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
  static const _darkRose = Color(0xFFD32F2F);
  static const _lightRose = Color(0xFFFFCDD2);
  static const _accentTeal = Color(0xFF26A69A);

  @override
  ConsumerState<PumpScheduleCard> createState() => _PumpScheduleCardState();
}

class _PumpScheduleCardState extends ConsumerState<PumpScheduleCard> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isPressed = false;
  
  // Notification preference
  bool _notificationEnabled = true;
  static const _notificationPrefKey = 'schedule_notification_enabled';
  
  // Stabilized online status - MORE ROBUST
  bool _stableOnlineStatus = false;
  DateTime? _lastDataReceivedTime;
  Timer? _offlineCheckTimer;
  static const _offlineThreshold = Duration(seconds: 90);
  static const _checkInterval = Duration(seconds: 5);

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
    
    // Load notification preference
    _loadNotificationPreference();
    
    // Initialize stable status from widget
    _updateOnlineStatusFromData();
    
    // Start periodic offline check timer
    _offlineCheckTimer = Timer.periodic(_checkInterval, (_) {
      _checkIfDeviceWentOffline();
    });
  }
  
  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationEnabled = prefs.getBool(_notificationPrefKey) ?? true;
    });
  }
  
  Future<void> _toggleNotification() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationEnabled = !_notificationEnabled;
    });
    await prefs.setBool(_notificationPrefKey, _notificationEnabled);
    
    HapticFeedback.lightImpact();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _notificationEnabled 
                ? 'Notifikasi jadwal penyiraman diaktifkan' 
                : 'Notifikasi jadwal penyiraman dinonaktifkan',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  /// Update online status when new data arrives
  void _updateOnlineStatusFromData() {
    final statusLastReceived = widget.status?.lastReceivedTime;
    
    if (statusLastReceived != null) {
      _lastDataReceivedTime = statusLastReceived;
      
      // Check if this data is fresh (within threshold)
      final diff = DateTime.now().difference(statusLastReceived);
      final isOnline = diff <= _offlineThreshold;
      
      if (isOnline != _stableOnlineStatus) {
        setState(() {
          _stableOnlineStatus = isOnline;
        });
      }
    }
  }
  
  /// Periodically check if device went offline (no new data)
  void _checkIfDeviceWentOffline() {
    if (_lastDataReceivedTime == null) return;
    
    final diff = DateTime.now().difference(_lastDataReceivedTime!);
    final shouldBeOffline = diff > _offlineThreshold;
    
    if (shouldBeOffline && _stableOnlineStatus) {
      setState(() {
        _stableOnlineStatus = false;
      });
    }
  }

  @override
  void didUpdateWidget(PumpScheduleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if we received new data
    final oldLastReceived = oldWidget.status?.lastReceivedTime;
    final newLastReceived = widget.status?.lastReceivedTime;
    
    // Only update if we have genuinely new data
    if (newLastReceived != null && 
        (oldLastReceived == null || newLastReceived.isAfter(oldLastReceived))) {
      _updateOnlineStatusFromData();
    }
    
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
    _offlineCheckTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final online = _stableOnlineStatus;

    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final canControlPump = profile?.role.canControlPump ?? false;
    final canTogglePump = !widget.isSendingPump && online && canControlPump;
    final isViewOnly = widget.controlMode == ControlMode.auto || !canControlPump;
    
    // Watch schedule
    final scheduleAsync = ref.watch(wateringScheduleProvider);

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
          // Mode Controls
          _buildModeSection(context, theme, canControlPump),
          // Schedule Section (integrated)
          scheduleAsync.when(
            data: (schedule) {
              if (schedule == null || !schedule.enabled) {
                return const SizedBox.shrink();
              }
              return _buildScheduleSection(context, theme, isDark, schedule);
            },
            loading: () => _buildScheduleLoading(theme, isDark),
            error: (_, __) => const SizedBox.shrink(),
          ),
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
    final isOnline = _stableOnlineStatus;
    
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
                    isActive: isOnline,
                    activeColor: const Color(0xFF66BB6A),
                    inactiveColor: const Color(0xFFEF5350),
                    activeLabel: 'Online',
                    inactiveLabel: 'Offline',
                    isPumpOn: isPumpOn,
                  ),
                  const SizedBox(width: 16),
                  _buildStatusDot(
                    isActive: (widget.status?.autoLogicEnabled ?? false) && isOnline,
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
    
    const buttonSize = 100.0;
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
                            PumpScheduleCard._primaryRose.withAlpha((255 * 0.1).round()),
                            PumpScheduleCard._primaryRose.withAlpha((255 * 0.05).round()),
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
                    color: PumpScheduleCard._primaryRose.withAlpha((255 * 0.5).round()),
                    width: 2,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: isPumpOn
                    ? const Color(0xFF4CAF50).withAlpha((255 * 0.4).round())
                    : isInteractive
                        ? PumpScheduleCard._primaryRose.withAlpha((255 * 0.2).round())
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
                        ? PumpScheduleCard._primaryRose
                        : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // MODE SECTION
  // ============================================================================

  Widget _buildModeSection(BuildContext context, ThemeData theme, bool canControl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
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
                  ? PumpScheduleCard._primaryRose 
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

  // ============================================================================
  // SCHEDULE SECTION (Integrated below pump)
  // ============================================================================

  Widget _buildScheduleSection(
    BuildContext context, 
    ThemeData theme, 
    bool isDark,
    WateringScheduleData schedule,
  ) {
    final nextTime = schedule.nextScheduledTime;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF3D3232), const Color(0xFF4A3A3A)]
              : [PumpScheduleCard._lightRose.withAlpha(180), PumpScheduleCard._lightRose],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark 
              ? PumpScheduleCard._darkRose.withAlpha(50)
              : PumpScheduleCard._primaryRose.withAlpha(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with notification toggle
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 20,
                color: isDark ? PumpScheduleCard._lightRose : PumpScheduleCard._darkRose,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Jadwal Penyiraman',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : PumpScheduleCard._darkRose,
                  ),
                ),
              ),
              // Notification toggle
              GestureDetector(
                onTap: _toggleNotification,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _notificationEnabled
                        ? PumpScheduleCard._accentTeal.withAlpha(30)
                        : Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _notificationEnabled 
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    size: 18,
                    color: _notificationEnabled
                        ? PumpScheduleCard._accentTeal
                        : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 14),
          
          // Moisture threshold info (moved to top)
          if (schedule.moistureThreshold?.enabled == true) ...[
            _buildMoistureThresholdInfo(theme, isDark, schedule.moistureThreshold!),
            const SizedBox(height: 12),
          ],
          
          // Next watering time
          if (nextTime != null) ...[
            _buildNextWateringInfo(theme, isDark, nextTime),
            const SizedBox(height: 12),
          ],
          
          // Schedule times row
          _buildScheduleTimes(theme, isDark, schedule),
        ],
      ),
    );
  }

  Widget _buildMoistureThresholdInfo(ThemeData theme, bool isDark, MoistureThreshold threshold) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PumpScheduleCard._accentTeal.withAlpha(isDark ? 30 : 40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PumpScheduleCard._accentTeal.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.water_drop_rounded,
            size: 16,
            color: PumpScheduleCard._accentTeal,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white.withAlpha(200) : Colors.black87,
                ),
                children: [
                  const TextSpan(text: 'Siram otomatis jika kelembaban '),
                  TextSpan(
                    text: '< ${threshold.triggerBelow}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: PumpScheduleCard._accentTeal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: PumpScheduleCard._accentTeal.withAlpha(40),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${threshold.duration}s',
              style: theme.textTheme.labelSmall?.copyWith(
                color: PumpScheduleCard._accentTeal,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextWateringInfo(ThemeData theme, bool isDark, String nextTime) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(15) : Colors.white.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PumpScheduleCard._primaryRose.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.timer_outlined,
              size: 18,
              color: PumpScheduleCard._primaryRose,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Penyiraman Berikutnya',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 11,
                  ),
                ),
                Text(
                  nextTime,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.white : PumpScheduleCard._darkRose,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTimes(ThemeData theme, bool isDark, WateringScheduleData schedule) {
    return Row(
      children: schedule.dailySchedules.map((item) {
        final isMorning = item.time.startsWith('0') || 
            (item.time.startsWith('1') && 
             int.tryParse(item.time.substring(0, 2)) != null && 
             int.parse(item.time.substring(0, 2)) < 12);
        
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: schedule.dailySchedules.last == item ? 0 : 8,
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withAlpha(item.enabled ? 20 : 8)
                  : Colors.white.withAlpha(item.enabled ? 200 : 100),
              borderRadius: BorderRadius.circular(12),
              border: item.enabled ? Border.all(
                color: isDark 
                    ? PumpScheduleCard._lightRose.withAlpha(30)
                    : PumpScheduleCard._primaryRose.withAlpha(20),
              ) : null,
            ),
            child: Column(
              children: [
                Icon(
                  isMorning ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                  size: 16,
                  color: item.enabled
                      ? (isMorning 
                          ? Colors.amber[isDark ? 300 : 700] 
                          : Colors.indigo[isDark ? 200 : 400])
                      : Colors.grey,
                ),
                const SizedBox(height: 4),
                Text(
                  item.time,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: item.enabled
                        ? (isDark ? Colors.white : PumpScheduleCard._darkRose)
                        : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${item.duration}s',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: item.enabled
                        ? (isDark ? Colors.white60 : Colors.black54)
                        : Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScheduleLoading(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withAlpha(10)
            : PumpScheduleCard._lightRose.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isDark ? Colors.white54 : PumpScheduleCard._primaryRose,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Memuat jadwal...',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white54 : PumpScheduleCard._darkRose,
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
