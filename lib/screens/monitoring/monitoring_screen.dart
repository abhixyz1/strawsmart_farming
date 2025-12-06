import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:shimmer/shimmer.dart';

import 'monitoring_repository.dart';

class MonitoringScreen extends ConsumerStatefulWidget {
  const MonitoringScreen({super.key});
  @override
  ConsumerState<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends ConsumerState<MonitoringScreen> {
  late ZoomPanBehavior _tempHumidityZoom;
  late ZoomPanBehavior _soilMoistureZoom;
  late ZoomPanBehavior _lightIntensityZoom;
  bool _showTemperature = true;
  bool _showHumidity = true;
  bool _showSoilMoisture = true;
  bool _showLightIntensity = true;

  @override
  void initState() {
    super.initState();
    _initZoomBehaviors();
  }

  void _initZoomBehaviors() {
    _tempHumidityZoom = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      zoomMode: ZoomMode.x,
    );
    _soilMoistureZoom = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      zoomMode: ZoomMode.x,
    );
    _lightIntensityZoom = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      zoomMode: ZoomMode.x,
    );
  }

  void _resetAllZoom() {
    _tempHumidityZoom.reset();
    _soilMoistureZoom.reset();
    _lightIntensityZoom.reset();
  }

  @override
  Widget build(BuildContext context) {
    final dateRange = ref.watch(monitoringDateRangeProvider);
    final readingsAsync = ref.watch(historicalReadingsByRangeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: Column(
        children: [
          _buildDateRangeBar(context, dateRange),
          Expanded(
            child: readingsAsync.when(
              loading: () => ShimmerLoading(isDark: isDark),
              error: (e, _) => ErrorState(error: e.toString(), onRetry: () => ref.invalidate(historicalReadingsByRangeProvider)),
              data: (readings) => readings.isEmpty ? EmptyState(isDark: isDark) : _buildContent(context, readings),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeBar(BuildContext context, MonitoringDateRange dateRange) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...MonitoringRangePreset.values.map((p) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PresetChip(label: p.label, isSelected: dateRange.preset == p, onTap: () => ref.read(monitoringDateRangeProvider.notifier).setPreset(p)),
            )),
            Container(width: 1, height: 24, color: colorScheme.outlineVariant),
            const SizedBox(width: 12),
            PresetChip(label: 'Custom', isSelected: dateRange.preset == null, onTap: () => _showCustomDatePicker(context), icon: Icons.date_range),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomDatePicker(BuildContext context) async {
    final range = ref.read(monitoringDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: range.startDate, end: range.endDate),
    );
    if (picked != null) ref.read(monitoringDateRangeProvider.notifier).setCustomRange(picked.start, picked.end);
  }

  Widget _buildContent(BuildContext context, List<HistoricalReading> readings) {
    final sorted = List<HistoricalReading>.from(readings)..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Calculate X-axis range with padding
    final dateRange = ref.read(monitoringDateRangeProvider);
    final xMin = dateRange.startDate;
    final xMax = dateRange.endDate;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ChartCard(title: 'Suhu & Kelembaban', legendItems: [
          LegendItemData('Suhu', const Color(0xFFFF6B6B), _showTemperature, () => setState(() => _showTemperature = !_showTemperature)),
          LegendItemData('Kelembaban', const Color(0xFF4ECDC4), _showHumidity, () => setState(() => _showHumidity = !_showHumidity)),
        ], chart: _buildTempHumidityChart(context, sorted, xMin, xMax), onResetZoom: () => _tempHumidityZoom.reset()),
        const SizedBox(height: 16),
        ChartCard(title: 'Kelembaban Tanah', legendItems: [
          LegendItemData('Tanah', const Color(0xFF45B7D1), _showSoilMoisture, () => setState(() => _showSoilMoisture = !_showSoilMoisture)),
        ], chart: _buildSoilMoistureChart(context, sorted, xMin, xMax), onResetZoom: () => _soilMoistureZoom.reset()),
        const SizedBox(height: 16),
        ChartCard(title: 'Intensitas Cahaya', legendItems: [
          LegendItemData('Cahaya', const Color(0xFFFFE66D), _showLightIntensity, () => setState(() => _showLightIntensity = !_showLightIntensity)),
        ], chart: _buildLightIntensityChart(context, sorted, xMin, xMax), onResetZoom: () => _lightIntensityZoom.reset()),
        const SizedBox(height: 24),
        HistoricalDataTable(readings: readings),
      ],
    );
  }

  // Helper to calculate interval based on range
  DateTimeIntervalType _getIntervalType(DateTime min, DateTime max) {
    final diff = max.difference(min);
    if (diff.inHours <= 24) return DateTimeIntervalType.hours;
    if (diff.inDays <= 7) return DateTimeIntervalType.days;
    if (diff.inDays <= 90) return DateTimeIntervalType.days;
    return DateTimeIntervalType.months;
  }

  double _getInterval(DateTime min, DateTime max) {
    final diff = max.difference(min);
    if (diff.inHours <= 24) return 4; // every 4 hours
    if (diff.inDays <= 7) return 1; // every day
    if (diff.inDays <= 30) return 5; // every 5 days
    if (diff.inDays <= 90) return 15; // every 15 days
    return 30; // every month
  }

  String _getDateFormat(DateTime min, DateTime max) {
    final diff = max.difference(min);
    if (diff.inHours <= 24) return 'HH:mm';
    if (diff.inDays <= 7) return 'dd/MM';
    return 'dd/MM';
  }

  Widget _buildTempHumidityChart(BuildContext context, List<HistoricalReading> data, DateTime xMin, DateTime xMax) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gridColor = colorScheme.outlineVariant;
    final labelColor = colorScheme.onSurfaceVariant;
    final isSinglePoint = data.length == 1;
    
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      zoomPanBehavior: _tempHumidityZoom,
      trackballBehavior: TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        tooltipSettings: InteractiveTooltip(
          color: colorScheme.surfaceContainerHighest,
          textStyle: TextStyle(color: colorScheme.onSurface),
        ),
        lineType: TrackballLineType.vertical,
        lineColor: gridColor,
      ),
      primaryXAxis: DateTimeAxis(
        minimum: xMin,
        maximum: xMax,
        intervalType: _getIntervalType(xMin, xMax),
        interval: _getInterval(xMin, xMax),
        majorGridLines: MajorGridLines(color: gridColor),
        axisLine: AxisLine(color: gridColor),
        labelStyle: TextStyle(color: labelColor, fontSize: 10),
        dateFormat: DateFormat(_getDateFormat(xMin, xMax)),
      ),
      primaryYAxis: NumericAxis(
        majorGridLines: MajorGridLines(color: gridColor),
        axisLine: AxisLine(color: gridColor),
        labelStyle: TextStyle(color: labelColor, fontSize: 10),
        minimum: 0,
        maximum: 100,
      ),
      series: <CartesianSeries<HistoricalReading, DateTime>>[
        if (_showTemperature && !isSinglePoint) SplineAreaSeries<HistoricalReading, DateTime>(dataSource: data, xValueMapper: (r, _) => r.timestamp, yValueMapper: (r, _) => r.temperature ?? 0, name: 'Suhu', color: const Color(0xFFFF6B6B).withValues(alpha: 0.3), borderColor: const Color(0xFFFF6B6B), borderWidth: 2),
        if (_showTemperature && isSinglePoint) ScatterSeries<HistoricalReading, DateTime>(dataSource: data, xValueMapper: (r, _) => r.timestamp, yValueMapper: (r, _) => r.temperature ?? 0, name: 'Suhu', color: const Color(0xFFFF6B6B), markerSettings: const MarkerSettings(isVisible: true, width: 12, height: 12)),
        if (_showHumidity && !isSinglePoint) SplineAreaSeries<HistoricalReading, DateTime>(dataSource: data, xValueMapper: (r, _) => r.timestamp, yValueMapper: (r, _) => r.humidity ?? 0, name: 'Kelembaban', color: const Color(0xFF4ECDC4).withValues(alpha: 0.3), borderColor: const Color(0xFF4ECDC4), borderWidth: 2),
        if (_showHumidity && isSinglePoint) ScatterSeries<HistoricalReading, DateTime>(dataSource: data, xValueMapper: (r, _) => r.timestamp, yValueMapper: (r, _) => r.humidity ?? 0, name: 'Kelembaban', color: const Color(0xFF4ECDC4), markerSettings: const MarkerSettings(isVisible: true, width: 12, height: 12)),
      ],
    );
  }

  Widget _buildSoilMoistureChart(BuildContext context, List<HistoricalReading> data, DateTime xMin, DateTime xMax) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gridColor = colorScheme.outlineVariant;
    final labelColor = colorScheme.onSurfaceVariant;
    final isSinglePoint = data.length == 1;
    
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      zoomPanBehavior: _soilMoistureZoom,
      trackballBehavior: TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        tooltipSettings: InteractiveTooltip(
          color: colorScheme.surfaceContainerHighest,
          textStyle: TextStyle(color: colorScheme.onSurface),
        ),
        lineType: TrackballLineType.vertical,
        lineColor: gridColor,
      ),
      primaryXAxis: DateTimeAxis(
        minimum: xMin,
        maximum: xMax,
        intervalType: _getIntervalType(xMin, xMax),
        interval: _getInterval(xMin, xMax),
        majorGridLines: MajorGridLines(color: gridColor),
        axisLine: AxisLine(color: gridColor),
        labelStyle: TextStyle(color: labelColor, fontSize: 10),
        dateFormat: DateFormat(_getDateFormat(xMin, xMax)),
      ),
      primaryYAxis: NumericAxis(
        majorGridLines: MajorGridLines(color: gridColor),
        axisLine: AxisLine(color: gridColor),
        labelStyle: TextStyle(color: labelColor, fontSize: 10),
        minimum: 0,
        maximum: 100,
      ),
      series: <CartesianSeries<HistoricalReading, DateTime>>[
        if (_showSoilMoisture && !isSinglePoint) SplineAreaSeries<HistoricalReading, DateTime>(dataSource: data, xValueMapper: (r, _) => r.timestamp, yValueMapper: (r, _) => r.soilMoisturePercent ?? 0, name: 'Tanah', color: const Color(0xFF45B7D1).withValues(alpha: 0.3), borderColor: const Color(0xFF45B7D1), borderWidth: 2),
        if (_showSoilMoisture && isSinglePoint) ScatterSeries<HistoricalReading, DateTime>(dataSource: data, xValueMapper: (r, _) => r.timestamp, yValueMapper: (r, _) => r.soilMoisturePercent ?? 0, name: 'Tanah', color: const Color(0xFF45B7D1), markerSettings: const MarkerSettings(isVisible: true, width: 12, height: 12)),
      ],
    );
  }

  Widget _buildLightIntensityChart(BuildContext context, List<HistoricalReading> data, DateTime xMin, DateTime xMax) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gridColor = colorScheme.outlineVariant;
    final labelColor = colorScheme.onSurfaceVariant;
    final isSinglePoint = data.length == 1;
    final maxL = data.isNotEmpty ? data.map((r) => r.lightIntensity ?? 0).reduce((a, b) => a > b ? a : b) : 10000.0;
    
    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      zoomPanBehavior: _lightIntensityZoom,
      trackballBehavior: TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        tooltipSettings: InteractiveTooltip(
          color: colorScheme.surfaceContainerHighest,
          textStyle: TextStyle(color: colorScheme.onSurface),
        ),
        lineType: TrackballLineType.vertical,
        lineColor: gridColor,
      ),
      primaryXAxis: DateTimeAxis(
        minimum: xMin,
        maximum: xMax,
        intervalType: _getIntervalType(xMin, xMax),
        interval: _getInterval(xMin, xMax),
        majorGridLines: MajorGridLines(color: gridColor),
        axisLine: AxisLine(color: gridColor),
        labelStyle: TextStyle(color: labelColor, fontSize: 10),
        dateFormat: DateFormat(_getDateFormat(xMin, xMax)),
      ),
      primaryYAxis: NumericAxis(
        majorGridLines: MajorGridLines(color: gridColor),
        axisLine: AxisLine(color: gridColor),
        labelStyle: TextStyle(color: labelColor, fontSize: 10),
        minimum: 0,
        maximum: maxL < 100 ? 100 : maxL * 1.1,
      ),
      series: <CartesianSeries<HistoricalReading, DateTime>>[
        if (_showLightIntensity && !isSinglePoint) SplineAreaSeries<HistoricalReading, DateTime>(dataSource: data, xValueMapper: (r, _) => r.timestamp, yValueMapper: (r, _) => r.lightIntensity ?? 0, name: 'Cahaya', color: const Color(0xFFFFE66D).withValues(alpha: 0.3), borderColor: const Color(0xFFFFE66D), borderWidth: 2),
        if (_showLightIntensity && isSinglePoint) ScatterSeries<HistoricalReading, DateTime>(dataSource: data, xValueMapper: (r, _) => r.timestamp, yValueMapper: (r, _) => r.lightIntensity ?? 0, name: 'Cahaya', color: const Color(0xFFFFE66D), markerSettings: const MarkerSettings(isVisible: true, width: 12, height: 12)),
      ],
    );
  }
}

