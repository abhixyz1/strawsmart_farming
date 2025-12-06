import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/notification_item.dart';
import 'notification_repository.dart';
import 'notification_rtdb_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service untuk menangani notifikasi lokal per greenhouse/device
/// Support multi-device dan anomaly detection
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  NotificationRepository? _repository;
  NotificationRtdbRepository? _rtdbRepository;
  
  bool _isInitialized = false;
  bool _hasPermission = false;

  /// Set notification repository untuk save history
  void setRepository(NotificationRepository repository) {
    _repository = repository;
  }

  /// Set RTDB notification repository untuk sync notifications
  void setRtdbRepository(NotificationRtdbRepository rtdbRepository) {
    _rtdbRepository = rtdbRepository;
  }

  /// Inisialisasi notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS/macOS settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    
    _isInitialized = true;
    
    // Request permissions
    await requestPermission();
  }

  /// Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    if (!_isInitialized) {
      await initialize();
    }

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      _hasPermission = await androidPlugin.requestNotificationsPermission() ?? false;
    } else {
      _hasPermission = true;
    }
    
    return _hasPermission;
  }

  /// Check if notification permission is granted
  bool get hasPermission => _hasPermission;

  /// Generic method to show notification and save to history
  Future<void> _showAndSaveNotification({
    required String deviceId,
    required String deviceName,
    required NotificationType type,
    required String title,
    required String body,
    required int notificationId,
    Color? color,
    Map<String, dynamic>? data,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    if (!_isInitialized) await initialize();
    if (!_hasPermission) return;

    // Check if device notifications are enabled
    if (_repository != null) {
      final isEnabled = await _repository!.isDeviceNotificationEnabled(deviceId);
      if (!isEnabled) return; // Skip if device notifications disabled
    }

    // Show local notification
    final androidColor = color ?? const Color(0xFF4ADE80);
    
    final androidDetails = AndroidNotificationDetails(
      'greenhouse_channel',
      'Greenhouse Notifications',
      channelDescription: 'Notifikasi untuk monitoring greenhouse',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: androidColor,
      enableVibration: enableVibration,
      playSound: playSound,
    );
    
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      notificationId,
      title,
      body,
      details,
      payload: '$deviceId|${type.name}',
    );

    // Save to RTDB for multi-user sync
    if (_rtdbRepository != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _rtdbRepository!.saveNotification(
          userId: user.uid,
          deviceId: deviceId,
          deviceName: deviceName,
          title: title,
          message: body,
          type: type,
        );
      }
    }
  }

  /// Show notification saat pompa mulai menyiram
  Future<void> showWateringStartNotification({
    required String deviceId,
    required String locationName,
    String? batchName,
    int? durationSeconds,
  }) async {
    final bodyText = batchName != null
        ? 'Penyiraman untuk $batchName di $locationName sedang berlangsung${durationSeconds != null ? ' (${durationSeconds}s)' : ''}.'
        : 'Sistem penyiraman di $locationName sedang aktif${durationSeconds != null ? ' selama ${durationSeconds} detik' : ''}';

    await _showAndSaveNotification(
      deviceId: deviceId,
      deviceName: locationName,
      type: NotificationType.wateringStart,
      title: '💧 Sedang Menyiram',
      body: bodyText,
      notificationId: deviceId.hashCode,
      color: const Color(0xFF2DD4BF),
      data: {
        'batchName': batchName,
        'duration': durationSeconds,
      },
    );
  }

  /// Show notification saat pompa selesai menyiram
  Future<void> showWateringCompleteNotification({
    required String deviceId,
    required String locationName,
    String? batchName,
  }) async {
    final bodyText = batchName != null
        ? 'Penyiraman untuk $batchName di $locationName telah selesai.'
        : 'Sistem penyiraman di $locationName telah selesai.';

    await _showAndSaveNotification(
      deviceId: deviceId,
      deviceName: locationName,
      type: NotificationType.wateringComplete,
      title: '✅ Penyiraman Selesai',
      body: bodyText,
      notificationId: deviceId.hashCode + 1,
      color: const Color(0xFF4ADE80),
      playSound: false,
      enableVibration: false,
      data: {'batchName': batchName},
    );
  }

  /// Show notification untuk anomali suhu
  Future<void> showTemperatureAnomalyNotification({
    required String deviceId,
    required String locationName,
    required double currentTemp,
    required double expectedMin,
    required double expectedMax,
  }) async {
    final status = currentTemp < expectedMin ? 'terlalu rendah' : 'terlalu tinggi';
    final body = '⚠️ Suhu di $locationName $status: ${currentTemp.toStringAsFixed(1)}°C (Normal: ${expectedMin.toStringAsFixed(1)}-${expectedMax.toStringAsFixed(1)}°C)';

    await _showAndSaveNotification(
      deviceId: deviceId,
      deviceName: locationName,
      type: NotificationType.anomalyTemperature,
      title: '🌡️ Peringatan Suhu Terdeteksi',
      body: body,
      notificationId: deviceId.hashCode + 10,
      color: const Color(0xFFF59E0B),
      data: {
        'currentTemp': currentTemp,
        'expectedMin': expectedMin,
        'expectedMax': expectedMax,
      },
    );
  }

  /// Show notification untuk anomali kelembaban udara
  Future<void> showHumidityAnomalyNotification({
    required String deviceId,
    required String locationName,
    required double currentHumidity,
    required double expectedMin,
    required double expectedMax,
  }) async {
    final status = currentHumidity < expectedMin ? 'terlalu rendah' : 'terlalu tinggi';
    final body = '⚠️ Kelembaban udara di $locationName $status: ${currentHumidity.toStringAsFixed(1)}% (Normal: ${expectedMin.toStringAsFixed(1)}-${expectedMax.toStringAsFixed(1)}%)';

    await _showAndSaveNotification(
      deviceId: deviceId,
      deviceName: locationName,
      type: NotificationType.anomalyHumidity,
      title: '💧 Peringatan Kelembaban Udara',
      body: body,
      notificationId: deviceId.hashCode + 11,
      color: const Color(0xFFF59E0B),
      data: {
        'currentHumidity': currentHumidity,
        'expectedMin': expectedMin,
        'expectedMax': expectedMax,
      },
    );
  }

  /// Show notification untuk anomali kelembaban tanah
  Future<void> showMoistureAnomalyNotification({
    required String deviceId,
    required String locationName,
    required double currentMoisture,
    required double expectedMin,
    required double expectedMax,
  }) async {
    final status = currentMoisture < expectedMin ? 'terlalu kering' : 'terlalu basah';
    final body = '⚠️ Kelembaban tanah di $locationName $status: ${currentMoisture.toStringAsFixed(1)}% (Normal: ${expectedMin.toStringAsFixed(1)}-${expectedMax.toStringAsFixed(1)}%)';

    await _showAndSaveNotification(
      deviceId: deviceId,
      deviceName: locationName,
      type: NotificationType.anomalyMoisture,
      title: '🌱 Peringatan Kelembaban Tanah',
      body: body,
      notificationId: deviceId.hashCode + 12,
      color: const Color(0xFFF59E0B),
      data: {
        'currentMoisture': currentMoisture,
        'expectedMin': expectedMin,
        'expectedMax': expectedMax,
      },
    );
  }

  /// Show notification untuk anomali pH tanah
  Future<void> showPhAnomalyNotification({
    required String deviceId,
    required String locationName,
    required double currentPh,
    required double expectedMin,
    required double expectedMax,
  }) async {
    final status = currentPh < expectedMin ? 'terlalu asam' : 'terlalu basa';
    final body = '⚠️ pH tanah di $locationName $status: ${currentPh.toStringAsFixed(1)} (Normal: ${expectedMin.toStringAsFixed(1)}-${expectedMax.toStringAsFixed(1)})';

    await _showAndSaveNotification(
      deviceId: deviceId,
      deviceName: locationName,
      type: NotificationType.anomalyPh,
      title: '🧪 Peringatan pH Tanah',
      body: body,
      notificationId: deviceId.hashCode + 13,
      color: const Color(0xFFF59E0B),
      data: {
        'currentPh': currentPh,
        'expectedMin': expectedMin,
        'expectedMax': expectedMax,
      },
    );
  }

  /// Show notification untuk device offline
  Future<void> showDeviceOfflineNotification({
    required String deviceId,
    required String locationName,
  }) async {
    await _showAndSaveNotification(
      deviceId: deviceId,
      deviceName: locationName,
      type: NotificationType.deviceOffline,
      title: '❌ Device Offline',
      body: '$locationName tidak merespons. Periksa koneksi device.',
      notificationId: deviceId.hashCode + 20,
      color: const Color(0xFFEF4444),
    );
  }

  /// Show notification untuk device online
  Future<void> showDeviceOnlineNotification({
    required String deviceId,
    required String locationName,
  }) async {
    await _showAndSaveNotification(
      deviceId: deviceId,
      deviceName: locationName,
      type: NotificationType.deviceOnline,
      title: '✅ Device Online',
      body: '$locationName kembali online.',
      notificationId: deviceId.hashCode + 21,
      color: const Color(0xFF4ADE80),
      playSound: false,
    );
  }

  /// Show notification reminder sebelum jadwal penyiraman (10 menit sebelum)
  Future<void> showScheduleReminderNotification({
    required String deviceId,
    required String locationName,
    required String scheduleTime,
    required int durationSeconds,
    String? batchName,
  }) async {
    final bodyText = batchName != null
        ? '⏰ Penyiraman untuk $batchName di $locationName akan dimulai pada $scheduleTime (durasi: ${durationSeconds}s)'
        : '⏰ Jadwal penyiraman di $locationName akan dimulai pada $scheduleTime (durasi: ${durationSeconds}s)';

    await _showAndSaveNotification(
      deviceId: deviceId,
      deviceName: locationName,
      type: NotificationType.scheduleExecuted,
      title: '⏰ Pengingat Penyiraman',
      body: bodyText,
      notificationId: deviceId.hashCode + 2,
      color: const Color(0xFF3B82F6),
      data: {
        'batchName': batchName,
        'scheduleTime': scheduleTime,
        'duration': durationSeconds,
      },
    );
  }

  /// Show notification saat fase batch berubah
  Future<void> showPhaseChangeNotification({
    required String deviceId,
    required String locationName,
    required String batchName,
    required String fromPhase,
    required String toPhase,
    required int dayInPhase,
  }) async {
    final body = '🌱 Batch $batchName di $locationName telah memasuki fase $toPhase (Hari ke-$dayInPhase). Fase sebelumnya: $fromPhase.';

    await _showAndSaveNotification(
      deviceId: deviceId,
      deviceName: locationName,
      type: NotificationType.batchPhaseChange,
      title: '🌱 Perubahan Fase Tanaman',
      body: body,
      notificationId: deviceId.hashCode + 3,
      color: const Color(0xFFF472B6),
      data: {
        'batchName': batchName,
        'fromPhase': fromPhase,
        'toPhase': toPhase,
        'dayInPhase': dayInPhase,
      },
    );
  }

  /// Cancel semua notifikasi
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancel notifikasi spesifik
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}

/// Provider untuk notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  final repository = ref.watch(notificationRepositoryProvider);
  final rtdbRepository = ref.watch(notificationRtdbRepositoryProvider);
  service.setRepository(repository);
  service.setRtdbRepository(rtdbRepository);
  return service;
});

/// Provider untuk tracking permission status
final notificationPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.requestPermission();
});
