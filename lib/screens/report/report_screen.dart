import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/report_data.dart';
import '../greenhouse/greenhouse_repository.dart';
import 'csv_report_generator.dart';
import 'pdf_report_generator.dart';
import 'report_repository.dart';

/// Extension untuk menghitung jumlah hari dalam DateTimeRange
extension DateTimeRangeExtension on DateTimeRange {
  int get dayCount => end.difference(start).inDays + 1;
  
  DateTimeRange copyWithStart(DateTime newStart) {
    return DateTimeRange(start: newStart, end: end);
  }
  
  DateTimeRange copyWithEnd(DateTime newEnd) {
    return DateTimeRange(start: start, end: newEnd);
  }
}

/// Screen untuk generate dan export laporan
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final dateRange = ref.watch(reportDateRangeProvider);
    final greenhouse = ref.watch(selectedGreenhouseProvider);
    final reportAsync = ref.watch(reportDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(reportDataProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: greenhouse == null
          ? _buildNoGreenhouseSelected()
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreenhouseInfo(greenhouse),
                    const SizedBox(height: 16),
                    _buildDateRangePicker(dateRange),
                    const SizedBox(height: 24),
                    _buildReportPreview(reportAsync),
                    const SizedBox(height: 24),
                    _buildExportButtons(reportAsync),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorMessage(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNoGreenhouseSelected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.agriculture, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Pilih greenhouse terlebih dahulu',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildGreenhouseInfo(dynamic greenhouse) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.eco, color: Colors.green[700], size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greenhouse.greenhouseName ?? 'Greenhouse',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${greenhouse.deviceId ?? greenhouse.greenhouseId}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangePicker(DateTimeRange dateRange) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.date_range, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Periode Laporan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${dateRange.dayCount} hari',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Dari',
                    value: dateRange.start,
                    onTap: () => _selectStartDate(dateRange),
                    dateFormat: dateFormat,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DateField(
                    label: 'Sampai',
                    value: dateRange.end,
                    onTap: () => _selectEndDate(dateRange),
                    dateFormat: dateFormat,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _QuickDateChip(
                  label: '7 Hari',
                  onTap: () => _setQuickRange(7),
                ),
                _QuickDateChip(
                  label: '14 Hari',
                  onTap: () => _setQuickRange(14),
                ),
                _QuickDateChip(
                  label: '30 Hari',
                  onTap: () => _setQuickRange(30),
                ),
                _QuickDateChip(
                  label: 'Bulan Ini',
                  onTap: _setThisMonth,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportPreview(AsyncValue<ReportData?> reportAsync) {
    return reportAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Mengambil data...'),
              ],
            ),
          ),
        ),
      ),
      error: (error, _) => Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Gagal memuat data: $error',
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        if (data == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Tidak ada data'),
              ),
            ),
          );
        }
        return _buildReportPreviewContent(data);
      },
    );
  }

  Widget _buildReportPreviewContent(ReportData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.preview, size: 20),
                SizedBox(width: 8),
                Text(
                  'Preview Laporan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildStatRow(
              'Total Data Sensor',
              '${data.readings.length} pembacaan',
              Icons.sensors,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              'Total Penyiraman',
              '${data.wateringHistory.length}x (${data.totalWateringMinutes} menit)',
              Icons.water_drop,
              Colors.cyan,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              'Kejadian Penting',
              '${data.importantEvents.length} kejadian',
              Icons.warning_amber,
              data.importantEvents.isEmpty ? Colors.green : Colors.orange,
            ),
            const Divider(height: 24),
            _buildSensorStatsGrid(data),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSensorStatsGrid(ReportData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistik Sensor',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SensorStatCard(
                label: 'Suhu',
                stats: data.temperatureStats,
                unit: '°C',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SensorStatCard(
                label: 'Kelembaban',
                stats: data.humidityStats,
                unit: '%',
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SensorStatCard(
                label: 'Tanah',
                stats: data.soilMoistureStats,
                unit: '%',
                color: Colors.brown,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SensorStatCard(
                label: 'Cahaya',
                stats: data.lightStats,
                unit: ' lux',
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExportButtons(AsyncValue<ReportData?> reportAsync) {
    final data = reportAsync.valueOrNull;
    final isEnabled = data != null && !_isGenerating;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.download, size: 20),
                SizedBox(width: 8),
                Text(
                  'Export Laporan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ExportButton(
                    icon: Icons.picture_as_pdf,
                    label: 'PDF',
                    color: Colors.red,
                    onPressed: isEnabled ? () => _exportPdf(data) : null,
                    isLoading: _isGenerating,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ExportButton(
                    icon: Icons.table_chart,
                    label: 'CSV',
                    color: Colors.green,
                    onPressed: isEnabled ? () => _exportCsv(data) : null,
                    isLoading: _isGenerating,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _ExportButton(
                icon: Icons.print,
                label: 'Preview & Print PDF',
                color: Colors.blue,
                onPressed: isEnabled ? () => _previewPdf(data) : null,
                isLoading: _isGenerating,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[700], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[700]),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _errorMessage = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDate(DateTimeRange current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current.start,
      firstDate: DateTime(2024),
      lastDate: current.end,
    );
    if (picked != null) {
      ref.read(reportDateRangeProvider.notifier).state = current.copyWithStart(picked);
    }
  }

  Future<void> _selectEndDate(DateTimeRange current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current.end,
      firstDate: current.start,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(reportDateRangeProvider.notifier).state = current.copyWithEnd(picked);
    }
  }

  void _setQuickRange(int days) {
    final now = DateTime.now();
    ref.read(reportDateRangeProvider.notifier).state = DateTimeRange(
      start: now.subtract(Duration(days: days - 1)),
      end: now,
    );
  }

  void _setThisMonth() {
    final now = DateTime.now();
    ref.read(reportDateRangeProvider.notifier).state = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
  }

  Future<void> _exportPdf(ReportData data) async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final generator = PdfReportGenerator();
      final pdfBytes = await generator.generateReport(data);

      final dateFormat = DateFormat('yyyy-MM-dd');
      final fileName = 'laporan_${data.greenhouseId}_${dateFormat.format(data.startDate)}_${dateFormat.format(data.endDate)}.pdf';

      if (kIsWeb) {
        // Web: use printing package to save
        await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      } else {
        // Mobile/Desktop: save to file and share
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Laporan Greenhouse ${data.greenhouseName}',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF berhasil dibuat!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal membuat PDF: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _exportCsv(ReportData data) async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final generator = CsvReportGenerator();
      final csvContent = generator.generateCompleteCsv(data);

      final dateFormat = DateFormat('yyyy-MM-dd');
      final fileName = 'laporan_${data.greenhouseId}_${dateFormat.format(data.startDate)}_${dateFormat.format(data.endDate)}.csv';

      if (kIsWeb) {
        // Web: create blob and download
        _showWebDownloadNotSupported();
      } else {
        // Mobile/Desktop: save to file and share
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(csvContent);

        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Laporan Greenhouse ${data.greenhouseName}',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV berhasil dibuat!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal membuat CSV: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _previewPdf(ReportData data) async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final generator = PdfReportGenerator();
      final pdfBytes = await generator.generateReport(data);

      final dateFormat = DateFormat('yyyy-MM-dd');
      final fileName = 'laporan_${data.greenhouseId}_${dateFormat.format(data.startDate)}_${dateFormat.format(data.endDate)}.pdf';

      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: fileName,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal preview PDF: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _showWebDownloadNotSupported() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Untuk web, gunakan export PDF'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.dateFormat,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(value),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      backgroundColor: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _SensorStatCard extends StatelessWidget {
  const _SensorStatCard({
    required this.label,
    required this.stats,
    required this.unit,
    required this.color,
  });

  final String label;
  final SensorStats stats;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          if (stats.hasData) ...[
            Text(
              '${stats.average.toStringAsFixed(1)}$unit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${stats.min.toStringAsFixed(1)} - ${stats.max.toStringAsFixed(1)}$unit',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ] else
            Text(
              'Tidak ada data',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
