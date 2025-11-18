import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Device ID that Flutter dashboard should subscribe to.
final dashboardDeviceIdProvider = Provider<String>((_) => 'greenhouse_node_001');

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
    return _deviceRef.child('status').onValue.map((event) {
      final data = _castSnapshot(event.snapshot.value);
      if (data == null) {
        return null;
      }
      return DeviceStatusData.fromJson(data);
    });
  }

  Stream<PumpStatusData?> watchPump() {
    // Device firmware reports live pump state under /state.
    return _deviceRef.child('state').onValue.map((event) {
      final data = _castSnapshot(event.snapshot.value);
      if (data == null) {
        return null;
      }
      return PumpStatusData.fromJson(data);
    });
  }

  Stream<ControlMode> watchControlMode() {
    return _deviceRef.child('control/mode').onValue.map((event) {
      final raw = event.snapshot.value?.toString();
      return ControlModeX.fromRaw(raw);
    });
  }

  Future<void> sendPumpCommand({required bool turnOn, int durationSeconds = 30}) async {
    final controlRef = _deviceRef.child('control');
    final updates = <String, Object?>{
      'pump': turnOn,
      'duration': turnOn ? durationSeconds : 0,
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
    final lightRaw = json.containsKey('lightIntensity')
        ? json['lightIntensity']
        : json['light'];
    return SensorSnapshot(
      temperature: _asDouble(json['temperature']),
      humidity: _asDouble(json['humidity']),
      soilMoisturePercent: _asDouble(json['soilMoisturePercent']),
      soilMoistureAdc: _asInt(json['soilMoistureADC']),
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

  factory DeviceStatusData.fromJson(Map<String, dynamic> json) {
    return DeviceStatusData(
      online: json['online'] == true,
      lastSeenMillis: _asInt(json['lastSeen']),
      wifiSignalStrength: _asInt(json['wifiSignalStrength']),
      freeMemory: _asInt(json['freeMemory']),
      uptimeMillis: _asInt(json['uptime']),
      autoLogicEnabled: json['autoLogicEnabled'] == true,
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
    final bool? pumpFlag = json['pump'] is bool ? json['pump'] as bool : null;
    final String resolvedStatus;
    final rawStatus = json['status']?.toString();
    if (rawStatus != null && rawStatus.isNotEmpty) {
      resolvedStatus = rawStatus.toUpperCase();
    } else if (pumpFlag != null) {
      resolvedStatus = pumpFlag ? 'ON' : 'OFF';
    } else {
      resolvedStatus = 'OFF';
    }
    final lastChange = _asInt(json['lastChange'] ?? json['lastSync']);
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
