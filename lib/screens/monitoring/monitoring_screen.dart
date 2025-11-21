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
    final selectedDate = ref.watch(selectedMonitoringDateProvider);
    
    // Use cached value if available during loading
    final readings = readingsAsync.valueOrNull ?? [];
    final isLoading = readingsAsync.isLoading && !readingsAsync.hasValue;
    final error = readingsAsync.error;

    return Scaffold(
      body: Column(
        children: [
          // Date Picker Header - Selalu tampil
          _DatePickerHeader(selectedDate: selectedDate),
          const Divider(height: 1),
          
          // Content Area
          Expanded(
            child: RefreshIndicator(
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
                          ? _EmptyStateWidget(selectedDate: selectedDate)
                          : _MonitoringContent(readings: readings),
            ),
          ),
        ],
      ),
    );
  }

  /// Menampilkan date picker dialog
  static Future<void> showMonitoringDatePicker(BuildContext context, WidgetRef ref) async {
    final selectedDate = ref.read(selectedMonitoringDateProvider);
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      ref.read(selectedMonitoringDateProvider.notifier).state = picked;
    }
  }
}

/// Widget header dengan date picker yang selalu tampil
class _DatePickerHeader extends ConsumerWidget {
  const _DatePickerHeader({required this.selectedDate});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(selectedDate);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.6),
            colorScheme.primaryContainer.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih Tanggal Data',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => MonitoringScreen.showMonitoringDatePicker(context, ref),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 22,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Quick navigation buttons
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: colorScheme.primary),
                tooltip: 'Hari sebelumnya',
                onPressed: () {
                  ref.read(selectedMonitoringDateProvider.notifier).state = 
                      selectedDate.subtract(const Duration(days: 1));
                },
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
                ),
              ),
              IconButton(
                icon: Icon(Icons.today_rounded, color: colorScheme.primary),
                tooltip: 'Hari ini',
                onPressed: () {
                  ref.read(selectedMonitoringDateProvider.notifier).state = DateTime.now();
                },
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: colorScheme.primary),
                tooltip: 'Hari berikutnya',
                onPressed: () {
                  final nextDay = selectedDate.add(const Duration(days: 1));
                  if (nextDay.isBefore(DateTime.now().add(const Duration(days: 1)))) {
                    ref.read(selectedMonitoringDateProvider.notifier).state = nextDay;
                  }
                },
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonitoringContent extends ConsumerStatefulWidget {
  const _MonitoringContent({required this.readings});

  final List<HistoricalReading> readings;

  @override
  ConsumerState<_MonitoringContent> createState() => _MonitoringContentState();
}

class _MonitoringContentState extends ConsumerState<_MonitoringContent> {
  // Filter interval options (in minutes, 0 = show all)
  int _selectedInterval = 5; // Default 5 menit

  List<HistoricalReading> _getFilteredReadings() {
    if (_selectedInterval == 0) {
      // Show all data
      return widget.readings;
    }

    // Apply interval filter
    if (widget.readings.isEmpty) return widget.readings;

    final filtered = <HistoricalReading>[];
    DateTime? lastIncludedTime;

    for (final reading in widget.readings) {
      if (lastIncludedTime == null) {
        filtered.add(reading);
        lastIncludedTime = reading.timestamp;
      } else {
        final difference = lastIncludedTime.difference(reading.timestamp).abs();
        if (difference.inMinutes >= _selectedInterval) {
          filtered.add(reading);
          lastIncludedTime = reading.timestamp;
        }
      }
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredReadings = _getFilteredReadings();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Selector with Date Picker
          _buildFilterSelector(context),
          const SizedBox(height: 24),
          
          // Temperature & Humidity Chart Section
          _ChartSection(
            title: 'Grafik Suhu & Kelembaban',
            subtitle: _getFilterSubtitle(),
            icon: Icons.show_chart,
            child: _TempHumidityChart(readings: filteredReadings),
          ),
          const SizedBox(height: 24),
          
          // Soil Moisture Chart Section
          _ChartSection(
            title: 'Grafik Kelembaban Tanah',
            subtitle: _getFilterSubtitle(),
            icon: Icons.water_drop,
            child: _SoilMoistureChart(readings: filteredReadings),
          ),
          const SizedBox(height: 24),
          
          // Historical Readings Table
          _ChartSection(
            title: 'Riwayat Pembacaan Sensor',
            subtitle: '${_getFilterSubtitle()} • Maks 50 baris',
            icon: Icons.table_chart,
            child: _HistoricalTable(readings: filteredReadings),
          ),
        ],
      ),
    );
  }

  String _getFilterSubtitle() {
    final selectedDate = ref.watch(selectedMonitoringDateProvider);
    final dateStr = DateFormat('dd MMM yyyy', 'id_ID').format(selectedDate);
    
    String intervalStr;
    if (_selectedInterval == 0) {
      intervalStr = 'Semua data';
    } else if (_selectedInterval >= 60) {
      final hours = _selectedInterval ~/ 60;
      intervalStr = '1 data per $hours jam';
    } else {
      intervalStr = '1 data per $_selectedInterval menit';
    }
    
    return '$intervalStr • $dateStr';
  }

  Widget _buildFilterSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filteredReadings = _getFilteredReadings();
    
    // Interval Filter Row - Date picker sudah dipindah ke header
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_list_rounded,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            'Interval Data:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedInterval,
                  isDense: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  onChanged: (int? value) {
                    if (value != null) {
                      setState(() => _selectedInterval = value);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text(
                        'Semua Data',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(
                        '1 Menit',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 5,
                      child: Text(
                        '5 Menit',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 10,
                      child: Text(
                        '10 Menit',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 30,
                      child: Text(
                        '30 Menit',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 60,
                      child: Text(
                        '1 Jam',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 14,
                  color: colorScheme.onPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${filteredReadings.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
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

class _EmptyStateWidget extends ConsumerWidget {
  const _EmptyStateWidget({required this.selectedDate});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(selectedDate);
    final isToday = DateFormat('yyyy-MM-dd').format(selectedDate) == 
                    DateFormat('yyyy-MM-dd').format(DateTime.now());
    
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
                Icons.calendar_today_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                isToday ? 'Belum Ada Data Hari Ini' : 'Tidak Ada Data',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tidak ada data sensor untuk tanggal\n$formattedDate',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 24),
              if (isToday)
                Text(
                  '⬇️ Tarik ke bawah untuk refresh',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                )
              else ...[
                // Tombol untuk pilih tanggal lain
                FilledButton.icon(
                  onPressed: () => MonitoringScreen.showMonitoringDatePicker(context, ref),
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Pilih Tanggal Lain'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    ref.read(selectedMonitoringDateProvider.notifier).state = DateTime.now();
                  },
                  icon: const Icon(Icons.today_rounded),
                  label: const Text('Kembali ke Hari Ini'),
                ),
              ],
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
