import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'monitoring_repository.dart';

class MonitoringScreen extends ConsumerWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingsAsync = ref.watch(historicalReadingsProvider);
    
    // Use cached value if available during loading
    final readings = readingsAsync.valueOrNull ?? [];
    final isLoading = readingsAsync.isLoading && !readingsAsync.hasValue;
    final error = readingsAsync.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: () => ref.invalidate(historicalReadingsProvider),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null && readings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Gagal memuat data: $error',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(historicalReadingsProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : readings.isEmpty
                  ? const _EmptyStateWidget()
                  : _MonitoringContent(readings: readings),
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
          const SizedBox(height: 24),
          
          // Temperature & Humidity Chart
          Text(
            'Grafik Suhu & Kelembaban',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          _TempHumidityChart(readings: readings),
          const SizedBox(height: 32),
          
          // Soil Moisture Chart
          Text(
            'Grafik Kelembaban Tanah',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          _SoilMoistureChart(readings: readings),
          const SizedBox(height: 32),
          
          // Historical Readings Table
          Text(
            'Riwayat Pembacaan Sensor',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          _HistoricalTable(readings: readings),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              current,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
            ),
            if (min != null || max != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (min != null)
                    Expanded(
                      child: Text(
                        min!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  if (max != null)
                    Expanded(
                      child: Text(
                        max!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
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
    return Center(
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
        ],
      ),
    );
  }
}
