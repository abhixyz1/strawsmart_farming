import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/strawberry_guidance.dart';
import '../../models/guidance_item.dart';
import '../greenhouse/greenhouse_repository.dart';

/// DEVELOPMENT MODE: Set true saat testing dengan Wokwi simulator
/// Wokwi memiliki delay 2-5 menit karena processing di server
/// Set false untuk production dengan real ESP32 hardware
const bool isWokwiMode = true;

/// Online detection timeout
/// - Real ESP32: 120 detik (4x telemetry interval 30s)
/// - Wokwi Mode: 300 detik (5 menit) karena delay server simulator
const int onlineTimeoutSeconds = isWokwiMode ? 300 : 120;

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
/// Uses FIREBASE timestamps (lastSeenAt, telemetry timestamp) as primary source.
/// Only uses local receive time as additional signal when new data actually arrives.
final deviceStatusProvider = Provider<AsyncValue<DeviceStatusData?>>((ref) {
  final statusAsync = ref.watch(_rawDeviceStatusProvider);
  final telemetryAsync = ref.watch(latestTelemetryProvider);
  // Also watch pump status - pump ON/OFF changes indicate device is online
  final pumpAsync = ref.watch(pumpStatusProvider);
  
  final telemetryTimestamp = telemetryAsync.valueOrNull?.timestampMillis;
  final pumpLastChange = pumpAsync.valueOrNull?.lastChangeMillis;
  
  return statusAsync.when(
    data: (status) {
      if (status == null) return const AsyncValue.data(null);
      
      // Enrich with telemetry timestamp for cross-checking
      var enrichedStatus = status.withTelemetryTimestamp(telemetryTimestamp);
      
      // IMPORTANT: Only set lastReceivedTime if we have evidence of fresh data
      // by checking if telemetry timestamp or lastSeenAt is recent (within threshold)
      final now = DateTime.now();
      final hasRecentData = enrichedStatus.isDataFresh(now);
      
      if (hasRecentData) {
        enrichedStatus = enrichedStatus.withLastReceivedTime(now);
      }
      
      // Also consider pump lastChange timestamp for online detection
      if (pumpLastChange != null) {
        enrichedStatus = enrichedStatus.withPumpLastChange(pumpLastChange);
      }
      
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

/// Provider untuk jadwal penyiraman dari Firebase
final wateringScheduleProvider = StreamProvider<WateringScheduleData?>((ref) {
  return ref.watch(dashboardRepositoryProvider).watchSchedule();
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

  /// Watch schedule data from Firebase
  Stream<WateringScheduleData?> watchSchedule() {
    return _deviceRef.child('schedule').onValue.map((event) {
      final data = _castSnapshot(event.snapshot.value);
      if (data == null) return null;
      return WateringScheduleData.fromJson(data);
    });
  }

  /// Update a daily schedule item
  Future<void> updateDailySchedule(int index, DailyScheduleItem item) async {
    await _deviceRef.child('schedule/daily/$index').update({
      'time': item.time,
      'duration': item.duration,
      'enabled': item.enabled,
    });
  }

  /// Update moisture threshold settings
  Future<void> updateMoistureThreshold(MoistureThreshold threshold) async {
    await _deviceRef.child('schedule/moisture_threshold').update({
      'enabled': threshold.enabled,
      'trigger_below': threshold.triggerBelow,
      'duration': threshold.duration,
    });
  }

  /// Enable/disable entire schedule
  Future<void> setScheduleEnabled(bool enabled) async {
    await _deviceRef.child('schedule/enabled').set(enabled);
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

  /// Check if Firebase data (lastSeenAt or telemetry) is fresh (within threshold).
  /// Used to validate whether we should consider new data arrival.
  bool isDataFresh(DateTime now) {
    final mostRecentMs = mostRecentActivityMs;
    if (mostRecentMs == null) return false;
    
    final diffSeconds = (now.millisecondsSinceEpoch - mostRecentMs) / 1000;
    return diffSeconds <= onlineTimeoutSeconds;
  }

  /// Returns true if device is considered online.
  /// PRIORITY: Firebase timestamps (lastSeenAt, telemetry) are the SOURCE OF TRUTH.
  /// Local receive time is only used as additional confirmation.
  /// Threshold: Dynamic based on isWokwiMode (300s for Wokwi, 120s for real hardware)
  bool get isDeviceOnline {
    // PRIMARY: Use Firebase device timestamps (most reliable source of truth)
    final mostRecentMs = mostRecentActivityMs;
    if (mostRecentMs != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diffSeconds = (now - mostRecentMs) / 1000;
      
      return diffSeconds <= onlineTimeoutSeconds;
    }
    
    // FALLBACK: Use local receive time if no Firebase timestamp
    if (lastReceivedTime != null) {
      final diffSeconds = DateTime.now().difference(lastReceivedTime!).inSeconds;
      return diffSeconds <= onlineTimeoutSeconds;
    }
    
    // LAST RESORT: Trust the 'online' field from Firebase if no timestamps
    return online;
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
  
  /// Create a copy with pump last change timestamp added
  /// This helps detect online status when pump changes occur
  DeviceStatusData withPumpLastChange(int? pumpLastChange) {
    // Pump change is another signal that the device is active
    // We don't need to store it separately since lastReceivedTime already tracks
    // when we received any data. This method exists for API clarity.
    return this;
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

// ============================================================================
// WATERING SCHEDULE MODELS
// ============================================================================

/// Data jadwal penyiraman dari Firebase
class WateringScheduleData {
  WateringScheduleData({
    required this.enabled,
    required this.dailySchedules,
    this.moistureThreshold,
    this.lastScheduledRun,
  });

  final bool enabled;
  final List<DailyScheduleItem> dailySchedules;
  final MoistureThreshold? moistureThreshold;
  final LastScheduledRun? lastScheduledRun;

  factory WateringScheduleData.fromJson(Map<String, dynamic> json) {
    // Parse daily schedules (bisa array atau map dengan index)
    final List<DailyScheduleItem> dailyList = [];
    final dailyRaw = json['daily'];
    if (dailyRaw is List) {
      for (var i = 0; i < dailyRaw.length; i++) {
        final item = dailyRaw[i];
        if (item is Map) {
          dailyList.add(DailyScheduleItem.fromJson(
            Map<String, dynamic>.from(item),
          ));
        }
      }
    } else if (dailyRaw is Map) {
      // Firebase kadang menyimpan array sebagai map dengan index
      final sorted = dailyRaw.entries.toList()
        ..sort((a, b) => int.parse(a.key.toString()).compareTo(int.parse(b.key.toString())));
      for (var entry in sorted) {
        if (entry.value is Map) {
          dailyList.add(DailyScheduleItem.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ));
        }
      }
    }

    // Parse moisture threshold
    MoistureThreshold? moistureThreshold;
    final moistureRaw = json['moisture_threshold'];
    if (moistureRaw is Map) {
      moistureThreshold = MoistureThreshold.fromJson(
        Map<String, dynamic>.from(moistureRaw),
      );
    }

    // Parse last scheduled run
    LastScheduledRun? lastRun;
    final lastRunRaw = json['last_scheduled_run'];
    if (lastRunRaw is Map) {
      lastRun = LastScheduledRun.fromJson(
        Map<String, dynamic>.from(lastRunRaw),
      );
    }

    return WateringScheduleData(
      enabled: json['enabled'] == true,
      dailySchedules: dailyList,
      moistureThreshold: moistureThreshold,
      lastScheduledRun: lastRun,
    );
  }

  /// Get the next scheduled watering time
  String? get nextScheduledTime {
    if (!enabled || dailySchedules.isEmpty) return null;
    
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    // Find next enabled schedule
    DailyScheduleItem? nextSchedule;
    int minDiff = 24 * 60; // Max diff is 24 hours
    
    for (final schedule in dailySchedules) {
      if (!schedule.enabled) continue;
      
      final parts = schedule.time.split(':');
      if (parts.length != 2) continue;
      
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final scheduleMinutes = hour * 60 + minute;
      
      int diff = scheduleMinutes - currentMinutes;
      if (diff <= 0) {
        diff += 24 * 60; // Next day
      }
      
      if (diff < minDiff) {
        minDiff = diff;
        nextSchedule = schedule;
      }
    }
    
    return nextSchedule?.time;
  }

  /// Get count of enabled daily schedules
  int get enabledCount => dailySchedules.where((s) => s.enabled).length;
}

/// Item jadwal harian
class DailyScheduleItem {
  DailyScheduleItem({
    required this.time,
    required this.duration,
    required this.enabled,
  });

  final String time; // Format "HH:mm"
  final int duration; // Seconds
  final bool enabled;

  factory DailyScheduleItem.fromJson(Map<String, dynamic> json) {
    return DailyScheduleItem(
      time: json['time']?.toString() ?? '00:00',
      duration: _asInt(json['duration']) ?? 60,
      enabled: json['enabled'] == true,
    );
  }

  DailyScheduleItem copyWith({
    String? time,
    int? duration,
    bool? enabled,
  }) {
    return DailyScheduleItem(
      time: time ?? this.time,
      duration: duration ?? this.duration,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Pengaturan penyiraman berdasarkan kelembaban tanah
class MoistureThreshold {
  MoistureThreshold({
    required this.enabled,
    required this.triggerBelow,
    required this.duration,
  });

  final bool enabled;
  final int triggerBelow; // Percentage
  final int duration; // Seconds

  factory MoistureThreshold.fromJson(Map<String, dynamic> json) {
    return MoistureThreshold(
      enabled: json['enabled'] == true,
      triggerBelow: _asInt(json['trigger_below']) ?? 30,
      duration: _asInt(json['duration']) ?? 30,
    );
  }
}

/// Info penyiraman terjadwal terakhir
class LastScheduledRun {
  LastScheduledRun({
    required this.time,
    required this.duration,
    required this.completed,
  });

  final String time;
  final int duration;
  final bool completed;

  factory LastScheduledRun.fromJson(Map<String, dynamic> json) {
    return LastScheduledRun(
      time: json['time']?.toString() ?? '',
      duration: _asInt(json['duration']) ?? 0,
      completed: json['completed'] == true,
    );
  }

  bool get hasRun => time.isNotEmpty;
}
