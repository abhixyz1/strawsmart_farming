import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../../models/cultivation_batch.dart';
import '../../batch/batch_repository.dart';
import '../dashboard_repository.dart';

/// Widget modern untuk menampilkan info jadwal penyiraman
/// Theme: Strawberry Rose - selaras dengan theme app
class ScheduleInfoCard extends ConsumerStatefulWidget {
  const ScheduleInfoCard({super.key});

  @override
  ConsumerState<ScheduleInfoCard> createState() => _ScheduleInfoCardState();
}

class _ScheduleInfoCardState extends ConsumerState<ScheduleInfoCard> {
  // Strawberry Rose Colors (selaras dengan tema app)
  static const _primaryRose = Color(0xFFE57373);
  static const _darkRose = Color(0xFFD32F2F);
  static const _lightRose = Color(0xFFFFCDD2);
  static const _accentTeal = Color(0xFF26A69A);
  
  // Track previous pump state for notification trigger
  bool? _previousPumpState;
  
  @override
  void initState() {
    super.initState();
    _initNotificationService();
  }
  
  Future<void> _initNotificationService() async {
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.initialize();
  }
  
  @override
  Widget build(BuildContext context) {
    // Use phase-aware schedule provider that automatically disables noon watering for non-seedling phases
    final scheduleAsync = ref.watch(phaseAwareScheduleProvider);
    final activeBatchAsync = ref.watch(activeBatchProvider);
    final pumpAsync = ref.watch(pumpStatusProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return scheduleAsync.when(
      data: (schedule) {
        if (schedule == null) {
          return const SizedBox.shrink();
        }
        
        // Get active batch data
        final activeBatch = activeBatchAsync.valueOrNull;
        // Get pump status to show "Sedang Menyiram"
        final pumpStatus = pumpAsync.valueOrNull;
        final isPumpActive = pumpStatus?.isOn ?? false;
        
        // Trigger notification when pump state changes to ON
        _handlePumpStateChange(isPumpActive, activeBatch, schedule);
        
        return _buildScheduleCard(context, theme, isDark, schedule, activeBatch, isPumpActive);
      },
      loading: () => _buildLoadingCard(theme),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
  
  /// Handle pump state change and send notification
  void _handlePumpStateChange(
    bool isPumpActive, 
    CultivationBatch? activeBatch,
    WateringScheduleData schedule,
  ) async {
    // Only trigger notification when state changes from OFF to ON
    if (_previousPumpState != null && isPumpActive && !_previousPumpState!) {
      final notificationService = ref.read(notificationServiceProvider);
      final deviceId = ref.read(dashboardDeviceIdProvider);
      
      // Fetch locationName dari RTDB
      final database = FirebaseDatabase.instance;
      final snapshot = await database
          .ref('devices')
          .child(deviceId)
          .child('info')
          .child('locationName')
          .get();
      
      final locationName = snapshot.exists 
          ? (snapshot.value as String?) 
          : null;
      
      // Get current schedule duration (use first enabled schedule)
      int? duration;
      for (final item in schedule.dailySchedules) {
        if (item.enabled) {
          duration = item.duration;
          break;
        }
      }
      
      notificationService.showWateringStartNotification(
        deviceId: deviceId,
        locationName: locationName ?? 'Greenhouse $deviceId',
        batchName: activeBatch?.name,
        durationSeconds: duration,
      );
    }
    // Update previous state
    _previousPumpState = isPumpActive;
  }

  Widget _buildScheduleCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    WateringScheduleData schedule,
    CultivationBatch? activeBatch,
    bool isPumpActive,
  ) {
    final nextTime = schedule.nextScheduledTime;
    final isEnabled = schedule.enabled;

    // Gradient colors - Strawberry Rose theme
    final gradientColors = isEnabled
        ? isDark
            ? [const Color(0xFF6D2C2C), const Color(0xFF8B3A3A)]  // Dark rose
            : [_primaryRose, _darkRose]  // Light rose
        : isDark
            ? [const Color(0xFF3D3D3D), const Color(0xFF4A4A4A)]
            : [const Color(0xFFE8E8E8), const Color(0xFFD0D0D0)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isEnabled ? _primaryRose : Colors.grey).withAlpha(isDark ? 50 : 70),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row - hanya teks tanpa icon jam
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Jadwal Penyiraman',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  // "Sedang Menyiram" badge when pump is active
                  if (isPumpActive) ...[
                    _buildWateringStatusBadge(theme),
                    const SizedBox(width: 10),
                  ],
                  // Notification toggle removed - all notification settings now in Settings (Pengaturan)
                ],
              ),

              if (isEnabled) ...[
                const SizedBox(height: 20),
                
                // Growth phase recommendation (from active batch)
                if (activeBatch != null) ...[
                  _buildPhaseRecommendation(theme, isDark, activeBatch, schedule),
                  const SizedBox(height: 14),
                ],
                
                // Moisture threshold DIHAPUS dari sini
                // Alasan: Sudah ditangani oleh Fuzzy Logic di ESP32 firmware
                // Fuzzy Logic otomatis menyiram saat kelembaban di bawah ambang batas
                
                // Next watering highlight with countdown
                if (nextTime != null) ...[
                  _buildNextWateringInfo(theme, isDark, nextTime, schedule),
                  const SizedBox(height: 14),
                ],

                // Schedule times row
                _buildScheduleTimes(theme, isDark, schedule),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build phase recommendation section showing watering needs for current growth phase
  Widget _buildPhaseRecommendation(
    ThemeData theme,
    bool isDark,
    CultivationBatch batch,
    WateringScheduleData schedule,
  ) {
    final currentPhase = batch.currentPhase;
    final requirements = batch.currentRequirements;
    
    // Phase emoji and name
    final (phaseEmoji, phaseName, phaseColor) = _getPhaseInfo(currentPhase);
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            phaseColor.withAlpha(70),  // Increased from 40
            phaseColor.withAlpha(45),  // Increased from 20
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: phaseColor.withAlpha(100),  // Increased from 60
          width: 1.5,  // Make border slightly thicker
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: phaseColor.withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  phaseEmoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fase $phaseName',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      batch.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withAlpha(150),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Batch day indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Hari ${_getDaysInPhase(batch)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Watering recommendation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // Watering frequency
                Expanded(
                  child: _buildRecommendationItem(
                    theme,
                    Icons.repeat_rounded,
                    '${requirements.wateringPerDay}x',
                    'per hari',
                    _accentTeal,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withAlpha(30),
                ),
                // Duration per watering
                Expanded(
                  child: _buildRecommendationItem(
                    theme,
                    Icons.timelapse_rounded,
                    '${requirements.wateringDurationSec}s',
                    'durasi',
                    Colors.amber[300]!,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withAlpha(30),
                ),
                // Moisture range
                Expanded(
                  child: _buildRecommendationItem(
                    theme,
                    Icons.water_drop_outlined,
                    '${requirements.minSoilMoisture.toInt()}-${requirements.maxSoilMoisture.toInt()}%',
                    'kelembaban',
                    Colors.blue[300]!,
                  ),
                ),
              ],
            ),
          ),
          
          // Mismatch warning dihapus - jadwal langsung dari Firebase RTDB
          // Fuzzy Logic di ESP32 mengatur penyiraman berdasarkan kondisi aktual
        ],
      ),
    );
  }
  
  Widget _buildRecommendationItem(
    ThemeData theme,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withAlpha(140),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
  
  /// Build "Sedang Menyiram" animated badge
  Widget _buildWateringStatusBadge(ThemeData theme) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.7, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue[400]!,
                  _accentTeal,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _accentTeal.withAlpha(100),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  'Sedang Menyiram',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Get phase info (emoji, name, color) for display
  /// Warna dibuat lebih cerah/kontras agar terlihat jelas di dark background
  (String, String, Color) _getPhaseInfo(GrowthPhase phase) {
    return switch (phase) {
      GrowthPhase.seedling => ('🌱', 'Pembibitan', const Color(0xFF4ADE80)),    // Bright green
      GrowthPhase.vegetative => ('🌿', 'Vegetatif', const Color(0xFF2DD4BF)),   // Bright teal
      GrowthPhase.flowering => ('🌸', 'Pembungaan', const Color(0xFFF472B6)),   // Bright pink
      GrowthPhase.fruiting => ('🍓', 'Pembuahan', const Color(0xFFFB7185)),     // Bright rose
      GrowthPhase.harvesting => ('📦', 'Panen', const Color(0xFFFB923C)),       // Bright orange
    };
  }
  
  /// Calculate days since current phase started
  int _getDaysInPhase(CultivationBatch batch) {
    int cumulativeDays = 0;
    for (final phase in GrowthPhase.values) {
      if (phase == batch.currentPhase) {
        return batch.daysSincePlanting - cumulativeDays;
      }
      final phaseDuration = batch.phaseSettings[phase]?.durationDays ?? 
                            CultivationBatch.defaultPhaseDuration(phase);
      cumulativeDays += phaseDuration;
    }
    return 0;
  }
  
  /// Calculate time remaining until next watering
  String _calculateTimeRemaining(String nextTimeStr, WateringScheduleData schedule) {
    try {
      final now = DateTime.now();
      
      // Parse time string (format: "HH:mm")
      final parts = nextTimeStr.split(':');
      if (parts.length != 2) return '';
      
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return '';
      
      // Create DateTime for next watering
      var nextWatering = DateTime(now.year, now.month, now.day, hour, minute);
      
      // If time has passed today, it's tomorrow
      if (nextWatering.isBefore(now)) {
        nextWatering = nextWatering.add(const Duration(days: 1));
      }
      
      // Calculate difference
      final diff = nextWatering.difference(now);
      
      if (diff.inMinutes < 1) {
        return 'Sebentar lagi';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes} menit lagi';
      } else if (diff.inHours < 24) {
        final hours = diff.inHours;
        final minutes = diff.inMinutes % 60;
        if (minutes > 0) {
          return '$hours jam $minutes menit lagi';
        }
        return '$hours jam lagi';
      } else {
        return 'Besok';
      }
    } catch (e) {
      return '';
    }
  }
  
  Widget _buildNextWateringInfo(
    ThemeData theme, 
    bool isDark, 
    String nextTime,
    WateringScheduleData schedule,
  ) {
    final timeRemaining = _calculateTimeRemaining(nextTime, schedule);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(isDark ? 20 : 35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha(25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _lightRose.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.timer_outlined,
              size: 22,
              color: isDark ? _lightRose : Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Penyiraman Berikutnya',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withAlpha(170),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      nextTime,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    if (timeRemaining.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accentTeal.withAlpha(60),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          timeRemaining,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isDark ? _accentTeal : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTimes(ThemeData theme, bool isDark, WateringScheduleData schedule) {
    final scheduleCount = schedule.dailySchedules.length;
    
    // Jika ada 4+ jadwal, gunakan horizontal scroll
    if (scheduleCount > 3) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: schedule.dailySchedules.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildScheduleTimeItem(theme, isDark, item, index, scheduleCount);
          }).toList(),
        ),
      );
    }
    
    // Jika 1-3 jadwal, gunakan Row dengan Expanded agar lebar sama
    return Row(
      children: schedule.dailySchedules.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isItemEnabled = item.enabled;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: index == scheduleCount - 1 ? 0 : 8,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(isItemEnabled ? 25 : 12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withAlpha(isItemEnabled ? 35 : 15),
              ),
            ),
            child: Column(
              children: [
                // Sun/Moon icon based on time
                Icon(
                  _getTimeIcon(item.time),
                  size: 20,
                  color: isItemEnabled
                      ? _getTimeIconColor(item.time)
                      : Colors.white.withAlpha(90),
                ),
                const SizedBox(height: 6),
                Text(
                  item.time,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withAlpha(isItemEnabled ? 255 : 110),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.duration} detik',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withAlpha(isItemEnabled ? 170 : 90),
                    fontSize: 11,
                  ),
                ),
                if (!isItemEnabled) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'OFF',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _lightRose,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  
  /// Build individual schedule time item for scrollable list
  Widget _buildScheduleTimeItem(
    ThemeData theme, 
    bool isDark, 
    DailyScheduleItem item, 
    int index,
    int totalCount,
  ) {
    final isItemEnabled = item.enabled;
    
    return Container(
      width: 90, // Fixed width for scrollable items
      margin: EdgeInsets.only(
        right: index == totalCount - 1 ? 0 : 8,
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(isItemEnabled ? 25 : 12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withAlpha(isItemEnabled ? 35 : 15),
        ),
      ),
      child: Column(
        children: [
          // Sun/Moon/Afternoon icon based on time
          Icon(
            _getTimeIcon(item.time),
            size: 20,
            color: isItemEnabled
                ? _getTimeIconColor(item.time)
                : Colors.white.withAlpha(90),
          ),
          const SizedBox(height: 6),
          Text(
            item.time,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withAlpha(isItemEnabled ? 255 : 110),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${item.duration}s',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withAlpha(isItemEnabled ? 170 : 90),
              fontSize: 11,
            ),
          ),
          if (!isItemEnabled) ...[  
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'OFF',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _lightRose,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// Check if time is morning (before 12:00)
  bool _isMorningTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return true;
    final hour = int.tryParse(parts[0]) ?? 0;
    return hour < 12;
  }
  
  /// Get appropriate icon for time of day
  IconData _getTimeIcon(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return Icons.wb_sunny_rounded;
    final hour = int.tryParse(parts[0]) ?? 0;
    
    if (hour >= 5 && hour < 12) {
      return Icons.wb_twilight_rounded; // Pagi (sunrise/dawn)
    } else if (hour >= 12 && hour < 17) {
      return Icons.wb_sunny_rounded; // Siang (noon/full sun)
    } else {
      return Icons.nights_stay_rounded; // Malam
    }
  }
  
  /// Get appropriate icon color for time of day
  Color _getTimeIconColor(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return Colors.amber[300]!;
    final hour = int.tryParse(parts[0]) ?? 0;
    
    if (hour >= 5 && hour < 12) {
      return Colors.amber[300]!; // Pagi - kuning
    } else if (hour >= 12 && hour < 17) {
      return Colors.orange[300]!; // Siang - oranye
    } else {
      return Colors.indigo[200]!; // Malam - biru
    }
  }

  Widget _buildMoistureInfo(ThemeData theme, bool isDark, MoistureThreshold threshold) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accentTeal.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _accentTeal.withAlpha(45),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.water_drop_rounded,
            size: 18,
            color: _accentTeal,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withAlpha(190),
                ),
                children: [
                  const TextSpan(text: 'Siram saat kelembaban '),
                  TextSpan(
                    text: 'kurang dari ${threshold.triggerBelow}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _accentTeal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _accentTeal.withAlpha(35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${threshold.duration}s',
              style: theme.textTheme.labelSmall?.copyWith(
                color: _accentTeal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF4D3030), const Color(0xFF5A3A3A)]
              : [_lightRose, _primaryRose.withAlpha(180)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: isDark ? Colors.white70 : Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Memuat jadwal penyiraman...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
