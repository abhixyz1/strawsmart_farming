import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../greenhouse/greenhouse_repository.dart';
import '../dashboard_repository.dart';

// ============================================================================
// GREENHOUSE CONDITION CARD V2 - Modern & Eye-catching Design
// ============================================================================

class GreenhouseConditionCard extends ConsumerWidget {
  const GreenhouseConditionCard({
    super.key,
    required this.snapshot,
  });

  final SensorSnapshot? snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(selectedGreenhouseProvider);
    final greenhouseName = selected?.greenhouseName ?? 'Greenhouse';

    final temp = snapshot?.temperature;
    final humidity = snapshot?.humidity;
    final soilPercent = snapshot?.soilMoisturePercent;
    final lightPercent = _lightPercent(snapshot?.lightIntensity);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE57373), // Strawberry rose
            Color(0xFFD32F2F), // Deep strawberry
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE57373).withAlpha((255 * 0.3).round()),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha((255 * 0.08).round()),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha((255 * 0.05).round()),
                ),
              ),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header - Location & Date side by side
                  _buildHeader(context, greenhouseName, theme),
                  const SizedBox(height: 16),
                  // Main temperature display - centered
                  _buildMainDisplay(context, temp, theme),
                  const SizedBox(height: 16),
                  // Divider line
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withAlpha((255 * 0.0).round()),
                          Colors.white.withAlpha((255 * 0.3).round()),
                          Colors.white.withAlpha((255 * 0.3).round()),
                          Colors.white.withAlpha((255 * 0.0).round()),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sensor grid
                  _buildSensorGrid(context, humidity, lightPercent, soilPercent, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String greenhouseName, ThemeData theme) {
    final now = DateTime.now();
    final days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final dateStr = '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Location chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((255 * 0.15).round()),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                greenhouseName,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Date chip - on the right
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((255 * 0.1).round()),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: Colors.white.withAlpha((255 * 0.8).round()),
              ),
              const SizedBox(width: 6),
              Text(
                dateStr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withAlpha((255 * 0.9).round()),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainDisplay(
    BuildContext context,
    double? temp,
    ThemeData theme,
  ) {
    final tempStr = temp?.toStringAsFixed(0) ?? '--';

    return Center(
      child: Column(
        children: [
          // Temperature - centered
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tempStr,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 72,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 0.9,
                  letterSpacing: -2,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '°C',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withAlpha((255 * 0.8).round()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Suhu Greenhouse',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withAlpha((255 * 0.7).round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorGrid(
    BuildContext context,
    double? humidity,
    double? light,
    double? soil,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _SensorItem(
            icon: Icons.water_drop_rounded,
            value: humidity != null ? '${humidity.toStringAsFixed(0)}%' : '—',
            label: 'Kelembaban',
            iconColor: const Color(0xFF64B5F6),
          ),
          _buildVerticalDivider(),
          _SensorItem(
            icon: Icons.wb_sunny_rounded,
            value: light != null ? '${light.toStringAsFixed(0)}%' : '—',
            label: 'Cahaya',
            iconColor: const Color(0xFFFFD54F),
          ),
          _buildVerticalDivider(),
          _SensorItem(
            icon: Icons.grass_rounded,
            value: soil != null ? '${soil.toStringAsFixed(0)}%' : '—',
            label: 'Tanah',
            iconColor: const Color(0xFF81C784),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withAlpha((255 * 0.2).round()),
    );
  }

  double? _lightPercent(int? raw) {
    if (raw == null) return null;
    final clamped = raw.clamp(0, 4095);
    return (clamped / 4095) * 100;
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

class _SensorItem extends StatelessWidget {
  const _SensorItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withAlpha((255 * 0.7).round()),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
