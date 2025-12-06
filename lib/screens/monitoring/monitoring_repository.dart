import 'dart:math' as math;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/dashboard_repository.dart';

/// Range preset untuk monitoring chart
enum MonitoringRangePreset {
  oneDay('1D', Duration(days: 1)),
  sevenDays('7D', Duration(days: 7)),
  thirtyDays('30D', Duration(days: 30)),
  ninetyDays('90D', Duration(days: 90)),
  all('All', Duration(days: 365 * 10)); // 10 years as "all"

  const MonitoringRangePreset(this.label, this.duration);
  final String label;
  final Duration duration;
}

/// State class untuk monitoring date range
class MonitoringDateRange {
  const MonitoringDateRange({
    required this.startDate,
    required this.endDate,
    required this.preset,
  });

  final DateTime startDate;
  final DateTime endDate;
  final MonitoringRangePreset? preset; // null if custom range

  /// Factory untuk membuat range dari preset
  factory MonitoringDateRange.fromPreset(MonitoringRangePreset preset) {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final startDate = DateTime(now.year, now.month, now.day).subtract(preset.duration).add(const Duration(days: 1));
    return MonitoringDateRange(
      startDate: startDate,
      endDate: endDate,
      preset: preset,
    );
  }

  /// Factory untuk custom range
  factory MonitoringDateRange.custom(DateTime start, DateTime end) {
    return MonitoringDateRange(
      startDate: DateTime(start.year, start.month, start.day),
      endDate: DateTime(end.year, end.month, end.day, 23, 59, 59),
      preset: null,
    );
  }

  /// Copy with new values
  MonitoringDateRange copyWith({
    DateTime? startDate,
    DateTime? endDate,
    MonitoringRangePreset? preset,
  }) {
    return MonitoringDateRange(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      preset: preset,
    );
  }
  
  /// Get duration in days
  int get durationDays => endDate.difference(startDate).inDays + 1;
}

/// Provider untuk tanggal yang dipilih di halaman Monitoring (legacy - keep for compatibility)
/// Default: hari ini
final selectedMonitoringDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Provider untuk date range di halaman Monitoring
/// Default: 1 Day preset
final monitoringDateRangeProvider = StateNotifierProvider<MonitoringDateRangeNotifier, MonitoringDateRange>((ref) {
  return MonitoringDateRangeNotifier();
});

class MonitoringDateRangeNotifier extends StateNotifier<MonitoringDateRange> {
  MonitoringDateRangeNotifier() : super(MonitoringDateRange.fromPreset(MonitoringRangePreset.oneDay));

  void setPreset(MonitoringRangePreset preset) {
    state = MonitoringDateRange.fromPreset(preset);
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = MonitoringDateRange.custom(start, end);
  }

  void reset() {
    state = MonitoringDateRange.fromPreset(MonitoringRangePreset.oneDay);
  }
}

/// Monitoring repository menggunakan deviceId yang sama dengan dashboard
final monitoringRepositoryProvider = Provider<MonitoringRepository>((ref) {
  final database = FirebaseDatabase.instance;
  final deviceId = ref.watch(dashboardDeviceIdProvider);
  return MonitoringRepository(database, deviceId: deviceId);
});

/// Provider untuk historical readings yang sudah difilter berdasarkan tanggal terpilih (legacy)
final historicalReadingsProvider = StreamProvider<List<HistoricalReading>>((ref) {
  final selectedDate = ref.watch(selectedMonitoringDateProvider);
  return ref.watch(monitoringRepositoryProvider).watchHistoricalReadingsByDate(selectedDate);
});

/// Provider untuk historical readings berdasarkan date range
final historicalReadingsByRangeProvider = StreamProvider<List<HistoricalReading>>((ref) {
  final dateRange = ref.watch(monitoringDateRangeProvider);
  return ref.watch(monitoringRepositoryProvider).watchHistoricalReadingsByRange(
    dateRange.startDate,
    dateRange.endDate,
  );
});

