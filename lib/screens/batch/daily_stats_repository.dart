import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/batch_daily_stats.dart';
import '../../models/cultivation_batch.dart';
import 'batch_repository.dart';

/// Repository untuk Daily Stats batch
final dailyStatsRepositoryProvider = Provider<DailyStatsRepository>((ref) {
  return DailyStatsRepository(
    FirebaseFirestore.instance,
    FirebaseDatabase.instance,
  );
});

/// Provider untuk daily stats batch tertentu
final batchDailyStatsProvider = StreamProvider.family<List<BatchDailyStats>, String>((ref, batchId) {
  return ref.watch(dailyStatsRepositoryProvider).watchDailyStats(batchId);
});

/// Provider untuk daily stats hari ini
final todayStatsProvider = StreamProvider.family<BatchDailyStats?, String>((ref, batchId) {
  return ref.watch(dailyStatsRepositoryProvider).watchTodayStats(batchId);
});

/// Provider untuk stats per fase
final phaseStatsProvider = FutureProvider.family<Map<GrowthPhase, PhaseStats>, String>((ref, batchId) async {
  final batch = await ref.watch(batchByIdProvider(batchId).future);
  if (batch == null) return {};
  
  final dailyStats = await ref.watch(batchDailyStatsProvider(batchId).future);
  return ref.watch(dailyStatsRepositoryProvider).calculatePhaseStats(batch, dailyStats);
});

class DailyStatsRepository {
  DailyStatsRepository(this._firestore, this._rtdb);

  final FirebaseFirestore _firestore;
  final FirebaseDatabase _rtdb;

  CollectionReference<Map<String, dynamic>> _dailyStatsCollection(String batchId) =>
      _firestore.collection('cultivationBatches').doc(batchId).collection('dailyStats');

