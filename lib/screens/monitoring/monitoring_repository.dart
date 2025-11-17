import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final monitoringRepositoryProvider = Provider<MonitoringRepository>((ref) {
  final database = FirebaseDatabase.instance;
  return MonitoringRepository(database, deviceId: 'node_001');
});

final historicalReadingsProvider = StreamProvider<List<HistoricalReading>>((ref) {
  return ref.watch(monitoringRepositoryProvider).watchHistoricalReadings();
});

class MonitoringRepository {
  MonitoringRepository(this._database, {required this.deviceId});

  final FirebaseDatabase _database;
  final String deviceId;

  DatabaseReference get _deviceRef => _database.ref('devices/$deviceId');

  /// Watches historical sensor readings from Firebase Realtime Database.
  /// Handles both flat structure (history/{timestamp}) and nested (history/{date}/{time}).
  Stream<List<HistoricalReading>> watchHistoricalReadings() {
    return _deviceRef.child('history').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) {
        return <HistoricalReading>[];
      }

      final List<HistoricalReading> readings = [];

      if (data is Map) {
        _parseHistoryMap(data, readings);
      }

      // Sort by timestamp descending (newest first)
      readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return readings;
    });
  }

  /// Recursively parse history map to handle both flat and nested structures.
  /// For nested date/time keys like "2025-11-16/20:59:54", the prefix carries the date part.
  void _parseHistoryMap(Map data, List<HistoricalReading> readings, {String prefix = ''}) {
    data.forEach((key, value) {
      if (value is Map) {
        // Check if this is a reading object (has sensor fields) or a nested date/time structure
        final hasTemperature = value.containsKey('temperature');
        final hasTimestamp = value.containsKey('timestamp');
        final hasSensorData = hasTemperature || value.containsKey('humidity') || 
                             value.containsKey('soilMoisturePercent');

        if (hasSensorData || hasTimestamp) {
          // This is a reading object
          try {
            final id = prefix.isNotEmpty ? '$prefix/$key' : key.toString();
            final reading = HistoricalReading.fromJson(
              id,
              _castToStringDynamicMap(value),
              parentKey: prefix,
              currentKey: key.toString(),
            );
            readings.add(reading);
          } catch (e) {
            // Skip invalid entries
          }
        } else {
          // This might be a nested structure (e.g., date folder)
          // Recurse into it
          final newPrefix = prefix.isNotEmpty ? '$prefix/$key' : key.toString();
          _parseHistoryMap(value, readings, prefix: newPrefix);
        }
      }
    });
  }

  /// Fetches historical readings for a specific date range.
  Future<List<HistoricalReading>> getReadingsInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _deviceRef
        .child('history')
        .orderByChild('timestamp')
        .startAt(startDate.millisecondsSinceEpoch)
        .endAt(endDate.millisecondsSinceEpoch)
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
            final reading = HistoricalReading.fromJson(
              key.toString(),
              _castToStringDynamicMap(value),
              parentKey: null,
              currentKey: key.toString(),
            );
            readings.add(reading);
          } catch (e) {
            // Skip invalid entries
          }
        }
      });
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
  }) {
    // Priority 1: Use timestamp field if present
    int timestampMillis = _asInt(json['timestamp']) ?? 0;
    
    // Priority 2: Build from parent date key + current time key
    if (timestampMillis == 0 && parentKey != null && currentKey != null) {
      timestampMillis = _parseFromDateTimeKeys(parentKey, currentKey);
    }
    
    // Priority 3: Parse from combined id string
    if (timestampMillis == 0) {
      timestampMillis = _parseTimestampFromId(id);
    }
    
    // Fallback to current time if all else fails
    if (timestampMillis == 0) {
      timestampMillis = DateTime.now().millisecondsSinceEpoch;
    }
    
    return HistoricalReading(
      id: id,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMillis),
      temperature: _asDouble(json['temperature']),
      humidity: _asDouble(json['humidity']),
      soilMoisturePercent: _asDouble(json['soilMoisturePercent']),
      lightIntensity: _asDouble(json['lightIntensity'] ?? json['light']),
    );
  }

  /// Parse timestamp from separate date and time keys.
  /// Example: parentKey="2025-11-16", currentKey="20:59:54"
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
      
      final dateTime = DateTime(year, month, day, hour, minute, second);
      return dateTime.millisecondsSinceEpoch;
    } catch (e) {
      return 0;
    }
  }

  static int _parseTimestampFromId(String id) {
    try {
      // Try to parse as integer timestamp
      final parsed = int.tryParse(id);
      if (parsed != null) return parsed;
      
      // Try to parse date/time format: "2024-11-17/14:30:45"
      if (id.contains('/')) {
        final parts = id.split('/');
        if (parts.length >= 2) {
          final datePart = parts[0];
          final timePart = parts.length > 2 ? parts.last : parts[1];
          
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
            
            final dateTime = DateTime(year, month, day, hour, minute, second);
            return dateTime.millisecondsSinceEpoch;
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
