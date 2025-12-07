import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/report_data.dart';

/// Service untuk generate PDF report
class PdfReportGenerator {
  /// Generate PDF bytes dari ReportData
  Future<Uint8List> generateReport(ReportData data) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    final dateTimeFormat = DateFormat('dd MMM yyyy HH:mm', 'id_ID');

    // Page 1: Summary, Statistics, Important Events
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 20, // Increase max pages limit
        header: (context) => _buildHeader(data, dateFormat),
        footer: (context) => _buildFooter(context, data),
        build: (context) => [
          _buildSummarySection(data, dateFormat),
          pw.SizedBox(height: 16),
          _buildStatisticsSection(data),
          pw.SizedBox(height: 16),
          _buildImportantEventsSection(data, dateTimeFormat),
          pw.SizedBox(height: 16),
          _buildWateringHistorySection(data, dateTimeFormat),
          pw.SizedBox(height: 16),
          _buildSensorDataTable(data, dateTimeFormat),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(ReportData data, DateFormat dateFormat) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Laporan Monitoring Greenhouse',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                data.greenhouseName,
                style: const pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'StrawSmart',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                ),
                pw.Text(
                  'Farming System',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context, ReportData data) {
    final dateTimeFormat = DateFormat('dd MMM yyyy HH:mm:ss', 'id_ID');
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Dibuat: ${dateTimeFormat.format(data.generatedAt)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummarySection(ReportData data, DateFormat dateFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Ringkasan Laporan',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            children: [
              _buildSummaryItem(
                'Periode',
                '${dateFormat.format(data.startDate)} - ${dateFormat.format(data.endDate)}',
              ),
              pw.SizedBox(width: 40),
              _buildSummaryItem('Durasi', '${data.dayCount} hari'),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildSummaryItem(
                'Total Data Sensor',
                '${data.readings.length} pembacaan',
              ),
              pw.SizedBox(width: 40),
              _buildSummaryItem(
                'Total Penyiraman',
                '${data.wateringHistory.length}x (${data.totalWateringMinutes} menit)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatisticsSection(ReportData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Statistik Sensor',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            _buildStatCard(
              'Suhu',
              data.temperatureStats,
              '°C',
              PdfColors.orange,
            ),
            pw.SizedBox(width: 12),
            _buildStatCard(
              'Kelembaban Udara',
              data.humidityStats,
              '%',
              PdfColors.blue,
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          children: [
            _buildStatCard(
              'Kelembaban Tanah',
              data.soilMoistureStats,
              '%',
              PdfColors.brown,
            ),
            pw.SizedBox(width: 12),
            _buildStatCard(
              'Intensitas Cahaya',
              data.lightStats,
              ' lux',
              PdfColors.yellow800,
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildStatCard(
    String title,
    SensorStats stats,
    String unit,
    PdfColor color,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 8),
            if (stats.hasData) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatValue('Min', stats.min, unit),
                  _buildStatValue('Rata-rata', stats.average, unit),
                  _buildStatValue('Max', stats.max, unit),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${stats.count} data',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey500,
                ),
              ),
            ] else
              pw.Text(
                'Tidak ada data',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildStatValue(String label, double value, String unit) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
        ),
        pw.Text(
          '${value.toStringAsFixed(1)}$unit',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildImportantEventsSection(
    ReportData data,
    DateFormat dateTimeFormat,
  ) {
    // Limit to max 10 events to avoid too many pages
    const maxEventsInPdf = 10;
    final events = data.importantEvents.take(maxEventsInPdf).toList();

    if (events.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.green50,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          children: [
            pw.Text(
              '✓',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green700,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text(
                'Tidak ada kejadian penting dalam periode ini.',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.green800),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Kejadian Penting',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Total: ${data.importantEvents.length} kejadian',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          context: null,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellHeight: 25,
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.centerLeft,
          },
          headers: ['Waktu', 'Jenis', 'Keterangan'],
          data: events.map((event) => [
            dateTimeFormat.format(event.timestamp),
            event.type.label,
            event.message,
          ]).toList(),
        ),
        if (data.importantEvents.length > maxEventsInPdf)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              '... dan ${data.importantEvents.length - maxEventsInPdf} kejadian lainnya',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ),
      ],
    );
  }

  pw.Widget _buildWateringHistorySection(
    ReportData data,
    DateFormat dateTimeFormat,
  ) {
    if (data.wateringHistory.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue50,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          'Tidak ada riwayat penyiraman dalam periode ini.',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.blue800),
        ),
      );
    }

    // Limit to max 10 events
    const maxWateringInPdf = 10;
    final events = data.wateringHistory.take(maxWateringInPdf).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Riwayat Penyiraman',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Total: ${data.wateringHistory.length}x',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          context: null,
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
          cellHeight: 25,
          headers: ['Waktu', 'Durasi', 'Sumber', 'Jadwal'],
          data: events.map((event) => [
            dateTimeFormat.format(event.timestamp),
            event.durationText,
            event.source.label,
            event.scheduleName ?? '-',
          ]).toList(),
        ),
        if (data.wateringHistory.length > maxWateringInPdf)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              '... dan ${data.wateringHistory.length - maxWateringInPdf} penyiraman lainnya',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ),
      ],
    );
  }

  pw.Widget _buildSensorDataTable(
    ReportData data,
    DateFormat dateTimeFormat,
  ) {
    if (data.readings.isEmpty) {
      return pw.SizedBox();
    }

    // Smart sampling - max 20 rows for PDF
    const maxRowsInPdf = 20;
    
    final totalReadings = data.readings.length;
    List<int> sampledIndices;
    
    if (totalReadings <= maxRowsInPdf) {
      sampledIndices = List.generate(totalReadings, (i) => i);
    } else {
      // Sample evenly across the dataset
      final step = totalReadings / maxRowsInPdf;
      sampledIndices = List.generate(
        maxRowsInPdf,
        (i) => (i * step).floor().clamp(0, totalReadings - 1),
      );
      // Ensure first and last reading included
      sampledIndices[0] = 0;
      sampledIndices[sampledIndices.length - 1] = totalReadings - 1;
      // Remove duplicates and sort
      sampledIndices = sampledIndices.toSet().toList()..sort();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Data Sensor (Sampel)',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              '${sampledIndices.length} dari $totalReadings data',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          context: null,
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellHeight: 22,
          headers: ['Waktu', 'Suhu (°C)', 'Humid (%)', 'Tanah (%)', 'Cahaya'],
          data: sampledIndices.map((i) {
            final reading = data.readings[i];
            return [
              dateTimeFormat.format(reading.timestamp),
              reading.temperature?.toStringAsFixed(1) ?? '-',
              reading.humidity?.toStringAsFixed(1) ?? '-',
              reading.soilMoisturePercent?.toStringAsFixed(1) ?? '-',
              reading.lightIntensity?.toStringAsFixed(0) ?? '-',
            ];
          }).toList(),
        ),
        if (totalReadings > maxRowsInPdf)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'Data ditampilkan secara sampling. Untuk data lengkap, gunakan export CSV.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue800),
              ),
            ),
          ),
      ],
    );
  }
}