class MonitoringRepository {
  MonitoringRepository(this._database, {required this.deviceId});

  final FirebaseDatabase _database;
  final String deviceId;

  DatabaseReference get _deviceRef => _database.ref('devices/$deviceId');

  /// Watch historical sensor readings untuk tanggal tertentu.
  /// New structure: devices/{deviceId}/readings/{timestamp}
  /// We filter by date range instead of nested date folders
  Stream<List<HistoricalReading>> watchHistoricalReadingsByDate(DateTime date) {
    // Calculate start and end of day in Unix timestamp (seconds)
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
    
    final startTimestamp = startOfDay.millisecondsSinceEpoch ~/ 1000;
    final endTimestamp = endOfDay.millisecondsSinceEpoch ~/ 1000;
    
    return _deviceRef
        .child('readings')
        .orderByKey()
        .startAt(startTimestamp.toString())
        .endAt(endTimestamp.toString())
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) {
        return <HistoricalReading>[];
      }

      final List<HistoricalReading> readings = [];

      if (data is Map) {
        _parseReadingsMap(data, readings);
      }

      // Sort by timestamp descending (newest first)
      readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return readings;
    });
  }

  /// Watches historical sensor readings from Firebase Realtime Database.
  /// New structure uses flat timestamp keys: readings/{timestamp}
  Stream<List<HistoricalReading>> watchHistoricalReadings() {
    return _deviceRef.child('readings').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) {
        return <HistoricalReading>[];
      }

      final List<HistoricalReading> readings = [];

      if (data is Map) {
        _parseReadingsMap(data, readings);
      }

      // Sort by timestamp descending (newest first)
      readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return readings;
    });
  }

  /// Watch historical sensor readings for date range.
  Stream<List<HistoricalReading>> watchHistoricalReadingsByRange(DateTime startDate, DateTime endDate) {
    final startTimestamp = startDate.millisecondsSinceEpoch ~/ 1000;
    final endTimestamp = endDate.millisecondsSinceEpoch ~/ 1000;
    
    return _deviceRef
        .child('readings')
        .orderByKey()
        .startAt(startTimestamp.toString())
        .endAt(endTimestamp.toString())
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) {
        return <HistoricalReading>[];
      }

      final List<HistoricalReading> readings = [];

      if (data is Map) {
        _parseReadingsMap(data, readings);
      }

      // Sort by timestamp ascending (oldest first for charts)
      readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return readings;
    });
  }

  /// Parse readings map from new flat structure: readings/{timestamp}/{sensorData}
  void _parseReadingsMap(Map data, List<HistoricalReading> readings) {
    data.forEach((key, value) {
      if (value is Map) {
        try {
          // Key is the timestamp (Unix seconds)
          final timestampSeconds = int.tryParse(key.toString());
          final reading = HistoricalReading.fromJson(
            key.toString(),
            _castToStringDynamicMap(value),
            timestampKey: timestampSeconds,
          );
          readings.add(reading);
        } catch (e) {
          // Skip invalid entries
          debugPrint('[MonitoringRepo] Failed to parse reading $key: $e');
        }
      }
    });
  }

  /// Fetches historical readings for a specific date range.
  Future<List<HistoricalReading>> getReadingsInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startTimestamp = (startDate.millisecondsSinceEpoch ~/ 1000).toString();
    final endTimestamp = (endDate.millisecondsSinceEpoch ~/ 1000).toString();
    
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
      _parseReadingsMap(data, readings);
    }

    // Sort by timestamp descending
    readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return readings;
  }
}

class HistoricalReading {
  const HistoricalReading({
    required this.id,
    required this.timestamp,
    this.temperature,
    this.humidity,
    this.soilMoisturePercent,
    this.lightIntensity,
  });

  final String id;
  final DateTime timestamp;
  final double? temperature;
  final double? humidity;
  final double? soilMoisturePercent;
  final double? lightIntensity;

