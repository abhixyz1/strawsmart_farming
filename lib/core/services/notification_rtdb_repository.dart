import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/notification_item.dart';

/// Repository untuk manage notification history di Firebase RTDB
class NotificationRtdbRepository {
  final FirebaseDatabase _database;
  final _uuid = const Uuid();

  NotificationRtdbRepository(this._database);

  /// Reference ke notifications node
  DatabaseReference get _notificationsRef => _database.ref('notifications');

  /// Reference ke cooldowns node
  DatabaseReference get _cooldownsRef => _database.ref('notification_cooldowns');

  /// Save notification to RTDB
  Future<void> saveNotification({
    required String userId,
    required String deviceId,
    required String deviceName,
    required String title,
    required String message,
    required NotificationType type,
  }) async {
    final notificationId = _uuid.v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await _notificationsRef.child(userId).child(notificationId).set({
      'id': notificationId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'isRead': false,
      'type': type.toString().split('.').last,
    });
  }

  /// Get notifications for user
  Stream<List<NotificationItem>> getNotifications(String userId) {
    return _notificationsRef
        .child(userId)
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <NotificationItem>[];

      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return <NotificationItem>[];

      final notifications = <NotificationItem>[];
      data.forEach((key, value) {
        try {
          final notifData = Map<String, dynamic>.from(value as Map);
          notifications.add(NotificationItem.fromJson(notifData));
        } catch (e) {
          // Skip invalid entries
        }
      });

      // Sort by timestamp descending (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return notifications;
    });
  }

  /// Get unread count for user
  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _notificationsRef
        .child(userId)
        .orderByChild('isRead')
        .equalTo(false)
        .once();

    if (!snapshot.snapshot.exists) return 0;

    final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;
    return data?.length ?? 0;
  }

  /// Get unread count for specific devices
  Future<int> getUnreadCountByDevices(
    String userId,
    Set<String> deviceIds,
  ) async {
    final snapshot = await _notificationsRef.child(userId).once();

    if (!snapshot.snapshot.exists) return 0;

    final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return 0;

    int count = 0;
    data.forEach((key, value) {
      try {
        final notifData = Map<String, dynamic>.from(value as Map);
        final isRead = notifData['isRead'] as bool? ?? true;
        final deviceId = notifData['deviceId'] as String?;
        
        if (!isRead && deviceId != null && deviceIds.contains(deviceId)) {
          count++;
        }
      } catch (e) {
        // Skip invalid entries
      }
    });

    return count;
  }

  /// Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    await _notificationsRef
        .child(userId)
        .child(notificationId)
        .update({'isRead': true});
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _notificationsRef.child(userId).once();

    if (!snapshot.snapshot.exists) return;

    final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return;

    final updates = <String, dynamic>{};
    data.forEach((key, value) {
      updates['$key/isRead'] = true;
    });

    if (updates.isNotEmpty) {
      await _notificationsRef.child(userId).update(updates);
    }
  }

  /// Clear old notifications (keep last 100 per user)
  Future<void> clearOldNotifications(String userId) async {
    final snapshot = await _notificationsRef
        .child(userId)
        .orderByChild('timestamp')
        .once();

    if (!snapshot.snapshot.exists) return;

    final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return;

    // Convert to list and sort by timestamp
    final notifications = <MapEntry<String, int>>[];
    data.forEach((key, value) {
      try {
        final notifData = Map<String, dynamic>.from(value as Map);
        final timestamp = notifData['timestamp'] as int? ?? 0;
        notifications.add(MapEntry(key as String, timestamp));
      } catch (e) {
        // Skip invalid entries
      }
    });

    notifications.sort((a, b) => b.value.compareTo(a.value));

    // Keep only last 100
    if (notifications.length > 100) {
      final toDelete = notifications.skip(100);
      for (final entry in toDelete) {
        await _notificationsRef.child(userId).child(entry.key).remove();
      }
    }
  }

  /// Check if cooldown is active
  Future<bool> isCooldownActive(String cooldownKey) async {
    final snapshot = await _cooldownsRef.child(cooldownKey).once();
    
    if (!snapshot.snapshot.exists) return false;

    final timestamp = snapshot.snapshot.value as int?;
    if (timestamp == null) return false;

    final lastNotificationTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(lastNotificationTime);

    // 30 minutes cooldown
    return diff.inMinutes < 30;
  }

  /// Set cooldown timestamp
  Future<void> setCooldown(String cooldownKey) async {
    await _cooldownsRef.child(cooldownKey).set(
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Clear expired cooldowns (older than 1 day)
  Future<void> clearExpiredCooldowns() async {
    final snapshot = await _cooldownsRef.once();

    if (!snapshot.snapshot.exists) return;

    final data = snapshot.snapshot.value as Map<dynamic, dynamic>?;
    if (data == null) return;

    final now = DateTime.now();
    final expiredKeys = <String>[];

    data.forEach((key, value) {
      try {
        final timestamp = value as int;
        final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final diff = now.difference(time);

        if (diff.inDays >= 1) {
          expiredKeys.add(key as String);
        }
      } catch (e) {
        // Skip invalid entries
      }
    });

    for (final key in expiredKeys) {
      await _cooldownsRef.child(key).remove();
    }
  }
}

/// Provider untuk NotificationRtdbRepository
final notificationRtdbRepositoryProvider = Provider<NotificationRtdbRepository>((ref) {
  return NotificationRtdbRepository(FirebaseDatabase.instance);
});