  /// Watch semua daily stats untuk batch
  Stream<List<BatchDailyStats>> watchDailyStats(String batchId) {
    return _dailyStatsCollection(batchId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BatchDailyStats.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Watch daily stats hari ini
  Stream<BatchDailyStats?> watchTodayStats(String batchId) {
    final today = DateTime.now();
    final dateId = _dateToId(today);
    
    return _dailyStatsCollection(batchId).doc(dateId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return BatchDailyStats.fromFirestore(snapshot.id, snapshot.data()!);
    });
  }

  /// Get daily stats untuk range tanggal
  Future<List<BatchDailyStats>> getDailyStatsRange(
    String batchId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = await _dailyStatsCollection(batchId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date')
        .get();

    return snapshot.docs
        .map((doc) => BatchDailyStats.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Aggregate data dari RTDB dan simpan ke daily stats
  Future<void> aggregateDailyStats(CultivationBatch batch, DateTime date) async {
    final dateId = _dateToId(date);
    final dayNumber = date.difference(batch.plantingDate).inDays;
    
    // Get current phase for the day
    final phase = _getPhaseForDay(batch, dayNumber);
    final requirements = batch.phaseSettings[phase]?.requirements ?? 
                         PhaseRequirements.defaultFor(phase);
    
    // Fetch sensor data from RTDB for that day
    final sensorData = await _fetchSensorDataForDate(batch.greenhouseId, date);
    
    if (sensorData.isEmpty) {
      // No data for this day
      return;
    }
    
    // Calculate aggregates
    final temps = sensorData.where((d) => d['temperature'] != null).map((d) => d['temperature'] as double).toList();
    final humidities = sensorData.where((d) => d['humidity'] != null).map((d) => d['humidity'] as double).toList();
    final soilMoistures = sensorData.where((d) => d['soilMoisture'] != null).map((d) => d['soilMoisture'] as double).toList();
    final lightLevels = sensorData.where((d) => d['lightLevel'] != null).map((d) => d['lightLevel'] as double).toList();
    
    // Generate alerts
    final alerts = <DailyAlert>[];
    
    final avgTemp = temps.isNotEmpty ? temps.reduce((a, b) => a + b) / temps.length : null;
    final avgHumidity = humidities.isNotEmpty ? humidities.reduce((a, b) => a + b) / humidities.length : null;
    final avgSoilMoisture = soilMoistures.isNotEmpty ? soilMoistures.reduce((a, b) => a + b) / soilMoistures.length : null;
    
    if (avgTemp != null) {
      if (avgTemp > requirements.maxTemp) {
        alerts.add(DailyAlert(
          type: AlertType.temperatureHigh,
          message: 'Suhu rata-rata ${avgTemp.toStringAsFixed(1)}°C melebihi batas maksimal ${requirements.maxTemp}°C',
          severity: avgTemp > requirements.maxTemp + 5 ? AlertSeverity.critical : AlertSeverity.warning,
          value: avgTemp,
          idealMin: requirements.minTemp,
          idealMax: requirements.maxTemp,
        ));
      } else if (avgTemp < requirements.minTemp) {
        alerts.add(DailyAlert(
          type: AlertType.temperatureLow,
          message: 'Suhu rata-rata ${avgTemp.toStringAsFixed(1)}°C di bawah batas minimal ${requirements.minTemp}°C',
          severity: avgTemp < requirements.minTemp - 5 ? AlertSeverity.critical : AlertSeverity.warning,
          value: avgTemp,
          idealMin: requirements.minTemp,
          idealMax: requirements.maxTemp,
        ));
      }
    }
    
    if (avgHumidity != null) {
      if (avgHumidity > requirements.maxHumidity) {
        alerts.add(DailyAlert(
          type: AlertType.humidityHigh,
          message: 'Kelembaban rata-rata ${avgHumidity.toStringAsFixed(1)}% melebihi batas maksimal',
          severity: AlertSeverity.warning,
          value: avgHumidity,
          idealMin: requirements.minHumidity,
          idealMax: requirements.maxHumidity,
        ));
      } else if (avgHumidity < requirements.minHumidity) {
        alerts.add(DailyAlert(
          type: AlertType.humidityLow,
          message: 'Kelembaban rata-rata ${avgHumidity.toStringAsFixed(1)}% di bawah batas minimal',
          severity: AlertSeverity.warning,
          value: avgHumidity,
          idealMin: requirements.minHumidity,
          idealMax: requirements.maxHumidity,
        ));
      }
    }
    
    if (avgSoilMoisture != null) {
      if (avgSoilMoisture > requirements.maxSoilMoisture) {
        alerts.add(DailyAlert(
          type: AlertType.soilMoistureHigh,
          message: 'Kelembaban tanah ${avgSoilMoisture.toStringAsFixed(1)}% terlalu tinggi',
          severity: AlertSeverity.warning,
          value: avgSoilMoisture,
          idealMin: requirements.minSoilMoisture,
          idealMax: requirements.maxSoilMoisture,
        ));
      } else if (avgSoilMoisture < requirements.minSoilMoisture) {
        alerts.add(DailyAlert(
          type: AlertType.soilMoistureLow,
          message: 'Kelembaban tanah ${avgSoilMoisture.toStringAsFixed(1)}% terlalu rendah',
          severity: AlertSeverity.warning,
          value: avgSoilMoisture,
          idealMin: requirements.minSoilMoisture,
          idealMax: requirements.maxSoilMoisture,
        ));
      }
    }

    // Create or update daily stats
    final stats = BatchDailyStats(
      id: dateId,
      batchId: batch.id,
      greenhouseId: batch.greenhouseId,
      date: date,
      phase: phase,
      dayNumber: dayNumber,
      avgTemperature: avgTemp,
      minTemperature: temps.isNotEmpty ? temps.reduce((a, b) => a < b ? a : b) : null,
      maxTemperature: temps.isNotEmpty ? temps.reduce((a, b) => a > b ? a : b) : null,
      avgHumidity: avgHumidity,
      minHumidity: humidities.isNotEmpty ? humidities.reduce((a, b) => a < b ? a : b) : null,
      maxHumidity: humidities.isNotEmpty ? humidities.reduce((a, b) => a > b ? a : b) : null,
      avgSoilMoisture: avgSoilMoisture,
      minSoilMoisture: soilMoistures.isNotEmpty ? soilMoistures.reduce((a, b) => a < b ? a : b) : null,
      maxSoilMoisture: soilMoistures.isNotEmpty ? soilMoistures.reduce((a, b) => a > b ? a : b) : null,
      avgLightLevel: lightLevels.isNotEmpty ? lightLevels.reduce((a, b) => a + b) / lightLevels.length : null,
      readingsCount: sensorData.length,
      alerts: alerts,
    );

    await _dailyStatsCollection(batch.id).doc(dateId).set(
      stats.toFirestoreCreate(),
      SetOptions(merge: true),
    );
  }

  /// Calculate phase stats from daily stats
  Map<GrowthPhase, PhaseStats> calculatePhaseStats(
    CultivationBatch batch,
    List<BatchDailyStats> dailyStats,
  ) {
    final result = <GrowthPhase, PhaseStats>{};
    
    for (final phase in GrowthPhase.values) {
      final phaseStats = dailyStats.where((s) => s.phase == phase).toList();
      if (phaseStats.isNotEmpty) {
        final requirements = batch.phaseSettings[phase]?.requirements ??
                            PhaseRequirements.defaultFor(phase);
        result[phase] = PhaseStats.fromDailyStats(phase, phaseStats, requirements);
      }
    }
    
    return result;
  }

  /// Fetch sensor data from RTDB for a specific date
  Future<List<Map<String, dynamic>>> _fetchSensorDataForDate(
    String greenhouseId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    // Query readings collection for the device
    final ref = _rtdb.ref('devices/$greenhouseId/readings');
    
    try {
      // Get readings ordered by timestamp
      final snapshot = await ref
          .orderByChild('timestamp')
          .startAt(startOfDay.millisecondsSinceEpoch)
          .endAt(endOfDay.millisecondsSinceEpoch - 1)
          .get();
      
      if (!snapshot.exists) return [];
      
      final data = <Map<String, dynamic>>[];
      final value = snapshot.value;
      
      if (value is Map) {
        for (final entry in value.entries) {
          if (entry.value is Map) {
            final reading = Map<String, dynamic>.from(entry.value as Map);
            data.add({
              'temperature': (reading['temperature'] as num?)?.toDouble(),
              'humidity': (reading['humidity'] as num?)?.toDouble(),
              'soilMoisture': (reading['soilMoisture'] as num?)?.toDouble(),
              'lightLevel': (reading['lightLevel'] as num?)?.toDouble(),
              'timestamp': reading['timestamp'],
            });
          }
        }
      }
      
      return data;
    } catch (e) {
      // If no readings collection or error, try latest data
      return [];
    }
  }

  GrowthPhase _getPhaseForDay(CultivationBatch batch, int dayNumber) {
    // Check phase transitions first
    if (batch.phaseTransitions.isNotEmpty) {
      final targetDate = batch.plantingDate.add(Duration(days: dayNumber));
      GrowthPhase latestPhase = GrowthPhase.seedling;
      
      for (final phase in GrowthPhase.values) {
        final transitionDate = batch.phaseTransitions[phase];
        if (transitionDate != null && transitionDate.isBefore(targetDate)) {
          latestPhase = phase;
        }
      }
      return latestPhase;
    }
    
    // Fallback to duration-based
    int cumulativeDays = 0;
    for (final phase in GrowthPhase.values) {
      cumulativeDays += batch.phaseSettings[phase]?.durationDays ?? 
                        CultivationBatch.defaultPhaseDuration(phase);
      if (dayNumber < cumulativeDays) {
        return phase;
      }
    }
    return GrowthPhase.harvesting;
  }

  String _dateToId(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Service untuk menjalankan agregasi harian secara periodik
class DailyStatsAggregatorService {
  DailyStatsAggregatorService(this._repository);

  final DailyStatsRepository _repository;

  /// Aggregate stats untuk batch tertentu dari tanggal tanam sampai hari ini
  Future<void> backfillBatchStats(CultivationBatch batch) async {
    final today = DateTime.now();
    var currentDate = batch.plantingDate;
    
    while (currentDate.isBefore(today)) {
      await _repository.aggregateDailyStats(batch, currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }
  }
}
