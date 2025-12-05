import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/strawberry_guidance.dart';
import '../../models/guidance_item.dart';
import '../greenhouse/greenhouse_repository.dart';

/// Device ID that Flutter dashboard should subscribe to.
/// Sekarang mengambil dari activeDeviceIdProvider (selected greenhouse)
/// Fallback ke 'greenhouse_node_001' jika belum ada pilihan
final dashboardDeviceIdProvider = Provider<String>((ref) {
  final activeDeviceId = ref.watch(activeDeviceIdProvider);
  return activeDeviceId ?? 'greenhouse_node_001';
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final database = FirebaseDatabase.instance;
  final deviceId = ref.watch(dashboardDeviceIdProvider);
  return DashboardRepository(database, deviceId: deviceId);
});

final latestTelemetryProvider =
    StreamProvider<SensorSnapshot?>((ref) => ref.watch(dashboardRepositoryProvider).watchLatest());

final _rawDeviceStatusProvider =
    StreamProvider<DeviceStatusData?>((ref) => ref.watch(dashboardRepositoryProvider).watchStatus());

/// Combined device status provider that includes telemetry timestamp for better online detection.
/// Uses local receive time to determine if device is online.
/// Note: lastReceivedTime is computed at build time based on current DateTime.now()
final deviceStatusProvider = Provider<AsyncValue<DeviceStatusData?>>((ref) {
  final statusAsync = ref.watch(_rawDeviceStatusProvider);
  final telemetryAsync = ref.watch(latestTelemetryProvider);
  
  final telemetryTimestamp = telemetryAsync.valueOrNull?.timestampMillis;
  
  return statusAsync.when(
    data: (status) {
      if (status == null) return const AsyncValue.data(null);
      
      // Use current time as "last received" since we're actively receiving data
      // This avoids the need for a separate StateProvider that can't be modified during build
      final lastReceived = DateTime.now();
      final enrichedStatus = status.withTelemetryTimestamp(telemetryTimestamp)
          .withLastReceivedTime(lastReceived);
      
      return AsyncValue.data(enrichedStatus);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

final pumpStatusProvider =
    StreamProvider<PumpStatusData?>((ref) => ref.watch(dashboardRepositoryProvider).watchPump());

final controlModeProvider = StreamProvider<ControlMode>((ref) {
  return ref.watch(dashboardRepositoryProvider).watchControlMode();
});

/// Provider untuk rekomendasi budidaya stroberi berdasarkan data sensor terbaru
final strawberryGuidanceProvider = Provider<List<GuidanceItem>>((ref) {
  final snapshot = ref.watch(latestTelemetryProvider).valueOrNull;
  return StrawberryGuidanceService.instance.getRecommendations(snapshot);
});

class DashboardRepository {
  DashboardRepository(this._database, {required this.deviceId});

  final FirebaseDatabase _database;
  final String deviceId;

  DatabaseReference get _deviceRef => _database.ref('devices/$deviceId');

  Stream<SensorSnapshot?> watchLatest() {
    return _deviceRef.child('latest').onValue.map((event) {
      final data = _castSnapshot(event.snapshot.value);
      if (data == null) {
        return null;
      }
      return SensorSnapshot.fromJson(data);
    });
  }

  Stream<DeviceStatusData?> watchStatus() {
    // New structure: info/ contains all device metadata, state, and status
    return _deviceRef.child('info').onValue.map((event) {
      final data = _castSnapshot(event.snapshot.value);
      if (data == null) {
        return null;
      }
      return DeviceStatusData.fromJson(data);
    });
  }

  Stream<PumpStatusData?> watchPump() {
    // New structure: pump state is in info/pumpActive
    return _deviceRef.child('info').onValue.map((event) {
      final data = _castSnapshot(event.snapshot.value);
      if (data == null) return null;
      return PumpStatusData.fromJson(data);
    });
  }

  Stream<ControlMode> watchControlMode() {
    return _deviceRef.child('control/mode').onValue.map((event) {
      final raw = event.snapshot.value?.toString();
      return ControlModeX.fromRaw(raw);
    });
  }

  Future<void> sendPumpCommand({required bool turnOn, int durationSeconds = 60}) async {
    final controlRef = _deviceRef.child('control');
    final updates = <String, Object?>{
      'pumpRequested': turnOn,
      // Send 0 when turning OFF, or the specified duration when turning ON
      'durationSeconds': turnOn ? durationSeconds : 0,
      'updatedAt': ServerValue.timestamp,
    };
    await controlRef.update(updates);
  }

  Future<void> setControlMode(ControlMode mode) {
    return _deviceRef.child('control/mode').set(mode.key);
  }
}

Map<String, dynamic>? _castSnapshot(Object? value) {
  if (value is Map<Object?, Object?>) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  return null;
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

class SensorSnapshot {
  SensorSnapshot({
    this.temperature,
    this.humidity,
    this.soilMoisturePercent,
    this.soilMoistureAdc,
    this.lightIntensity,
    this.timestampMillis,
  });

  final double? temperature;
  final double? humidity;
  final double? soilMoisturePercent;
  final int? soilMoistureAdc;
  final int? lightIntensity;
  final int? timestampMillis;

  factory SensorSnapshot.fromJson(Map<String, dynamic> json) {
    // New structure uses clearer field names
    final tempValue = json.containsKey('temperatureCelsius') 
        ? json['temperatureCelsius'] 
        : json['temperature'];
    final humidValue = json.containsKey('humidityPercent')
        ? json['humidityPercent']
        : json['humidity'];
    final soilRaw = json.containsKey('soilMoistureRaw')
        ? json['soilMoistureRaw']
        : json['soilMoistureADC'];
    final lightRaw = json.containsKey('lightIntensityRaw')
        ? json['lightIntensityRaw']
        : (json.containsKey('lightIntensity') ? json['lightIntensity'] : json['light']);
    
    return SensorSnapshot(
      temperature: _asDouble(tempValue),
      humidity: _asDouble(humidValue),
      soilMoisturePercent: _asDouble(json['soilMoisturePercent']),
      soilMoistureAdc: _asInt(soilRaw),
      lightIntensity: _asInt(lightRaw),
      timestampMillis: _asInt(json['timestamp']),
    );
  }
}

class DeviceStatusData {
  DeviceStatusData({
    required this.online,
    this.lastSeenMillis,
    this.wifiSignalStrength,
    this.freeMemory,
    this.uptimeMillis,
    required this.autoLogicEnabled,
    this.telemetryTimestampMillis,
    this.lastReceivedTime,
  });

  final bool online;
  final int? lastSeenMillis;
  final int? wifiSignalStrength;
  final int? freeMemory;
  final int? uptimeMillis;
  final bool autoLogicEnabled;
  final int? telemetryTimestampMillis; // From latest/ sensor data
  final DateTime? lastReceivedTime; // LOCAL time when Flutter received data

  /// Returns the most recent activity timestamp (in milliseconds).
  /// Uses the most recent between lastSeenAt and telemetry timestamp.
  /// Handles both Unix seconds and milliseconds formats.
  int? get mostRecentActivityMs {
    int? lastSeenMs;
    int? telemetryMs;
    
    // Convert lastSeenMillis (which is actually Unix seconds) to milliseconds
    if (lastSeenMillis != null) {
      // If value is small (< year 2000 in seconds), it's already seconds
      // Unix seconds for year 2000 = 946684800
      // If value is large (> 1e12), it's already milliseconds
      if (lastSeenMillis! > 1e12) {
        lastSeenMs = lastSeenMillis; // Already milliseconds
      } else {
        lastSeenMs = lastSeenMillis! * 1000; // Convert seconds to ms
      }
    }
    
    // Same for telemetry timestamp
    if (telemetryTimestampMillis != null) {
      if (telemetryTimestampMillis! > 1e12) {
        telemetryMs = telemetryTimestampMillis; // Already milliseconds
      } else {
        telemetryMs = telemetryTimestampMillis! * 1000; // Convert seconds to ms
      }
    }
    
    if (lastSeenMs == null && telemetryMs == null) return null;
    if (lastSeenMs == null) return telemetryMs;
    if (telemetryMs == null) return lastSeenMs;
    
    // Return the more recent one
    return lastSeenMs > telemetryMs ? lastSeenMs : telemetryMs;
  }

  /// Returns true if device is considered online.
  /// Uses LOCAL receive time (when Flutter received data from Firebase).
  /// This is more reliable than device timestamps which may be out of sync.
  /// If no data received in the last 90 seconds, device is considered offline.
  bool get isDeviceOnline {
    // PRIMARY: Use local receive time (most reliable)
    if (lastReceivedTime != null) {
      final diffSeconds = DateTime.now().difference(lastReceivedTime!).inSeconds;
      return diffSeconds <= 90;
    }
    
    // FALLBACK: Use device timestamps if local time not available
    final mostRecentMs = mostRecentActivityMs;
    if (mostRecentMs == null) return false;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffSeconds = (now - mostRecentMs) / 1000;
    
    return diffSeconds <= 90;
  }

  /// Create a copy with telemetry timestamp added
  DeviceStatusData withTelemetryTimestamp(int? telemetryTimestamp) {
    return DeviceStatusData(
      online: online,
      lastSeenMillis: lastSeenMillis,
      wifiSignalStrength: wifiSignalStrength,
      freeMemory: freeMemory,
      uptimeMillis: uptimeMillis,
      autoLogicEnabled: autoLogicEnabled,
      telemetryTimestampMillis: telemetryTimestamp,
      lastReceivedTime: lastReceivedTime,
    );
  }
  
  /// Create a copy with local receive time added
  DeviceStatusData withLastReceivedTime(DateTime? receivedTime) {
    return DeviceStatusData(
      online: online,
      lastSeenMillis: lastSeenMillis,
      wifiSignalStrength: wifiSignalStrength,
      freeMemory: freeMemory,
      uptimeMillis: uptimeMillis,
      autoLogicEnabled: autoLogicEnabled,
      telemetryTimestampMillis: telemetryTimestampMillis,
      lastReceivedTime: receivedTime,
    );
  }

  factory DeviceStatusData.fromJson(Map<String, dynamic> json) {
    // New structure uses clearer field names
    final onlineValue = json.containsKey('isOnline') ? json['isOnline'] : json['online'];
    final lastSeenValue = json.containsKey('lastSeenAt') ? json['lastSeenAt'] : json['lastSeen'];
    final wifiValue = json.containsKey('wifiSignalDbm') ? json['wifiSignalDbm'] : json['wifiSignalStrength'];
    final uptimeValue = json.containsKey('uptimeSeconds') ? json['uptimeSeconds'] : json['uptime'];
    final memoryValue = json.containsKey('freeMemoryBytes') ? json['freeMemoryBytes'] : json['freeMemory'];
    
    return DeviceStatusData(
      online: onlineValue == true,
      lastSeenMillis: _asInt(lastSeenValue),
      wifiSignalStrength: _asInt(wifiValue),
      freeMemory: _asInt(memoryValue),
      uptimeMillis: _asInt(uptimeValue),
      autoLogicEnabled: json['autoModeEnabled'] == true || json['autoLogicEnabled'] == true,
    );
  }
}

class PumpStatusData {
  PumpStatusData({
    required this.status,
    this.lastChangeMillis,
  });

  final String status;
  final int? lastChangeMillis;

  bool get isOn => status.toUpperCase() == 'ON';

  factory PumpStatusData.fromJson(Map<String, dynamic> json) {
    // New structure uses 'pumpActive' field
    final bool? pumpFlag = json.containsKey('pumpActive') 
        ? (json['pumpActive'] is bool ? json['pumpActive'] as bool : null)
        : (json['pump'] is bool ? json['pump'] as bool : null);
    
    final String resolvedStatus;
    final rawStatus = json['status']?.toString();
    if (rawStatus != null && rawStatus.isNotEmpty) {
      resolvedStatus = rawStatus.toUpperCase();
    } else if (pumpFlag != null) {
      resolvedStatus = pumpFlag ? 'ON' : 'OFF';
    } else {
      resolvedStatus = 'OFF';
    }
    
    final lastChange = _asInt(json['lastChange'] ?? json['lastSync'] ?? json['lastSeenAt']);
    return PumpStatusData(
      status: resolvedStatus,
      lastChangeMillis: lastChange,
    );
  }
}

enum ControlMode { auto, manual }

extension ControlModeX on ControlMode {
  String get label => this == ControlMode.auto ? 'Auto' : 'Manual';
  String get key => name;

  static ControlMode fromRaw(String? raw) {
    if (raw?.toLowerCase() == 'manual') {
      return ControlMode.manual;
    }
    return ControlMode.auto;
  }
}
