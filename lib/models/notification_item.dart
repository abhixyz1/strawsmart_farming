import 'package:flutter/material.dart';

/// Enum untuk tipe notifikasi
enum NotificationType {
  wateringStart,     // Pompa mulai menyiram
  wateringComplete,  // Pompa selesai menyiram
  anomalyTemperature, // Anomali suhu
  anomalyHumidity,    // Anomali kelembaban udara
  anomalyMoisture,    // Anomali kelembaban tanah
  anomalyPh,          // Anomali pH tanah
  deviceOffline,      // Device offline
  deviceOnline,       // Device kembali online
  scheduleExecuted,   // Jadwal dijalankan
  batchPhaseChange,   // Fase batch berubah
}

/// Model untuk item notifikasi
class NotificationItem {
  final String id;
  final String deviceId;
  final String deviceName;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? data; // Data tambahan (nilai sensor, dll)

  const NotificationItem({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.data,
  });

  /// Copy with untuk update fields
  NotificationItem copyWith({
    String? id,
    String? deviceId,
    String? deviceName,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  /// Convert to JSON untuk penyimpanan
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'type': type.name,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'data': data,
    };
  }

  /// Create from JSON
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.scheduleExecuted,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  /// Get icon untuk notification type
  IconData get icon {
    return switch (type) {
      NotificationType.wateringStart => Icons.water_drop,
      NotificationType.wateringComplete => Icons.check_circle_outline,
      NotificationType.anomalyTemperature => Icons.thermostat,
      NotificationType.anomalyHumidity => Icons.water_damage,
      NotificationType.anomalyMoisture => Icons.grass,
      NotificationType.anomalyPh => Icons.science,
      NotificationType.deviceOffline => Icons.cloud_off,
      NotificationType.deviceOnline => Icons.cloud_done,
      NotificationType.scheduleExecuted => Icons.schedule,
      NotificationType.batchPhaseChange => Icons.timeline,
    };
  }

  /// Get color untuk notification type
  Color get color {
    return switch (type) {
      NotificationType.wateringStart => const Color(0xFF2DD4BF),
      NotificationType.wateringComplete => const Color(0xFF4ADE80),
      NotificationType.anomalyTemperature => const Color(0xFFF59E0B),
      NotificationType.anomalyHumidity => const Color(0xFFF59E0B),
      NotificationType.anomalyMoisture => const Color(0xFFF59E0B),
      NotificationType.anomalyPh => const Color(0xFFF59E0B),
      NotificationType.deviceOffline => const Color(0xFFEF4444),
      NotificationType.deviceOnline => const Color(0xFF4ADE80),
      NotificationType.scheduleExecuted => const Color(0xFF3B82F6),
      NotificationType.batchPhaseChange => const Color(0xFFF472B6),
    };
  }

  /// Check if notification is critical (needs immediate attention)
  bool get isCritical {
    return type == NotificationType.deviceOffline ||
           type == NotificationType.anomalyTemperature ||
           type == NotificationType.anomalyHumidity ||
           type == NotificationType.anomalyMoisture ||
           type == NotificationType.anomalyPh;
  }
}
