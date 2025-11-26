import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/report_data.dart';
import '../dashboard/dashboard_repository.dart';
import '../monitoring/monitoring_repository.dart';
import '../greenhouse/greenhouse_repository.dart';

/// Provider untuk repository laporan
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final database = FirebaseDatabase.instance;
  final deviceId = ref.watch(dashboardDeviceIdProvider);
  return ReportRepository(database, deviceId: deviceId);
});

/// Provider untuk date range yang dipilih
final reportDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: now.subtract(const Duration(days: 7)),
    end: now,
  );
});

/// Provider untuk generate report data
final reportDataProvider = FutureProvider<ReportData?>((ref) async {
  final dateRange = ref.watch(reportDateRangeProvider);
  final repository = ref.watch(reportRepositoryProvider);
  final greenhouse = ref.watch(selectedGreenhouseProvider);
  
  if (greenhouse == null) return null;
  
  return repository.generateReport(
    greenhouseName: greenhouse.greenhouseName ?? 'Greenhouse',
    greenhouseId: greenhouse.deviceId ?? greenhouse.greenhouseId,
    startDate: dateRange.start,
    endDate: dateRange.end,
  );
});

/// Repository untuk mengambil dan memproses data laporan
class ReportRepository {
  ReportRepository(this._database, {required this.deviceId});

  final FirebaseDatabase _database;
  final String deviceId;

  DatabaseReference get _deviceRef => _database.ref('devices/$deviceId');

  /// Generate report untuk rentang tanggal tertentu
  Future<ReportData> generateReport({
    required String greenhouseName,
    required String greenhouseId,
    required DateTime startDate,
    required DateTime endDate,
    String? generatedBy,
  }) async {
    // Fetch sensor readings
    final readings = await _fetchReadings(startDate, endDate);
    
    // Fetch watering history
    final wateringHistory = await _fetchWateringHistory(startDate, endDate);

    return ReportData(
      greenhouseName: greenhouseName,
      greenhouseId: greenhouseId,
      startDate: startDate,
      endDate: endDate,
      readings: readings,
      wateringHistory: wateringHistory,
      generatedAt: DateTime.now(),
      generatedBy: generatedBy,
    );
  }

  /// Fetch sensor readings dari Firebase RTDB
  Future<List<HistoricalReading>> _fetchReadings(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startTimestamp = (startDate.millisecondsSinceEpoch ~/ 1000).toString();
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    final endTimestamp = (endOfDay.millisecondsSinceEpoch ~/ 1000).toString();

    final snapshot = await _deviceRef
        .child('readings')
        .orderByKey()
        .startAt(startTimestamp)
        .endAt(endTimestamp)
        .get();

    if (!snapshot.exists) {
      return [];
    }

    final data = snapshot.value;
    final List<HistoricalReading> readings = [];

    if (data is Map) {
      data.forEach((key, value) {
        if (value is Map) {
          try {
            final timestampSeconds = int.tryParse(key.toString());
            final reading = HistoricalReading.fromJson(
              key.toString(),
              _castToStringDynamicMap(value),
              timestampKey: timestampSeconds,
            );
            readings.add(reading);
          } catch (e) {
            // Skip invalid entries
          }
        }
      });
    }

    // Sort by timestamp ascending
    readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return readings;
  }

  /// Fetch watering history dari Firebase RTDB
  Future<List<WateringEvent>> _fetchWateringHistory(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    final endTimestamp = endOfDay.millisecondsSinceEpoch ~/ 1000;

    final snapshot = await _deviceRef.child('pump_history').get();

    if (!snapshot.exists) {
      return [];
    }

    final data = snapshot.value;
    final List<WateringEvent> events = [];

    if (data is Map) {
      data.forEach((key, value) {
        if (value is Map) {
          try {
            final timestampSeconds = int.tryParse(key.toString()) ?? 0;
            
            // Filter by date range
            if (timestampSeconds >= startTimestamp && timestampSeconds <= endTimestamp) {
              final castValue = _castToStringDynamicMap(value);
              events.add(WateringEvent(
                timestamp: DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000),
                durationSec: castValue['duration'] as int? ?? 30,
                source: _parseWateringSource(castValue['source'] as String?),
                scheduleName: castValue['schedule_name'] as String?,
              ));
            }
          } catch (e) {
            // Skip invalid entries
          }
        }
      });
    }

    // Sort by timestamp ascending
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return events;
  }

  WateringSource _parseWateringSource(String? source) {
    switch (source?.toLowerCase()) {
      case 'manual':
        return WateringSource.manual;
      case 'scheduled':
      case 'schedule':
        return WateringSource.scheduled;
      case 'automatic':
      case 'auto':
        return WateringSource.automatic;
      default:
        return WateringSource.manual;
    }
  }

  Map<String, dynamic> _castToStringDynamicMap(Map value) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
}
