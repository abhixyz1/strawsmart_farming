import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'monitoring_repository.dart';

class MonitoringScreen extends ConsumerWidget {
  const MonitoringScreen({super.key});

  /// Refresh callback untuk pull-to-refresh dan refresh button
  Future<void> _handleRefresh(WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    ref.invalidate(historicalReadingsProvider);
    // Wait sedikit untuk give feedback ke user
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingsAsync = ref.watch(historicalReadingsProvider);
    
    // Use cached value if available during loading
    final readings = readingsAsync.valueOrNull ?? [];
    final isLoading = readingsAsync.isLoading && !readingsAsync.hasValue;
    final error = readingsAsync.error;

    return Scaffold(
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: () => _handleRefresh(ref),
        child: isLoading
            ? const _ShimmerLoadingState()
            : error != null && readings.isEmpty
                ? _ErrorStateWidget(
                    error: error,
                    onRetry: () => ref.invalidate(historicalReadingsProvider),
                  )
                : readings.isEmpty
                    ? const _EmptyStateWidget()
                    : _MonitoringContent(readings: readings),
      ),
    );
  }
}

class _MonitoringContent extends StatelessWidget {
  const _MonitoringContent({required this.readings});

  final List<HistoricalReading> readings;

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats(readings);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary Cards
          _buildSummaryCards(context, stats),
          const SizedBox(height: 32),
          
          // Temperature & Humidity Chart Section
          _ChartSection(
            title: 'Grafik Suhu & Kelembaban',
            subtitle: 'Tren 20 pembacaan terakhir',
            icon: Icons.show_chart,
            child: _TempHumidityChart(readings: readings),
          ),
          const SizedBox(height: 24),
          
          // Soil Moisture Chart Section
          _ChartSection(
            title: 'Grafik Kelembaban Tanah',
            subtitle: 'Monitor kondisi media tanam',
            icon: Icons.water_drop,
            child: _SoilMoistureChart(readings: readings),
          ),
          const SizedBox(height: 24),
          
          // Historical Readings Table
          _ChartSection(
            title: 'Riwayat Pembacaan Sensor',
            subtitle: 'Data lengkap dari perangkat',
            icon: Icons.table_chart,
            child: _HistoricalTable(readings: readings),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, _Stats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        
        final cards = [
          _SummaryCard(
            title: 'Suhu',
            icon: Icons.thermostat_outlined,
            current: stats.lastTemp != null ? '${stats.lastTemp!.toStringAsFixed(1)}°C' : 'N/A',
            min: stats.minTemp != null ? 'Min: ${stats.minTemp!.toStringAsFixed(1)}°C' : null,
            max: stats.maxTemp != null ? 'Max: ${stats.maxTemp!.toStringAsFixed(1)}°C' : null,
            color: const Color(0xFFFF6B6B),
          ),
          _SummaryCard(
            title: 'Kelembaban Udara',
            icon: Icons.water_drop_outlined,
            current: stats.lastHumidity != null ? '${stats.lastHumidity!.toStringAsFixed(1)}%' : 'N/A',
            min: stats.minHumidity != null ? 'Min: ${stats.minHumidity!.toStringAsFixed(1)}%' : null,
            max: stats.maxHumidity != null ? 'Max: ${stats.maxHumidity!.toStringAsFixed(1)}%' : null,
            color: const Color(0xFF4ECDC4),
          ),
          _SummaryCard(
            title: 'Kelembaban Tanah',
            icon: Icons.grass_outlined,
            current: stats.lastSoil != null ? '${stats.lastSoil!.toStringAsFixed(1)}%' : 'N/A',
            min: stats.minSoil != null ? 'Min: ${stats.minSoil!.toStringAsFixed(1)}%' : null,
            max: stats.maxSoil != null ? 'Max: ${stats.maxSoil!.toStringAsFixed(1)}%' : null,
            color: const Color(0xFF95E1D3),
          ),
          _SummaryCard(
            title: 'Intensitas Cahaya',
            icon: Icons.wb_sunny_outlined,
            current: stats.lastLight != null ? '${stats.lastLight!.toStringAsFixed(0)}%' : 'N/A',
            min: stats.minLight != null ? 'Min: ${stats.minLight!.toStringAsFixed(0)}%' : null,
            max: stats.maxLight != null ? 'Max: ${stats.maxLight!.toStringAsFixed(0)}%' : null,
            color: const Color(0xFFFFA07A),
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

        return Column(
          children: cards
              .map((card) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card,
                  ))
              .toList(),
        );
      },
    );
  }

  _Stats _calculateStats(List<HistoricalReading> readings) {
    if (readings.isEmpty) {
      return _Stats();
    }

    final temps = readings.where((r) => r.temperature != null).map((r) => r.temperature!).toList();
    final humidities = readings.where((r) => r.humidity != null).map((r) => r.humidity!).toList();
    final soils = readings.where((r) => r.soilMoisturePercent != null).map((r) => r.soilMoisturePercent!).toList();
    final lights = readings.where((r) => r.lightIntensity != null).map((r) => r.lightIntensity!).toList();

    return _Stats(
      lastTemp: temps.isNotEmpty ? temps.first : null,
      minTemp: temps.isNotEmpty ? temps.reduce((a, b) => a < b ? a : b) : null,
      maxTemp: temps.isNotEmpty ? temps.reduce((a, b) => a > b ? a : b) : null,
      lastHumidity: humidities.isNotEmpty ? humidities.first : null,
      minHumidity: humidities.isNotEmpty ? humidities.reduce((a, b) => a < b ? a : b) : null,
      maxHumidity: humidities.isNotEmpty ? humidities.reduce((a, b) => a > b ? a : b) : null,
      lastSoil: soils.isNotEmpty ? soils.first : null,
      minSoil: soils.isNotEmpty ? soils.reduce((a, b) => a < b ? a : b) : null,
      maxSoil: soils.isNotEmpty ? soils.reduce((a, b) => a > b ? a : b) : null,
      lastLight: lights.isNotEmpty ? lights.first : null,
      minLight: lights.isNotEmpty ? lights.reduce((a, b) => a < b ? a : b) : null,
      maxLight: lights.isNotEmpty ? lights.reduce((a, b) => a > b ? a : b) : null,
    );
  }
}

