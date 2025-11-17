import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../monitoring/monitoring_repository.dart';

class LaporanScreen extends ConsumerWidget {
  const LaporanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingsAsync = ref.watch(historicalReadingsProvider);
    final readings = readingsAsync.valueOrNull ?? [];

    // Calculate daily summary from last 24 hours
    final now = DateTime.now();
    final last24Hours = readings.where((r) {
      return now.difference(r.timestamp).inHours <= 24;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assessment_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Laporan Harian',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                    ),
                    Text(
                      'Ringkasan 24 jam terakhir',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Daily Summary Cards
          if (last24Hours.isNotEmpty) ...[
            _DailySummarySection(readings: last24Hours),
            const SizedBox(height: 24),
          ],

          // Download Placeholder
          _DownloadPlaceholder(),
          const SizedBox(height: 24),

          // Notable Events Timeline
          _NotableEventsTimeline(readings: last24Hours),
        ],
      ),
    );
  }
}

class _DailySummarySection extends StatelessWidget {
  const _DailySummarySection({required this.readings});

  final List<HistoricalReading> readings;

  @override
  Widget build(BuildContext context) {
    final stats = _calculateDailyStats(readings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan Statistik',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final cards = [
              _StatCard(
                title: 'Suhu',
                icon: Icons.thermostat_outlined,
                color: const Color(0xFFFF6B6B),
                max: stats['tempMax'],
                min: stats['tempMin'],
                avg: stats['tempAvg'],
                unit: '°C',
              ),
              _StatCard(
                title: 'Kelembaban Udara',
                icon: Icons.water_drop_outlined,
                color: const Color(0xFF4ECDC4),
                max: stats['humidityMax'],
                min: stats['humidityMin'],
                avg: stats['humidityAvg'],
                unit: '%',
              ),
              _StatCard(
                title: 'Kelembaban Tanah',
                icon: Icons.grass_outlined,
                color: const Color(0xFF95E1D3),
                max: stats['soilMax'],
                min: stats['soilMin'],
                avg: stats['soilAvg'],
                unit: '%',
              ),
              _StatCard(
                title: 'Cahaya',
                icon: Icons.wb_sunny_outlined,
                color: const Color(0xFFFFA07A),
                max: stats['lightMax'],
                min: stats['lightMin'],
                avg: stats['lightAvg'],
                unit: '%',
              ),
            ];

            if (isWide) {
              return Row(
                children: cards
                    .map((card) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: card,
                          ),
                        ))
                    .toList(),
              );
            }

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards.map((card) => SizedBox(
                width: (constraints.maxWidth - 12) / 2,
                child: card,
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  Map<String, double?> _calculateDailyStats(List<HistoricalReading> readings) {
    final temps = readings.where((r) => r.temperature != null).map((r) => r.temperature!).toList();
    final humidities = readings.where((r) => r.humidity != null).map((r) => r.humidity!).toList();
    final soils = readings.where((r) => r.soilMoisturePercent != null).map((r) => r.soilMoisturePercent!).toList();
    final lights = readings.where((r) => r.lightIntensity != null).map((r) => r.lightIntensity!).toList();

    return {
      'tempMax': temps.isNotEmpty ? temps.reduce((a, b) => a > b ? a : b) : null,
      'tempMin': temps.isNotEmpty ? temps.reduce((a, b) => a < b ? a : b) : null,
      'tempAvg': temps.isNotEmpty ? temps.reduce((a, b) => a + b) / temps.length : null,
      'humidityMax': humidities.isNotEmpty ? humidities.reduce((a, b) => a > b ? a : b) : null,
      'humidityMin': humidities.isNotEmpty ? humidities.reduce((a, b) => a < b ? a : b) : null,
      'humidityAvg': humidities.isNotEmpty ? humidities.reduce((a, b) => a + b) / humidities.length : null,
      'soilMax': soils.isNotEmpty ? soils.reduce((a, b) => a > b ? a : b) : null,
      'soilMin': soils.isNotEmpty ? soils.reduce((a, b) => a < b ? a : b) : null,
      'soilAvg': soils.isNotEmpty ? soils.reduce((a, b) => a + b) / soils.length : null,
      'lightMax': lights.isNotEmpty ? lights.reduce((a, b) => a > b ? a : b) : null,
      'lightMin': lights.isNotEmpty ? lights.reduce((a, b) => a < b ? a : b) : null,
      'lightAvg': lights.isNotEmpty ? lights.reduce((a, b) => a + b) / lights.length : null,
    };
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.max,
    required this.min,
    required this.avg,
    required this.unit,
  });

  final String title;
  final IconData icon;
  final Color color;
  final double? max;
  final double? min;
  final double? avg;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatRow(context, 'Maks', max),
          const SizedBox(height: 4),
          _buildStatRow(context, 'Min', min),
          const SizedBox(height: 4),
          _buildStatRow(context, 'Rata', avg),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, double? value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        Text(
          value != null ? '${value.toStringAsFixed(1)}$unit' : '-',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _DownloadPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.download_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ekspor Laporan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  'Fitur download akan tersedia segera',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur ekspor akan tersedia segera'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }
}

class _NotableEventsTimeline extends StatelessWidget {
  const _NotableEventsTimeline({required this.readings});

  final List<HistoricalReading> readings;

  @override
  Widget build(BuildContext context) {
    final events = _generateNotableEvents(readings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kejadian Penting',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        if (events.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'Tidak ada kejadian penting dalam 24 jam terakhir',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          )
        else
          ...events.map((event) => _EventCard(event: event)),
      ],
    );
  }

  List<_NotableEvent> _generateNotableEvents(List<HistoricalReading> readings) {
    final events = <_NotableEvent>[];

    for (final reading in readings) {
      // High temperature alert
      if (reading.temperature != null && reading.temperature! > 30) {
        events.add(_NotableEvent(
          icon: Icons.thermostat,
          iconColor: const Color(0xFFFF6B6B),
          title: 'Suhu Tinggi',
          description: 'Suhu mencapai ${reading.temperature!.toStringAsFixed(1)}°C',
          timestamp: reading.timestamp,
        ));
      }

      // Low temperature alert
      if (reading.temperature != null && reading.temperature! < 20) {
        events.add(_NotableEvent(
          icon: Icons.ac_unit,
          iconColor: const Color(0xFF4ECDC4),
          title: 'Suhu Rendah',
          description: 'Suhu turun hingga ${reading.temperature!.toStringAsFixed(1)}°C',
          timestamp: reading.timestamp,
        ));
      }

      // Low soil moisture alert
      if (reading.soilMoisturePercent != null && reading.soilMoisturePercent! < 30) {
        events.add(_NotableEvent(
          icon: Icons.water_drop_outlined,
          iconColor: const Color(0xFFFFA07A),
          title: 'Tanah Kering',
          description: 'Kelembaban tanah ${reading.soilMoisturePercent!.toStringAsFixed(0)}%',
          timestamp: reading.timestamp,
        ));
      }

      // High humidity alert
      if (reading.humidity != null && reading.humidity! > 75) {
        events.add(_NotableEvent(
          icon: Icons.cloud,
          iconColor: const Color(0xFF95E1D3),
          title: 'Kelembaban Tinggi',
          description: 'Kelembaban udara ${reading.humidity!.toStringAsFixed(0)}%',
          timestamp: reading.timestamp,
        ));
      }
    }

    // Sort by timestamp descending and take first 10
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events.take(10).toList();
  }
}

class _NotableEvent {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final DateTime timestamp;

  _NotableEvent({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.timestamp,
  });
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final _NotableEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: event.iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              event.icon,
              color: event.iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Text(
            DateFormat('dd/MM HH:mm').format(event.timestamp),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
