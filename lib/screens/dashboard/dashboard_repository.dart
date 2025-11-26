import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
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

final deviceStatusProvider =
    StreamProvider<DeviceStatusData?>((ref) => ref.watch(dashboardRepositoryProvider).watchStatus());

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
      
  debugPrint('[DashboardRepo] watchPump: path=devices/$deviceId/info, data=$data');
      
      if (data == null) {
  debugPrint('[DashboardRepo] watchPump: No data at /info, returning null');
        return null;
      }
      
      final pump = PumpStatusData.fromJson(data);
  debugPrint('[DashboardRepo] watchPump: Parsed pump status=${pump.status}, isOn=${pump.isOn}');
      return pump;
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
  });

  final bool online;
  final int? lastSeenMillis;
  final int? wifiSignalStrength;
  final int? freeMemory;
  final int? uptimeMillis;
  final bool autoLogicEnabled;

  /// Returns true if device is considered online.
  /// Checks both the 'online' flag and if lastSeenMillis is within 60 seconds.
  bool get isDeviceOnline {
    if (online) return true;
    
    final lastSeen = lastSeenMillis;
    if (lastSeen == null) return false;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffSeconds = (now - lastSeen) / 1000;
    return diffSeconds <= 60;
  }

  /// Returns a human-readable string showing connection status.
  /// Examples: "Terhubung 5 detik lalu" or "Perangkat offline"
  String get connectionStatusLabel {
    if (!isDeviceOnline) {
      return 'Perangkat offline';
    }
    
    final lastSeen = lastSeenMillis;
    if (lastSeen == null) {
      return 'Terhubung';
    }
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffSeconds = ((now - lastSeen) / 1000).round();
    
    if (diffSeconds < 5) {
      return 'Terhubung (live)';
    } else if (diffSeconds < 60) {
      return 'Terhubung $diffSeconds detik lalu';
    } else {
      return 'Terhubung';
    }
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
