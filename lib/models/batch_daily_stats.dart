import 'package:cloud_firestore/cloud_firestore.dart';
import 'cultivation_batch.dart';

/// ============================================================
/// MODEL STATISTIK HARIAN BATCH
/// ============================================================
/// Menyimpan agregasi data sensor harian untuk setiap batch.
/// Data ini digunakan untuk:
/// - Tracking kondisi lingkungan per fase
/// - Analisis performa batch
/// - Perbandingan dengan kondisi ideal
/// ============================================================

/// Statistik harian untuk satu batch
class BatchDailyStats {
  const BatchDailyStats({
    required this.id,
    required this.batchId,
    required this.greenhouseId,
    required this.date,
    required this.phase,
    required this.dayNumber,
    this.avgTemperature,
    this.minTemperature,
    this.maxTemperature,
    this.avgHumidity,
    this.minHumidity,
    this.maxHumidity,
    this.avgSoilMoisture,
    this.minSoilMoisture,
    this.maxSoilMoisture,
    this.avgLightLevel,
    this.pumpActivations = 0,
    this.totalPumpDurationSec = 0,
    this.readingsCount = 0,
    this.alerts = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String batchId;
  final String greenhouseId;
  final DateTime date;
  final GrowthPhase phase;
  final int dayNumber; // Hari ke-berapa sejak tanam

  // Temperature stats
  final double? avgTemperature;
  final double? minTemperature;
  final double? maxTemperature;

  // Humidity stats
  final double? avgHumidity;
  final double? minHumidity;
  final double? maxHumidity;

  // Soil moisture stats
  final double? avgSoilMoisture;
  final double? minSoilMoisture;
  final double? maxSoilMoisture;

  // Light stats
  final double? avgLightLevel;

  // Pump/watering stats
  final int pumpActivations;
  final int totalPumpDurationSec;

  // Metadata
  final int readingsCount;
  final List<DailyAlert> alerts;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Check if temperature is within ideal range for the phase
  bool isTemperatureIdeal(PhaseRequirements requirements) {
    if (avgTemperature == null) return true;
    return avgTemperature! >= requirements.minTemp && 
           avgTemperature! <= requirements.maxTemp;
  }

  /// Check if humidity is within ideal range
  bool isHumidityIdeal(PhaseRequirements requirements) {
    if (avgHumidity == null) return true;
    return avgHumidity! >= requirements.minHumidity && 
           avgHumidity! <= requirements.maxHumidity;
  }

  /// Check if soil moisture is within ideal range
  bool isSoilMoistureIdeal(PhaseRequirements requirements) {
    if (avgSoilMoisture == null) return true;
    return avgSoilMoisture! >= requirements.minSoilMoisture && 
           avgSoilMoisture! <= requirements.maxSoilMoisture;
  }

  /// Overall compliance score (0-100%)
  double complianceScore(PhaseRequirements requirements) {
    int total = 0;
    int compliant = 0;

    if (avgTemperature != null) {
      total++;
      if (isTemperatureIdeal(requirements)) compliant++;
    }
    if (avgHumidity != null) {
      total++;
      if (isHumidityIdeal(requirements)) compliant++;
    }
    if (avgSoilMoisture != null) {
      total++;
      if (isSoilMoistureIdeal(requirements)) compliant++;
    }

    return total > 0 ? (compliant / total) * 100 : 100;
  }

  factory BatchDailyStats.fromFirestore(String id, Map<String, dynamic> data) {
    final alertsData = data['alerts'] as List<dynamic>? ?? [];
    
    return BatchDailyStats(
      id: id,
      batchId: data['batchId'] as String? ?? '',
      greenhouseId: data['greenhouseId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      phase: GrowthPhase.values.firstWhere(
        (p) => p.name == data['phase'],
        orElse: () => GrowthPhase.seedling,
      ),
      dayNumber: data['dayNumber'] as int? ?? 0,
      avgTemperature: (data['avgTemperature'] as num?)?.toDouble(),
      minTemperature: (data['minTemperature'] as num?)?.toDouble(),
      maxTemperature: (data['maxTemperature'] as num?)?.toDouble(),
      avgHumidity: (data['avgHumidity'] as num?)?.toDouble(),
      minHumidity: (data['minHumidity'] as num?)?.toDouble(),
      maxHumidity: (data['maxHumidity'] as num?)?.toDouble(),
      avgSoilMoisture: (data['avgSoilMoisture'] as num?)?.toDouble(),
      minSoilMoisture: (data['minSoilMoisture'] as num?)?.toDouble(),
      maxSoilMoisture: (data['maxSoilMoisture'] as num?)?.toDouble(),
      avgLightLevel: (data['avgLightLevel'] as num?)?.toDouble(),
      pumpActivations: data['pumpActivations'] as int? ?? 0,
      totalPumpDurationSec: data['totalPumpDurationSec'] as int? ?? 0,
      readingsCount: data['readingsCount'] as int? ?? 0,
      alerts: alertsData
          .map((a) => DailyAlert.fromJson(a as Map<String, dynamic>))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'batchId': batchId,
      'greenhouseId': greenhouseId,
      'date': Timestamp.fromDate(date),
      'phase': phase.name,
      'dayNumber': dayNumber,
      'avgTemperature': avgTemperature,
      'minTemperature': minTemperature,
      'maxTemperature': maxTemperature,
      'avgHumidity': avgHumidity,
      'minHumidity': minHumidity,
      'maxHumidity': maxHumidity,
      'avgSoilMoisture': avgSoilMoisture,
      'minSoilMoisture': minSoilMoisture,
      'maxSoilMoisture': maxSoilMoisture,
      'avgLightLevel': avgLightLevel,
      'pumpActivations': pumpActivations,
      'totalPumpDurationSec': totalPumpDurationSec,
      'readingsCount': readingsCount,
      'alerts': alerts.map((a) => a.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  BatchDailyStats copyWith({
    double? avgTemperature,
    double? minTemperature,
    double? maxTemperature,
    double? avgHumidity,
    double? minHumidity,
    double? maxHumidity,
    double? avgSoilMoisture,
    double? minSoilMoisture,
    double? maxSoilMoisture,
    double? avgLightLevel,
    int? pumpActivations,
    int? totalPumpDurationSec,
    int? readingsCount,
    List<DailyAlert>? alerts,
  }) {
    return BatchDailyStats(
      id: id,
      batchId: batchId,
      greenhouseId: greenhouseId,
      date: date,
      phase: phase,
      dayNumber: dayNumber,
      avgTemperature: avgTemperature ?? this.avgTemperature,
      minTemperature: minTemperature ?? this.minTemperature,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      avgHumidity: avgHumidity ?? this.avgHumidity,
      minHumidity: minHumidity ?? this.minHumidity,
      maxHumidity: maxHumidity ?? this.maxHumidity,
      avgSoilMoisture: avgSoilMoisture ?? this.avgSoilMoisture,
      minSoilMoisture: minSoilMoisture ?? this.minSoilMoisture,
      maxSoilMoisture: maxSoilMoisture ?? this.maxSoilMoisture,
      avgLightLevel: avgLightLevel ?? this.avgLightLevel,
      pumpActivations: pumpActivations ?? this.pumpActivations,
      totalPumpDurationSec: totalPumpDurationSec ?? this.totalPumpDurationSec,
      readingsCount: readingsCount ?? this.readingsCount,
      alerts: alerts ?? this.alerts,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Alert untuk kondisi di luar range ideal
class DailyAlert {
  const DailyAlert({
    required this.type,
    required this.message,
    required this.severity,
    this.value,
    this.idealMin,
    this.idealMax,
  });

  final AlertType type;
  final String message;
  final AlertSeverity severity;
  final double? value;
  final double? idealMin;
  final double? idealMax;

  factory DailyAlert.fromJson(Map<String, dynamic> json) {
    return DailyAlert(
      type: AlertType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AlertType.other,
      ),
      message: json['message'] as String? ?? '',
      severity: AlertSeverity.values.firstWhere(
        (s) => s.name == json['severity'],
        orElse: () => AlertSeverity.warning,
      ),
      value: (json['value'] as num?)?.toDouble(),
      idealMin: (json['idealMin'] as num?)?.toDouble(),
      idealMax: (json['idealMax'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'message': message,
      'severity': severity.name,
      'value': value,
      'idealMin': idealMin,
      'idealMax': idealMax,
    };
  }
}

enum AlertType {
  temperatureHigh,
  temperatureLow,
  humidityHigh,
  humidityLow,
  soilMoistureHigh,
  soilMoistureLow,
  lightLow,
  pumpFailure,
  other;

  String get label {
    switch (this) {
      case AlertType.temperatureHigh:
        return 'Suhu Terlalu Tinggi';
      case AlertType.temperatureLow:
        return 'Suhu Terlalu Rendah';
      case AlertType.humidityHigh:
        return 'Kelembaban Terlalu Tinggi';
      case AlertType.humidityLow:
        return 'Kelembaban Terlalu Rendah';
      case AlertType.soilMoistureHigh:
        return 'Tanah Terlalu Basah';
      case AlertType.soilMoistureLow:
        return 'Tanah Terlalu Kering';
      case AlertType.lightLow:
        return 'Cahaya Kurang';
      case AlertType.pumpFailure:
        return 'Pompa Bermasalah';
      case AlertType.other:
        return 'Lainnya';
    }
  }

  String get emoji {
    switch (this) {
      case AlertType.temperatureHigh:
        return '🔥';
      case AlertType.temperatureLow:
        return '❄️';
      case AlertType.humidityHigh:
        return '💦';
      case AlertType.humidityLow:
        return '🏜️';
      case AlertType.soilMoistureHigh:
        return '🌊';
      case AlertType.soilMoistureLow:
        return '🏜️';
      case AlertType.lightLow:
        return '🌑';
      case AlertType.pumpFailure:
        return '⚠️';
      case AlertType.other:
        return '❓';
    }
  }
}

enum AlertSeverity {
  info,
  warning,
  critical;

  int get colorValue {
    switch (this) {
      case AlertSeverity.info:
        return 0xFF2196F3; // Blue
      case AlertSeverity.warning:
        return 0xFFFF9800; // Orange
      case AlertSeverity.critical:
        return 0xFFF44336; // Red
    }
  }
}

/// Statistik agregat per fase
class PhaseStats {
  const PhaseStats({
    required this.phase,
    required this.startDate,
    this.endDate,
    required this.totalDays,
    this.avgTemperature,
    this.avgHumidity,
    this.avgSoilMoisture,
    this.compliancePercent,
    this.totalAlerts = 0,
    this.totalWateringMin = 0,
  });

  final GrowthPhase phase;
  final DateTime startDate;
  final DateTime? endDate;
  final int totalDays;
  final double? avgTemperature;
  final double? avgHumidity;
  final double? avgSoilMoisture;
  final double? compliancePercent;
  final int totalAlerts;
  final int totalWateringMin;

  /// Calculate from list of daily stats
  factory PhaseStats.fromDailyStats(
    GrowthPhase phase,
    List<BatchDailyStats> dailyStats,
    PhaseRequirements requirements,
  ) {
    if (dailyStats.isEmpty) {
      return PhaseStats(
        phase: phase,
        startDate: DateTime.now(),
        totalDays: 0,
      );
    }

    // Sort by date
    dailyStats.sort((a, b) => a.date.compareTo(b.date));

    // Calculate averages
    final temps = dailyStats
        .where((s) => s.avgTemperature != null)
        .map((s) => s.avgTemperature!)
        .toList();
    final humidities = dailyStats
        .where((s) => s.avgHumidity != null)
        .map((s) => s.avgHumidity!)
        .toList();
    final soilMoistures = dailyStats
        .where((s) => s.avgSoilMoisture != null)
        .map((s) => s.avgSoilMoisture!)
        .toList();

    // Calculate compliance
    final compliances = dailyStats
        .map((s) => s.complianceScore(requirements))
        .toList();

    // Calculate totals
    final totalAlerts = dailyStats.fold<int>(
      0,
      (runningTotal, stat) => runningTotal + stat.alerts.length,
    );
    final totalWateringMin = dailyStats.fold<int>(
      0,
      (runningTotal, stat) => runningTotal + (stat.totalPumpDurationSec ~/ 60),
    );

    return PhaseStats(
      phase: phase,
      startDate: dailyStats.first.date,
      endDate: dailyStats.last.date,
      totalDays: dailyStats.length,
      avgTemperature: temps.isNotEmpty
          ? temps.reduce((a, b) => a + b) / temps.length
          : null,
      avgHumidity: humidities.isNotEmpty
          ? humidities.reduce((a, b) => a + b) / humidities.length
          : null,
      avgSoilMoisture: soilMoistures.isNotEmpty
          ? soilMoistures.reduce((a, b) => a + b) / soilMoistures.length
          : null,
      compliancePercent: compliances.isNotEmpty
          ? compliances.reduce((a, b) => a + b) / compliances.length
          : null,
      totalAlerts: totalAlerts,
      totalWateringMin: totalWateringMin,
    );
  }
}
