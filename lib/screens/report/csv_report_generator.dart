import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../../models/report_data.dart';

/// Service untuk generate CSV/Excel report
class CsvReportGenerator {
  /// Generate CSV string untuk data sensor
  String generateSensorDataCsv(ReportData data) {
    final dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final rows = <List<dynamic>>[
      // Header
      [
        'Timestamp',
        'Suhu (°C)',
        'Kelembaban Udara (%)',
        'Kelembaban Tanah (%)',
        'Intensitas Cahaya (lux)',
      ],
      // Data rows
      ...data.readings.map((reading) => [
            dateTimeFormat.format(reading.timestamp),
            reading.temperature?.toStringAsFixed(2) ?? '',
            reading.humidity?.toStringAsFixed(2) ?? '',
            reading.soilMoisturePercent?.toStringAsFixed(2) ?? '',
            reading.lightIntensity?.toStringAsFixed(2) ?? '',
          ]),
    ];

    return const ListToCsvConverter().convert(rows);
  }

  /// Generate CSV string untuk riwayat penyiraman
  String generateWateringHistoryCsv(ReportData data) {
    final dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final rows = <List<dynamic>>[
      // Header
      [
        'Timestamp',
        'Durasi (detik)',
        'Sumber',
        'Nama Jadwal',
      ],
      // Data rows
      ...data.wateringHistory.map((event) => [
            dateTimeFormat.format(event.timestamp),
            event.durationSec,
            event.source.label,
            event.scheduleName ?? '',
          ]),
    ];

    return const ListToCsvConverter().convert(rows);
  }

  /// Generate CSV string untuk statistik ringkasan
  String generateSummaryCsv(ReportData data) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    final rows = <List<dynamic>>[
      // Meta info
      ['Laporan Monitoring Greenhouse'],
      ['Greenhouse', data.greenhouseName],
      ['ID Greenhouse', data.greenhouseId],
      ['Periode', '${dateFormat.format(data.startDate)} - ${dateFormat.format(data.endDate)}'],
      ['Durasi', '${data.dayCount} hari'],
      ['Dibuat pada', dateTimeFormat.format(data.generatedAt)],
      [],
      // Statistics header
      ['Statistik Sensor'],
      ['Metrik', 'Min', 'Rata-rata', 'Max', 'Jumlah Data'],
      // Temperature
      [
        'Suhu (°C)',
        data.temperatureStats.hasData ? data.temperatureStats.min.toStringAsFixed(2) : '-',
        data.temperatureStats.hasData ? data.temperatureStats.average.toStringAsFixed(2) : '-',
        data.temperatureStats.hasData ? data.temperatureStats.max.toStringAsFixed(2) : '-',
        data.temperatureStats.count,
      ],
      // Humidity
      [
        'Kelembaban Udara (%)',
        data.humidityStats.hasData ? data.humidityStats.min.toStringAsFixed(2) : '-',
        data.humidityStats.hasData ? data.humidityStats.average.toStringAsFixed(2) : '-',
        data.humidityStats.hasData ? data.humidityStats.max.toStringAsFixed(2) : '-',
        data.humidityStats.count,
      ],
      // Soil moisture
      [
        'Kelembaban Tanah (%)',
        data.soilMoistureStats.hasData ? data.soilMoistureStats.min.toStringAsFixed(2) : '-',
        data.soilMoistureStats.hasData ? data.soilMoistureStats.average.toStringAsFixed(2) : '-',
        data.soilMoistureStats.hasData ? data.soilMoistureStats.max.toStringAsFixed(2) : '-',
        data.soilMoistureStats.count,
      ],
      // Light
      [
        'Intensitas Cahaya (lux)',
        data.lightStats.hasData ? data.lightStats.min.toStringAsFixed(2) : '-',
        data.lightStats.hasData ? data.lightStats.average.toStringAsFixed(2) : '-',
        data.lightStats.hasData ? data.lightStats.max.toStringAsFixed(2) : '-',
        data.lightStats.count,
      ],
      [],
      // Watering summary
      ['Ringkasan Penyiraman'],
      ['Total Penyiraman', '${data.wateringHistory.length}x'],
      ['Total Durasi', '${data.totalWateringMinutes} menit'],
      [],
      // Important events count
      ['Kejadian Penting'],
      ['Total Kejadian', data.importantEvents.length],
    ];

    return const ListToCsvConverter().convert(rows);
  }

  /// Generate complete CSV with all data in multiple sheets (as single CSV with sections)
  String generateCompleteCsv(ReportData data) {
    final buffer = StringBuffer();

    // Summary section
    buffer.writeln('=== RINGKASAN ===');
    buffer.writeln(generateSummaryCsv(data));
    buffer.writeln();
    buffer.writeln();

    // Sensor data section
    buffer.writeln('=== DATA SENSOR ===');
    buffer.writeln(generateSensorDataCsv(data));
    buffer.writeln();
    buffer.writeln();

    // Watering history section
    buffer.writeln('=== RIWAYAT PENYIRAMAN ===');
    buffer.writeln(generateWateringHistoryCsv(data));

    return buffer.toString();
  }
}