// ============================================================================
// Helper Classes
// ============================================================================

class LegendItemData {
  final String label;
  final Color color;
  final bool isVisible;
  final VoidCallback onToggle;
  const LegendItemData(this.label, this.color, this.isVisible, this.onToggle);
}

// ============================================================================
// Reusable Widgets
// ============================================================================

class PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const PresetChip({super.key, required this.label, required this.isSelected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? colorScheme.primary : colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartCard extends StatelessWidget {
  final String title;
  final List<LegendItemData> legendItems;
  final Widget chart;
  final VoidCallback onResetZoom;

  const ChartCard({super.key, required this.title, required this.legendItems, required this.chart, required this.onResetZoom});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.zoom_out_map, color: colorScheme.onSurfaceVariant, size: 20),
                  onPressed: onResetZoom,
                  tooltip: 'Reset Zoom',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 16, runSpacing: 8, children: legendItems.map((item) => LegendItem(item: item)).toList()),
          ),
          SizedBox(height: 250, child: Padding(padding: const EdgeInsets.all(8), child: chart)),
        ],
      ),
    );
  }
}

class LegendItem extends StatelessWidget {
  final LegendItemData item;
  const LegendItem({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: item.onToggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: item.isVisible ? item.color : Colors.transparent,
              border: Border.all(color: item.color, width: 2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            item.label,
            style: TextStyle(
              color: item.isVisible ? colorScheme.onSurfaceVariant : colorScheme.outline,
              fontSize: 12,
              decoration: item.isVisible ? null : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }
}

class HistoricalDataTable extends StatelessWidget {
  final List<HistoricalReading> readings;
  const HistoricalDataTable({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tableData = readings.length > 100 ? readings.sublist(0, 100) : readings;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Data Historis',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${tableData.length} dari ${readings.length} data',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest),
              dataRowColor: WidgetStateProperty.all(Colors.transparent),
              headingTextStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              dataTextStyle: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              columns: const [
                DataColumn(label: Text('Waktu')),
                DataColumn(label: Text('Suhu (°C)')),
                DataColumn(label: Text('Kelembaban (%)')),
                DataColumn(label: Text('Tanah (%)')),
                DataColumn(label: Text('Cahaya (lux)')),
              ],
              rows: tableData.map((r) => DataRow(cells: [
                DataCell(Text(DateFormat('dd/MM/yy HH:mm').format(r.timestamp))),
                DataCell(Text((r.temperature ?? 0).toStringAsFixed(1))),
                DataCell(Text((r.humidity ?? 0).toStringAsFixed(1))),
                DataCell(Text((r.soilMoisturePercent ?? 0).toStringAsFixed(1))),
                DataCell(Text((r.lightIntensity ?? 0).toStringAsFixed(0))),
              ])).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerLoading extends StatelessWidget {
  final bool isDark;
  const ShimmerLoading({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? const Color(0xFF2B2D30) : Colors.grey.shade300;
    final highlightColor = isDark ? const Color(0xFF3C3E42) : Colors.grey.shade100;
    
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(height: 350, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 16),
          Container(height: 350, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 16),
          Container(height: 350, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final bool isDark;
  const EmptyState({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart_outlined, size: 80, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Data',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Data sensor akan muncul di sini\nsetelah device terhubung',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Terjadi Kesalahan',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
