import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/notification_item.dart';
import '../../screens/greenhouse/greenhouse_repository.dart';

/// Repository untuk manage notification history
class NotificationRepository {
  static const String _notificationsKey = 'notifications_history';
  static const String _devicePrefsPrefix = 'notification_device_';
  static const int _maxNotificationsPerDevice = 100; // Limit history per device
  
  final SharedPreferences _prefs;
  final _uuid = const Uuid();

  NotificationRepository(this._prefs);

  /// Save notification to history
  Future<void> saveNotification(NotificationItem notification) async {
    final notifications = await getNotifications();
    
    // Add new notification at the beginning
    notifications.insert(0, notification);
    
    // Keep only recent notifications per device (prevent unlimited growth)
    final deviceNotifications = notifications
        .where((n) => n.deviceId == notification.deviceId)
        .take(_maxNotificationsPerDevice)
        .toList();
    
    // Combine with other devices' notifications
    final otherDevices = notifications
        .where((n) => n.deviceId != notification.deviceId)
        .toList();
    
    final limitedNotifications = [...deviceNotifications, ...otherDevices];
    
    // Save to storage
    final jsonList = limitedNotifications.map((n) => n.toJson()).toList();
    await _prefs.setString(_notificationsKey, jsonEncode(jsonList));
  }

  /// Get all notifications
  Future<List<NotificationItem>> getNotifications() async {
    final jsonString = _prefs.getString(_notificationsKey);
    if (jsonString == null) return [];
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get notifications for specific device
  Future<List<NotificationItem>> getNotificationsByDevice(String deviceId) async {
    final notifications = await getNotifications();
    return notifications
        .where((n) => n.deviceId == deviceId)
        .toList();
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    final notifications = await getNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  /// Get unread count for specific device
  Future<int> getUnreadCountByDevice(String deviceId) async {
    final notifications = await getNotificationsByDevice(deviceId);
    return notifications.where((n) => !n.isRead).length;
  }

  /// Get unread count for multiple devices (user's greenhouses)
  Future<int> getUnreadCountByDevices(Set<String> deviceIds) async {
    final notifications = await getNotifications();
    return notifications
        .where((n) => !n.isRead && deviceIds.contains(n.deviceId))
        .length;
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final notifications = await getNotifications();
    final index = notifications.indexWhere((n) => n.id == notificationId);
    
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      final jsonList = notifications.map((n) => n.toJson()).toList();
      await _prefs.setString(_notificationsKey, jsonEncode(jsonList));
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final notifications = await getNotifications();
    final updatedNotifications = notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    
    final jsonList = updatedNotifications.map((n) => n.toJson()).toList();
    await _prefs.setString(_notificationsKey, jsonEncode(jsonList));
  }

  /// Mark all notifications for device as read
  Future<void> markDeviceNotificationsAsRead(String deviceId) async {
    final notifications = await getNotifications();
    final updatedNotifications = notifications.map((n) {
      if (n.deviceId == deviceId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    
    final jsonList = updatedNotifications.map((n) => n.toJson()).toList();
    await _prefs.setString(_notificationsKey, jsonEncode(jsonList));
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    final notifications = await getNotifications();
    notifications.removeWhere((n) => n.id == notificationId);
    
    final jsonList = notifications.map((n) => n.toJson()).toList();
    await _prefs.setString(_notificationsKey, jsonEncode(jsonList));
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    await _prefs.remove(_notificationsKey);
  }

  /// Clear notifications for specific device
  Future<void> clearDevice(String deviceId) async {
    final notifications = await getNotifications();
    notifications.removeWhere((n) => n.deviceId == deviceId);
    
    final jsonList = notifications.map((n) => n.toJson()).toList();
    await _prefs.setString(_notificationsKey, jsonEncode(jsonList));
  }

  /// Get or set notification enabled for device
  Future<bool> isDeviceNotificationEnabled(String deviceId) async {
    return _prefs.getBool('$_devicePrefsPrefix$deviceId') ?? true;
  }

  Future<void> setDeviceNotificationEnabled(String deviceId, bool enabled) async {
    await _prefs.setBool('$_devicePrefsPrefix$deviceId', enabled);
  }

  /// Generate unique ID for notification
  String generateId() => _uuid.v4();
}

/// Provider untuk notification repository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  throw UnimplementedError('notificationRepositoryProvider must be overridden');
});

/// Provider untuk notification list (auto-refresh)
final notificationsProvider = StreamProvider<List<NotificationItem>>((ref) async* {
  final repo = ref.watch(notificationRepositoryProvider);
  
  // Initial load
  yield await repo.getNotifications();
  
  // Poll every 2 seconds for updates (simple approach)
  await for (var _ in Stream.periodic(const Duration(seconds: 2))) {
    yield await repo.getNotifications();
  }
});

/// Provider untuk unread count (filtered by user's greenhouses)
final unreadNotificationCountProvider = StreamProvider<int>((ref) async* {
  final repo = ref.watch(notificationRepositoryProvider);
  final greenhousesAsync = ref.watch(availableGreenhousesProvider);
  
  // Wait for greenhouses data
  await for (final greenhouses in Stream.value(greenhousesAsync)) {
    if (greenhouses.hasValue) {
      final userDeviceIds = greenhouses.value!
          .map((g) => g.deviceId)
          .whereType<String>()
          .toSet();
      yield await repo.getUnreadCountByDevices(userDeviceIds);
      
      await for (var _ in Stream.periodic(const Duration(seconds: 2))) {
        yield await repo.getUnreadCountByDevices(userDeviceIds);
      }
    } else {
      yield 0;
    }
    break;
  }
});