class _Stats {
  final double? lastTemp;
  final double? minTemp;
  final double? maxTemp;
  final double? lastHumidity;
  final double? minHumidity;
  final double? maxHumidity;
  final double? lastSoil;
  final double? minSoil;
  final double? maxSoil;
  final double? lastLight;
  final double? minLight;
  final double? maxLight;

  _Stats({
    this.lastTemp,
    this.minTemp,
    this.maxTemp,
    this.lastHumidity,
    this.minHumidity,
    this.maxHumidity,
    this.lastSoil,
    this.minSoil,
    this.maxSoil,
    this.lastLight,
    this.minLight,
    this.maxLight,
  });
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.current,
    this.min,
    this.max,
    required this.color,
  });

  final String title;
  final IconData icon;
  final String current;
  final String? min;
  final String? max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color.darken(0.2),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              current,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color.darken(0.3),
                    letterSpacing: -0.5,
                  ),
            ),
            if (min != null || max != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (min != null)
                    Expanded(
                      child: _StatLabel(
                        label: min!,
                        color: color.darken(0.15),
                      ),
                    ),
                  if (min != null && max != null) const SizedBox(width: 8),
                  if (max != null)
                    Expanded(
                      child: _StatLabel(
                        label: max!,
                        color: color.darken(0.15),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatLabel extends StatelessWidget {
  const _StatLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

extension on Color {
  Color darken([double amount = 0.1]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _TempHumidityChart extends StatelessWidget {
  const _TempHumidityChart({required this.readings});

  final List<HistoricalReading> readings;

  @override
  Widget build(BuildContext context) {
    // Take last 20 readings for chart (reversed to show chronological order)
    final chartData = readings.take(20).toList().reversed.toList();

    if (chartData.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(child: Text('Tidak ada data')),
      );
    }

    final tempSpots = <FlSpot>[];
    final humiditySpots = <FlSpot>[];

    for (int i = 0; i < chartData.length; i++) {
      final reading = chartData[i];
      if (reading.temperature != null) {
        tempSpots.add(FlSpot(i.toDouble(), reading.temperature!));
      }
      if (reading.humidity != null) {
        humiditySpots.add(FlSpot(i.toDouble(), reading.humidity!));
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 300,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 10,
                verticalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= chartData.length) {
                        return const Text('');
                      }
                      final time = DateFormat('HH:mm').format(chartData[index].timestamp);
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          time,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 20,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                    reservedSize: 42,
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              minX: 0,
              maxX: (chartData.length - 1).toDouble(),
              minY: 0,
              maxY: 100,
              lineBarsData: [
                // Temperature line
                if (tempSpots.isNotEmpty)
                  LineChartBarData(
                    spots: tempSpots,
                    isCurved: true,
                    color: const Color(0xFFFF6B6B),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                    ),
                  ),
                // Humidity line
                if (humiditySpots.isNotEmpty)
                  LineChartBarData(
                    spots: humiditySpots,
                    isCurved: true,
                    color: const Color(0xFF4ECDC4),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                    ),
                  ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                    return touchedBarSpots.map((barSpot) {
                      final flSpot = barSpot;
                      final index = flSpot.x.toInt();
                      if (index < 0 || index >= chartData.length) {
                        return null;
                      }
                      final time = DateFormat('HH:mm').format(chartData[index].timestamp);
                      final value = flSpot.y.toStringAsFixed(1);
                      final label = barSpot.barIndex == 0 ? 'Suhu' : 'Kelembaban';
                      return LineTooltipItem(
                        '$label: $value\n$time',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoilMoistureChart extends StatelessWidget {
  const _SoilMoistureChart({required this.readings});

  final List<HistoricalReading> readings;

  @override
  Widget build(BuildContext context) {
    final chartData = readings.take(20).toList().reversed.toList();

    if (chartData.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(child: Text('Tidak ada data')),
      );
    }

    final soilSpots = <FlSpot>[];

    for (int i = 0; i < chartData.length; i++) {
      final reading = chartData[i];
      if (reading.soilMoisturePercent != null) {
        soilSpots.add(FlSpot(i.toDouble(), reading.soilMoisturePercent!));
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          height: 300,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 20,
                verticalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= chartData.length) {
                        return const Text('');
                      }
                      final time = DateFormat('HH:mm').format(chartData[index].timestamp);
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          time,
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 20,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                    reservedSize: 42,
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              minX: 0,
              maxX: (chartData.length - 1).toDouble(),
              minY: 0,
              maxY: 100,
              lineBarsData: [
                if (soilSpots.isNotEmpty)
                  LineChartBarData(
                    spots: soilSpots,
                    isCurved: true,
                    color: const Color(0xFF95E1D3),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF95E1D3).withValues(alpha: 0.2),
                    ),
                  ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                    return touchedBarSpots.map((barSpot) {
                      final flSpot = barSpot;
                      final index = flSpot.x.toInt();
                      if (index < 0 || index >= chartData.length) {
                        return null;
                      }
                      final time = DateFormat('HH:mm').format(chartData[index].timestamp);
                      final value = flSpot.y.toStringAsFixed(1);
                      return LineTooltipItem(
                        'Tanah: $value%\n$time',
                        const TextStyle(color: Colors.white),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoricalTable extends StatelessWidget {
  const _HistoricalTable({required this.readings});

  final List<HistoricalReading> readings;

  @override
  Widget build(BuildContext context) {
    // Show last 50 readings
    final displayReadings = readings.take(50).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                ),
                headingTextStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                dataTextStyle: Theme.of(context).textTheme.bodyMedium,
                columns: const [
                  DataColumn(label: Text('Waktu')),
                  DataColumn(label: Text('Suhu (°C)')),
                  DataColumn(label: Text('Kelembaban (%)')),
                  DataColumn(label: Text('Tanah (%)')),
                  DataColumn(label: Text('Cahaya (%)')),
                ],
                rows: displayReadings.map((reading) {
                  return DataRow(cells: [
                    DataCell(Text(
                      DateFormat('dd/MM HH:mm').format(reading.timestamp),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    )),
                    DataCell(Text(
                      reading.temperature?.toStringAsFixed(1) ?? '-',
                    )),
                    DataCell(Text(
                      reading.humidity?.toStringAsFixed(1) ?? '-',
                    )),
                    DataCell(Text(
                      reading.soilMoisturePercent?.toStringAsFixed(1) ?? '-',
                    )),
                    DataCell(Text(
                      reading.lightIntensity?.toStringAsFixed(0) ?? '-',
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateWidget extends StatelessWidget {
  const _EmptyStateWidget();

  @override
  Widget build(BuildContext context) {
    // Make scrollable agar RefreshIndicator bisa triggered
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timeline_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Data Historis',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Data monitoring akan ditampilkan di sini\nsetelah perangkat mulai mengirim data',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                '⬇️ Tarik ke bawah untuk refresh',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorStateWidget extends StatelessWidget {
  const _ErrorStateWidget({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Make scrollable agar RefreshIndicator bisa triggered
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cloud_off_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Gagal Memuat Data',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerLoadingState extends StatefulWidget {
  const _ShimmerLoadingState();

  @override
  State<_ShimmerLoadingState> createState() => _ShimmerLoadingStateState();
}

class _ShimmerLoadingStateState extends State<_ShimmerLoadingState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shimmer summary cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;
              final shimmerCards = List.generate(4, (index) => _ShimmerCard(animation: _animation));
              
              if (isWide) {
                return Row(
                  children: shimmerCards
                      .map((card) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: card,
                            ),
                          ))
                      .toList(),
                );
              }
              
              return Column(
                children: shimmerCards
                    .map((card) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: card,
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 32),
          _ShimmerCard(animation: _animation, height: 300),
          const SizedBox(height: 24),
          _ShimmerCard(animation: _animation, height: 300),
        ],
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard({required this.animation, this.height = 120});

  final Animation<double> animation;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Theme.of(context).colorScheme.surfaceContainerHighest,
                Theme.of(context).colorScheme.surfaceContainerHigh,
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ],
              stops: [
                (animation.value - 1).clamp(0.0, 1.0),
                animation.value.clamp(0.0, 1.0),
                (animation.value + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
