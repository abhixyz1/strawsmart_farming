import '../screens/monitoring/monitoring_repository.dart';

/// Model untuk data laporan
class ReportData {
  const ReportData({
    required this.greenhouseName,
    required this.greenhouseId,
    required this.startDate,
    required this.endDate,
    required this.readings,
    required this.wateringHistory,
    required this.generatedAt,
    this.generatedBy,
  });

  final String greenhouseName;
  final String greenhouseId;
  final DateTime startDate;
  final DateTime endDate;
  final List<HistoricalReading> readings;
  final List<WateringEvent> wateringHistory;
  final DateTime generatedAt;
  final String? generatedBy;

  /// Statistik suhu
  SensorStats get temperatureStats => SensorStats.fromValues(
        readings.map((r) => r.temperature).whereType<double>().toList(),
      );

  /// Statistik kelembaban udara
  SensorStats get humidityStats => SensorStats.fromValues(
        readings.map((r) => r.humidity).whereType<double>().toList(),
      );

  /// Statistik kelembaban tanah
  SensorStats get soilMoistureStats => SensorStats.fromValues(
        readings.map((r) => r.soilMoisturePercent).whereType<double>().toList(),
      );

  /// Statistik intensitas cahaya
  SensorStats get lightStats => SensorStats.fromValues(
        readings.map((r) => r.lightIntensity).whereType<double>().toList(),
      );

  /// Total durasi penyiraman dalam menit
  int get totalWateringMinutes {
    return wateringHistory.fold(0, (sum, e) => sum + (e.durationSec ~/ 60));
  }

  /// Jumlah hari dalam rentang
  int get dayCount {
    return endDate.difference(startDate).inDays + 1;
  }

  /// Kejadian penting berdasarkan threshold
  List<ImportantEvent> get importantEvents {
    final events = <ImportantEvent>[];

    for (final reading in readings) {
      // Suhu tinggi (> 35°C)
      if (reading.temperature != null && reading.temperature! > 35) {
        events.add(ImportantEvent(
          timestamp: reading.timestamp,
          type: EventType.highTemperature,
          value: reading.temperature!,
          message: 'Suhu tinggi: ${reading.temperature!.toStringAsFixed(1)}°C',
        ));
      }

      // Suhu rendah (< 15°C)
      if (reading.temperature != null && reading.temperature! < 15) {
        events.add(ImportantEvent(
          timestamp: reading.timestamp,
          type: EventType.lowTemperature,
          value: reading.temperature!,
          message: 'Suhu rendah: ${reading.temperature!.toStringAsFixed(1)}°C',
        ));
      }

      // Kelembaban tanah rendah (< 30%)
      if (reading.soilMoisturePercent != null && reading.soilMoisturePercent! < 30) {
        events.add(ImportantEvent(
          timestamp: reading.timestamp,
          type: EventType.lowSoilMoisture,
          value: reading.soilMoisturePercent!,
          message: 'Tanah kering: ${reading.soilMoisturePercent!.toStringAsFixed(1)}%',
        ));
      }

      // Kelembaban udara rendah (< 40%)
      if (reading.humidity != null && reading.humidity! < 40) {
        events.add(ImportantEvent(
          timestamp: reading.timestamp,
          type: EventType.lowHumidity,
          value: reading.humidity!,
          message: 'Kelembaban rendah: ${reading.humidity!.toStringAsFixed(1)}%',
        ));
      }
    }

    // Sort by timestamp descending
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Limit to most recent 50 events
    return events.take(50).toList();
  }
}

/// Statistik untuk satu jenis sensor
class SensorStats {
  const SensorStats({
    required this.min,
    required this.max,
    required this.average,
    required this.count,
  });

  final double min;
  final double max;
  final double average;
  final int count;

  factory SensorStats.fromValues(List<double> values) {
    if (values.isEmpty) {
      return const SensorStats(min: 0, max: 0, average: 0, count: 0);
    }

    final sum = values.reduce((a, b) => a + b);
    return SensorStats(
      min: values.reduce((a, b) => a < b ? a : b),
      max: values.reduce((a, b) => a > b ? a : b),
      average: sum / values.length,
      count: values.length,
    );
  }

  bool get hasData => count > 0;
}

/// Event penyiraman
class WateringEvent {
  const WateringEvent({
    required this.timestamp,
    required this.durationSec,
    required this.source,
    this.scheduleName,
  });

  final DateTime timestamp;
  final int durationSec;
  final WateringSource source;
  final String? scheduleName;

  String get durationText {
    final minutes = durationSec ~/ 60;
    final seconds = durationSec % 60;
    if (minutes > 0) {
      return '$minutes menit ${seconds > 0 ? '$seconds detik' : ''}';
    }
    return '$seconds detik';
  }
}

enum WateringSource {
  manual,
  scheduled,
  automatic;

  String get label {
    switch (this) {
      case WateringSource.manual:
        return 'Manual';
      case WateringSource.scheduled:
        return 'Terjadwal';
      case WateringSource.automatic:
        return 'Otomatis';
    }
  }
}

/// Kejadian penting
class ImportantEvent {
  const ImportantEvent({
    required this.timestamp,
    required this.type,
    required this.value,
    required this.message,
  });

  final DateTime timestamp;
  final EventType type;
  final double value;
  final String message;
}

enum EventType {
  highTemperature,
  lowTemperature,
  highHumidity,
  lowHumidity,
  lowSoilMoisture,
  highSoilMoisture,
  pumpActivated,
  pumpDeactivated;

  String get label {
    switch (this) {
      case EventType.highTemperature:
        return 'Suhu Tinggi';
      case EventType.lowTemperature:
        return 'Suhu Rendah';
      case EventType.highHumidity:
        return 'Kelembaban Tinggi';
      case EventType.lowHumidity:
        return 'Kelembaban Rendah';
      case EventType.lowSoilMoisture:
        return 'Tanah Kering';
      case EventType.highSoilMoisture:
        return 'Tanah Terlalu Basah';
      case EventType.pumpActivated:
        return 'Pompa Aktif';
      case EventType.pumpDeactivated:
        return 'Pompa Nonaktif';
    }
  }

  String get icon {
    switch (this) {
      case EventType.highTemperature:
        return '🔥';
      case EventType.lowTemperature:
        return '❄️';
      case EventType.highHumidity:
      case EventType.lowHumidity:
        return '💧';
      case EventType.lowSoilMoisture:
        return '🏜️';
      case EventType.highSoilMoisture:
        return '🌊';
      case EventType.pumpActivated:
        return '✅';
      case EventType.pumpDeactivated:
        return '⏹️';
    }
  }
}
