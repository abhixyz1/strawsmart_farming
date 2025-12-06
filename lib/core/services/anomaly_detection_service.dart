import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cultivation_batch.dart';
import 'notification_service.dart';
import 'notification_rtdb_repository.dart';

/// Service untuk monitoring anomali sensor dan trigger notifikasi
class AnomalyDetectionService {
  final NotificationService _notificationService;
  final NotificationRtdbRepository _rtdbRepository;
  final DatabaseReference _database;
  
  // Track previous anomaly states to prevent spam notifications
  final Map<String, bool> _previousAnomalyStates = {};
  
  // Cooldown period diatur di RTDB (30 menit)

  AnomalyDetectionService(
    this._notificationService,
    this._rtdbRepository,
  ) : _database = FirebaseDatabase.instance.ref();

  /// Check sensor readings untuk anomali
  Future<void> checkSensorReadings({
    required String deviceId,
    required String deviceName,
    double? temperature,
    double? humidity,
    double? soilMoisture,
    double? soilPh,
    GrowthPhase? currentPhase,
    PhaseRequirements? phaseRequirements,
  }) async {
    // Fetch locationName dari RTDB
    final locationName = await _getLocationName(deviceId) ?? deviceName;
    
    // Get expected ranges dari batch phase atau gunakan default
    final ranges = phaseRequirements ?? _getDefaultRanges();

    // Check temperature anomaly
    if (temperature != null) {
      await _checkTemperatureAnomaly(
        deviceId: deviceId,
        locationName: locationName,
        current: temperature,
        expectedMin: ranges.minTemp,
        expectedMax: ranges.maxTemp,
      );
    }

    // Check humidity anomaly
    if (humidity != null) {
      await _checkHumidityAnomaly(
        deviceId: deviceId,
        locationName: locationName,
        current: humidity,
        expectedMin: ranges.minHumidity,
        expectedMax: ranges.maxHumidity,
      );
    }

    // Check soil moisture anomaly
    // Check soil moisture anomaly
    if (soilMoisture != null) {
      await _checkMoistureAnomaly(
        deviceId: deviceId,
        locationName: locationName,
        current: soilMoisture,
        expectedMin: ranges.minSoilMoisture,
        expectedMax: ranges.maxSoilMoisture,
      );
    }

    // Check pH anomaly (if pH sensor available)
    if (soilPh != null) {
      // Note: PhaseRequirements doesn't have pH fields yet
      // Use default range for now
      await _checkPhAnomaly(
        deviceId: deviceId,
        locationName: locationName,
        current: soilPh,
        expectedMin: 5.5,
        expectedMax: 6.5,
      );
    }
  }

  /// Fetch locationName dari Firebase RTDB
  Future<String?> _getLocationName(String deviceId) async {
    try {
      final snapshot = await _database
          .child('devices')
          .child(deviceId)
          .child('info')
          .child('locationName')
          .get();
      
      if (snapshot.exists) {
        return snapshot.value as String?;
      }
    } catch (e) {
      // Jika gagal fetch, return null dan fallback ke deviceName
      return null;
    }
    return null;
  }

  /// Check device online status
  Future<void> checkDeviceStatus({
    required String deviceId,
    required String deviceName,
    required bool isOnline,
  }) async {
    // Fetch locationName dari RTDB
    final locationName = await _getLocationName(deviceId) ?? deviceName;
    
    final stateKey = '${deviceId}_online';
    final previousState = _previousAnomalyStates[stateKey];

    // Notify only on state change
    if (previousState != null && previousState != isOnline) {
      if (!isOnline) {
        await _notificationService.showDeviceOfflineNotification(
          deviceId: deviceId,
          locationName: locationName,
        );
      } else {
        await _notificationService.showDeviceOnlineNotification(
          deviceId: deviceId,
          locationName: locationName,
        );
      }
    }

    _previousAnomalyStates[stateKey] = isOnline;
  }

