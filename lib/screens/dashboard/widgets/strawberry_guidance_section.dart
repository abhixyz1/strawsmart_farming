import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/guidance_item.dart';
import '../dashboard_repository.dart';

// ============================================================================
// STRAWBERRY GUIDANCE SECTION - Modern Card Design with Sage Theme
// ============================================================================

class StrawberryGuidanceSection extends ConsumerWidget {
  const StrawberryGuidanceSection({super.key});

  // Theme colors - Strawberry Rose (soft red-pink)
  static const _primaryRose = Color(0xFFE57373);
  static const _darkRose = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendations = ref.watch(strawberryGuidanceProvider);
    final theme = Theme.of(context);

    if (recommendations.isEmpty) {
      return _buildPlaceholder(context, theme);
    }

    // Show all recommendations (max 4)
    final displayCount = recommendations.length > 4 ? 4 : recommendations.length;
    final topRecommendations = recommendations.take(displayCount).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context, theme),
          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: theme.colorScheme.outline.withAlpha((255 * 0.1).round()),
          ),
          // Recommendations
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...topRecommendations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Column(
                    children: [
                      _GuidanceItem(item: item, index: index + 1),
                      if (index < topRecommendations.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Container(
                            height: 1,
                            color: theme.colorScheme.outline.withAlpha((255 * 0.08).round()),
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Icon with gradient background
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryRose, _darkRose],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _primaryRose.withAlpha((255 * 0.3).round()),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.eco_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          // Title & subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insight Budidaya',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rekomendasi berdasarkan kondisi sensor',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primaryRose.withAlpha((255 * 0.1).round()),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.sensors_rounded,
              size: 28,
              color: _primaryRose.withAlpha((255 * 0.6).round()),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menunggu Data Sensor',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Insight akan muncul setelah data tersedia',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GUIDANCE ITEM - Compact Row Design
// ============================================================================

class _GuidanceItem extends StatelessWidget {
  const _GuidanceItem({
    required this.item,
    required this.index,
  });

  final GuidanceItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _getColors();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon with colored background
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getIcon(),
            size: 20,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with priority icon
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  // Priority icon indicator
                  Icon(
                    _getPriorityIcon(),
                    size: 16,
                    color: _getPriorityColor(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Description
              Text(
                item.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor() {
    if (item.isCritical) return const Color(0xFFEF5350);
    if (item.isWarning) return const Color(0xFFFFB74D);
    return const Color(0xFF66BB6A);
  }

  IconData _getPriorityIcon() {
    if (item.isCritical) return Icons.warning_rounded;
    if (item.isWarning) return Icons.info_rounded;
    return Icons.check_circle_rounded;
  }

  IconData _getIcon() {
    return switch (item.type) {
      GuidanceType.temperature => Icons.thermostat_rounded,
      GuidanceType.humidity => Icons.water_drop_rounded,
      GuidanceType.light => Icons.wb_sunny_rounded,
      GuidanceType.soilMoisture => Icons.grass_rounded,
      GuidanceType.watering => Icons.opacity_rounded,
      GuidanceType.ventilation => Icons.air_rounded,
      GuidanceType.general => Icons.eco_rounded,
    };
  }

  _ItemColors _getColors() {
    return switch (item.type) {
      GuidanceType.temperature => _ItemColors(
          primary: const Color(0xFFEF5350),
          background: const Color(0xFFEF5350).withAlpha((255 * 0.1).round()),
        ),
      GuidanceType.humidity => _ItemColors(
          primary: const Color(0xFF42A5F5),
          background: const Color(0xFF42A5F5).withAlpha((255 * 0.1).round()),
        ),
      GuidanceType.light => _ItemColors(
          primary: const Color(0xFFFFB74D),
          background: const Color(0xFFFFB74D).withAlpha((255 * 0.1).round()),
        ),
      GuidanceType.soilMoisture || GuidanceType.watering => _ItemColors(
          primary: const Color(0xFF66BB6A),
          background: const Color(0xFF66BB6A).withAlpha((255 * 0.1).round()),
        ),
      GuidanceType.ventilation || GuidanceType.general => _ItemColors(
          primary: const Color(0xFF9575CD),
          background: const Color(0xFF9575CD).withAlpha((255 * 0.1).round()),
        ),
    };
  }
}

class _ItemColors {
  final Color primary;
  final Color background;

  const _ItemColors({
    required this.primary,
    required this.background,
  });
}
