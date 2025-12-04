import 'package:flutter/material.dart';

import '../dashboard_repository.dart';

/// Data untuk setiap tile sensor
class SensorTileData {
  const SensorTileData({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
}

/// Widget grid sensor 6 tile seperti referensi
/// Tampilan minimalis dengan ikon strawberry theme
class SensorGridPanel extends StatelessWidget {
  const SensorGridPanel({
    super.key,
    required this.snapshot,
  });

  final SensorSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = _buildTiles(theme);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha((255 * 0.1).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.04).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Icon(
                Icons.sensors,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Data Sensor',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tiles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              return _SensorTile(data: tiles[index]);
            },
          ),
        ],
      ),
    );
  }

  List<SensorTileData> _buildTiles(ThemeData theme) {
    final temp = snapshot?.temperature;
    final humidity = snapshot?.humidity;
    final soilPercent = snapshot?.soilMoisturePercent;
    final lightRaw = snapshot?.lightIntensity;
    final soilAdc = snapshot?.soilMoistureAdc;

    // Hitung heat index (feels like)
    final feelsLike = _calculateFeelsLike(temp, humidity);

    // Hitung light percent
    final lightPercent = _lightPercent(lightRaw);

    return [
      SensorTileData(
        icon: Icons.thermostat_outlined,
        label: 'Feels like',
        value: _formatTemp(feelsLike),
        iconColor: theme.colorScheme.primary,
      ),
      SensorTileData(
        icon: Icons.device_thermostat,
        label: 'Suhu',
        value: _formatTemp(temp),
        iconColor: Colors.orange,
      ),
      SensorTileData(
        icon: Icons.water_drop_outlined,
        label: 'Humidity',
        value: _formatPercent(humidity),
        iconColor: Colors.blue,
      ),
      SensorTileData(
        icon: Icons.light_mode_outlined,
        label: 'Cahaya',
        value: _formatPercent(lightPercent),
        iconColor: Colors.amber,
      ),
      SensorTileData(
        icon: Icons.grass_outlined,
        label: 'Tanah',
        value: _formatPercent(soilPercent),
        iconColor: Colors.green,
      ),
      SensorTileData(
        icon: Icons.analytics_outlined,
        label: 'Soil ADC',
        value: _formatAdc(soilAdc),
        iconColor: Colors.teal,
      ),
    ];
  }

  double? _calculateFeelsLike(double? temp, double? humidity) {
    if (temp == null || humidity == null) return null;

    // Rumus heat index sederhana
    final t = temp;
    final rh = humidity;
    final hi = -8.784695 +
        (1.61139411 * t) +
        (2.338549 * rh) -
        (0.14611605 * t * rh) -
        (0.012308094 * t * t) -
        (0.016424828 * rh * rh) +
        (0.002211732 * t * t * rh) +
        (0.00072546 * t * rh * rh) -
        (0.000003582 * t * t * rh * rh);
    return hi;
  }

  double? _lightPercent(int? raw) {
    if (raw == null) return null;
    final clamped = raw.clamp(0, 4095);
    return (clamped / 4095) * 100;
  }

  String _formatTemp(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(0)}°C';
  }

  String _formatPercent(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(0)}%';
  }

  String _formatAdc(int? value) {
    if (value == null) return '—';
    return '$value';
  }
}

/// Tile individual untuk sensor
class _SensorTile extends StatelessWidget {
  const _SensorTile({required this.data});

  final SensorTileData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = data.iconColor ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon dengan background circle
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withAlpha((255 * 0.12).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.icon,
              color: iconColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          // Label
          Text(
            data.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // Value
          Text(
            data.value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