  Future<void> _checkTemperatureAnomaly({
    required String deviceId,
    required String locationName,
    required double current,
    required double expectedMin,
    required double expectedMax,
  }) async {
    final stateKey = '${deviceId}_temp';
    final isAnomaly = current < expectedMin || current > expectedMax;

    if (isAnomaly && await _shouldSendNotification(stateKey)) {
      await _notificationService.showTemperatureAnomalyNotification(
        deviceId: deviceId,
        locationName: locationName,
        currentTemp: current,
        expectedMin: expectedMin,
        expectedMax: expectedMax,
      );
      await _recordNotificationSent(stateKey);
    }

    _previousAnomalyStates[stateKey] = isAnomaly;
  }

  Future<void> _checkHumidityAnomaly({
    required String deviceId,
    required String locationName,
    required double current,
    required double expectedMin,
    required double expectedMax,
  }) async {
    final stateKey = '${deviceId}_humidity';
    final isAnomaly = current < expectedMin || current > expectedMax;

    if (isAnomaly && await _shouldSendNotification(stateKey)) {
      await _notificationService.showHumidityAnomalyNotification(
        deviceId: deviceId,
        locationName: locationName,
        currentHumidity: current,
        expectedMin: expectedMin,
        expectedMax: expectedMax,
      );
      await _recordNotificationSent(stateKey);
    }

    _previousAnomalyStates[stateKey] = isAnomaly;
  }

  Future<void> _checkMoistureAnomaly({
    required String deviceId,
    required String locationName,
    required double current,
    required double expectedMin,
    required double expectedMax,
  }) async {
    final stateKey = '${deviceId}_moisture';
    final isAnomaly = current < expectedMin || current > expectedMax;

    if (isAnomaly && await _shouldSendNotification(stateKey)) {
      await _notificationService.showMoistureAnomalyNotification(
        deviceId: deviceId,
        locationName: locationName,
        currentMoisture: current,
        expectedMin: expectedMin,
        expectedMax: expectedMax,
      );
      await _recordNotificationSent(stateKey);
    }

    _previousAnomalyStates[stateKey] = isAnomaly;
  }

  Future<void> _checkPhAnomaly({
    required String deviceId,
    required String locationName,
    required double current,
    required double expectedMin,
    required double expectedMax,
  }) async {
    final stateKey = '${deviceId}_ph';
    final isAnomaly = current < expectedMin || current > expectedMax;

    if (isAnomaly && await _shouldSendNotification(stateKey)) {
      await _notificationService.showPhAnomalyNotification(
        deviceId: deviceId,
        locationName: locationName,
        currentPh: current,
        expectedMin: expectedMin,
        expectedMax: expectedMax,
      );
      await _recordNotificationSent(stateKey);
    }

    _previousAnomalyStates[stateKey] = isAnomaly;
  }

  /// Check if enough time has passed since last notification untuk mencegah spam
  /// Cooldown 30 menit memastikan notifikasi tidak terlalu sering
  /// Menggunakan RTDB untuk cooldown global across all users
  Future<bool> _shouldSendNotification(String key) async {
    return !await _rtdbRepository.isCooldownActive(key);
  }

  /// Record notification sent time dan simpan ke RTDB
  Future<void> _recordNotificationSent(String key) async {
    await _rtdbRepository.setCooldown(key);
  }

  /// Get default sensor ranges jika tidak ada active batch
  PhaseRequirements _getDefaultRanges() {
    return const PhaseRequirements(
      minTemp: 18.0,
      maxTemp: 25.0,
      minHumidity: 60.0,
      maxHumidity: 80.0,
      minSoilMoisture: 60.0,
      maxSoilMoisture: 80.0,
      wateringPerDay: 2,
      wateringDurationSec: 10,
      fertilizers: [],
    );
  }
}

/// Provider untuk anomaly detection service
final anomalyDetectionServiceProvider = Provider<AnomalyDetectionService>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final rtdbRepository = ref.watch(notificationRtdbRepositoryProvider);
  return AnomalyDetectionService(notificationService, rtdbRepository);
});