  factory HistoricalReading.fromJson(
    String id,
    Map<String, dynamic> json, {
    String? parentKey,
    String? currentKey,
    int? timestampKey,
  }) {
    // Priority 1: Use timestampKey if provided (from new structure where key is timestamp)
    int timestampMillis = 0;
    if (timestampKey != null) {
      timestampMillis = timestampKey * 1000; // Convert seconds to milliseconds
    }
    
    // Priority 2: Use timestamp field if present
    if (timestampMillis == 0) {
      final timestampSeconds = _asInt(json['timestamp']);
      timestampMillis = timestampSeconds != null ? timestampSeconds * 1000 : 0;
    }
    
    // Priority 3: Build from parent date key + current time key (legacy structure)
    if (timestampMillis == 0 && parentKey != null && currentKey != null) {
      timestampMillis = _parseFromDateTimeKeys(parentKey, currentKey);
    }
    
    // Priority 4: Parse from combined id string
    if (timestampMillis == 0) {
      timestampMillis = _parseTimestampFromId(id);
    }
    
    // Fallback to current time if all else fails
    if (timestampMillis == 0) {
      timestampMillis = DateTime.now().millisecondsSinceEpoch;
    }
    
    // Support both old and new field names
    final tempValue = json.containsKey('temperatureCelsius') 
        ? json['temperatureCelsius'] 
        : json['temperature'];
    final humidValue = json.containsKey('humidityPercent')
        ? json['humidityPercent']
        : json['humidity'];
    final lightValue = json.containsKey('lightIntensityRaw')
        ? json['lightIntensityRaw']
        : (json['lightIntensity'] ?? json['light']);
    
    return HistoricalReading(
      id: id,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMillis),
      temperature: _asDouble(tempValue),
      humidity: _asDouble(humidValue),
      soilMoisturePercent: _asDouble(json['soilMoisturePercent']),
      lightIntensity: _asDouble(lightValue),
    );
  }

  /// Parse timestamp from separate date and time keys.
  /// Example: parentKey="2025-11-16", currentKey="20:59:54"
  /// Assumes data is in UTC+7 (WIB - Waktu Indonesia Barat) and converts to local time.
  static int _parseFromDateTimeKeys(String dateKey, String timeKey) {
    try {
      // Parse date (YYYY-MM-DD)
      final dateParts = dateKey.split('-');
      if (dateParts.length != 3) return 0;
      
      final year = int.tryParse(dateParts[0]) ?? 0;
      final month = int.tryParse(dateParts[1]) ?? 0;
      final day = int.tryParse(dateParts[2]) ?? 0;
      
      if (year == 0 || month == 0 || day == 0) return 0;
      
      // Parse time (HH:mm:ss)
      final timeParts = timeKey.split(':');
      if (timeParts.isEmpty) return 0;
      
      final hour = timeParts.isNotEmpty ? (int.tryParse(timeParts[0]) ?? 0) : 0;
      final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
      final second = timeParts.length > 2 ? (int.tryParse(timeParts[2]) ?? 0) : 0;
      
      // Create DateTime in UTC+7 (WIB timezone)
      // UTC+7 is 7 hours ahead of UTC
      final wibDateTime = DateTime.utc(year, month, day, hour, minute, second).subtract(const Duration(hours: 7));
      
      // Convert to local time
      final localDateTime = wibDateTime.toLocal();
      return localDateTime.millisecondsSinceEpoch;
    } catch (e) {
      return 0;
    }
  }

  static int _parseTimestampFromId(String id) {
    try {
      // Try to parse as integer timestamp
      final parsed = int.tryParse(id);
      if (parsed != null) return parsed;
      
      // Try to parse date/time format: "2024-11-17/14:30:45" or nested paths
      if (id.contains('/')) {
        final parts = id.split('/');
        if (parts.length >= 2) {
          // Get the last two parts which should be date and time
          final datePart = parts.length > 2 ? parts[parts.length - 2] : parts[0];
          final timePart = parts.last;
          
          // Parse date (YYYY-MM-DD)
          final dateParts = datePart.split('-');
          if (dateParts.length == 3) {
            final year = int.tryParse(dateParts[0]) ?? DateTime.now().year;
            final month = int.tryParse(dateParts[1]) ?? 1;
            final day = int.tryParse(dateParts[2]) ?? 1;
            
            // Parse time (HH:mm:ss)
            final timeParts = timePart.split(':');
            final hour = timeParts.isNotEmpty ? (int.tryParse(timeParts[0]) ?? 0) : 0;
            final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
            final second = timeParts.length > 2 ? (int.tryParse(timeParts[2]) ?? 0) : 0;
            
            // Assume UTC+7 and convert to local
            final wibDateTime = DateTime.utc(year, month, day, hour, minute, second).subtract(const Duration(hours: 7));
            final localDateTime = wibDateTime.toLocal();
            return localDateTime.millisecondsSinceEpoch;
          }
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'temperature': temperature,
      'humidity': humidity,
      'soilMoisturePercent': soilMoisturePercent,
      'lightIntensity': lightIntensity,
    };
  }
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

Map<String, dynamic> _castToStringDynamicMap(Map value) {
  return value.map((key, value) => MapEntry(key.toString(), value));
}

/// Largest Triangle Three Buckets (LTTB) downsampling algorithm
/// Preserves visual shape while reducing data points for chart performance
class LTTBDownsampler {
  /// Downsample readings using LTTB algorithm
  static List<HistoricalReading> downsample(List<HistoricalReading> data, int threshold) {
    if (data.length <= threshold) return data;
    if (threshold <= 2) return [data.first, data.last];

    final sampled = <HistoricalReading>[];
    
    // Always add the first point
    sampled.add(data.first);

    // Bucket size (excluding first and last)
    final bucketSize = (data.length - 2) / (threshold - 2);

    int a = 0; // Initially, the first point

    for (int i = 0; i < threshold - 2; i++) {
      // Calculate bucket boundaries
      final avgRangeStart = ((i + 1) * bucketSize).floor() + 1;
      final avgRangeEnd = ((i + 2) * bucketSize).floor() + 1;
      final actualEnd = math.min(avgRangeEnd, data.length);

      // Calculate average point for the next bucket
      double avgX = 0;
      double avgY = 0;
      int avgCount = 0;

      for (int j = avgRangeStart; j < actualEnd; j++) {
        avgX += data[j].timestamp.millisecondsSinceEpoch.toDouble();
        avgY += _getPrimaryMetric(data[j]);
        avgCount++;
      }
      
      if (avgCount > 0) {
        avgX /= avgCount;
        avgY /= avgCount;
      }

      // Calculate bucket range for current bucket
      final rangeStart = ((i) * bucketSize).floor() + 1;
      final rangeEnd = math.min(((i + 1) * bucketSize).floor() + 1, data.length);

      // Find point with largest triangle area
      double maxArea = -1;
      int maxAreaIndex = rangeStart;

      final pointAX = data[a].timestamp.millisecondsSinceEpoch.toDouble();
      final pointAY = _getPrimaryMetric(data[a]);

      for (int j = rangeStart; j < rangeEnd; j++) {
        final pointBX = data[j].timestamp.millisecondsSinceEpoch.toDouble();
        final pointBY = _getPrimaryMetric(data[j]);

        // Calculate triangle area using cross product
        final area = ((pointAX - avgX) * (pointBY - pointAY) -
                     (pointAX - pointBX) * (avgY - pointAY)).abs() *
                    0.5;

        if (area > maxArea) {
          maxArea = area;
          maxAreaIndex = j;
        }
      }

      sampled.add(data[maxAreaIndex]);
      a = maxAreaIndex; // Move to the selected point
    }

    // Always add the last point
    sampled.add(data.last);

    return sampled;
  }

  /// Get primary metric value for LTTB calculation (use temperature as primary)
  static double _getPrimaryMetric(HistoricalReading reading) {
    return reading.temperature ?? 0;
  }
}
