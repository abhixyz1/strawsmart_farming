import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/guidance_item.dart';
import '../dashboard_repository.dart';

/// Widget untuk menampilkan insight dan rekomendasi budidaya stroberi
class StrawberryGuidanceSection extends ConsumerWidget {
  const StrawberryGuidanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(strawberryGuidanceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Jika tidak ada data sensor, tampilkan placeholder
    if (recommendations.isEmpty) {
      return _buildPlaceholder(context);
    }

    // Ambil top 4 recommendations (prioritas tertinggi)
    final topRecommendations = recommendations.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 24,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insight Budidaya Stroberi',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                    ),
                    Text(
                      '${recommendations.length} rekomendasi tersedia',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Guidance Cards
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: topRecommendations.length,
          itemBuilder: (context, index) {
            final item = topRecommendations[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GuidanceCard(item: item),
            );
          },
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.sensors_off_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Menunggu Data Sensor',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rekomendasi budidaya akan muncul setelah data sensor tersedia',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
          ),
        ],
      ),
    );
  }
}

/// Widget untuk single guidance card
class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({required this.item});

  final GuidanceItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Tentukan warna berdasarkan priority
    Color backgroundColor;
    Color borderColor;
    Color iconColor;
    IconData priorityIcon;

    if (item.isCritical) {
      backgroundColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      iconColor = Colors.red.shade700;
      priorityIcon = Icons.error_outline;
    } else if (item.isWarning) {
      backgroundColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
      iconColor = Colors.orange.shade700;
      priorityIcon = Icons.warning_amber_outlined;
    } else {
      backgroundColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      iconColor = Colors.green.shade700;
      priorityIcon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconForType(item.type),
              size: 24,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title with priority badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
                    ),
                    Icon(
                      priorityIcon,
                      size: 16,
                      color: iconColor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),

                // Sensor value if available
                if (item.sensorValue != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Nilai: ${item.sensorValue}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(GuidanceType type) {
    switch (type) {
      case GuidanceType.temperature:
        return Icons.thermostat_outlined;
      case GuidanceType.humidity:
        return Icons.water_drop_outlined;
      case GuidanceType.soilMoisture:
        return Icons.grass_outlined;
      case GuidanceType.light:
        return Icons.wb_sunny_outlined;
      case GuidanceType.watering:
        return Icons.water_outlined;
      case GuidanceType.ventilation:
        return Icons.air_outlined;
      case GuidanceType.general:
        return Icons.info_outline;
    }
  }
}
