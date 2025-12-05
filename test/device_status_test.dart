// Unit tests for DeviceStatusData online/offline indicator
//
// Memastikan:
// 1. isDeviceOnline mengembalikan true jika online flag true
// 2. isDeviceOnline mengembalikan true jika lastSeenMillis dalam 45 detik
// 3. isDeviceOnline mengembalikan false jika lastSeenMillis lebih dari 45 detik
// 4. connectionStatusLabel menampilkan status yang benar

import 'package:flutter_test/flutter_test.dart';
import 'package:strawsmart_farming/screens/dashboard/dashboard_repository.dart';

void main() {
  group('DeviceStatusData isDeviceOnline Tests', () {
    test('returns true when online flag is true', () {
      final status = DeviceStatusData(
        online: true,
        lastSeenMillis: null,
        autoLogicEnabled: false,
      );

      expect(status.isDeviceOnline, true);
    });

    test('returns true when lastSeenMillis is within 45 seconds', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 30 seconds ago - should be online (within 45 second threshold)
      final lastSeen = now - (30 * 1000);

      final status = DeviceStatusData(
        online: false,
        lastSeenMillis: lastSeen,
        autoLogicEnabled: false,
      );

      expect(status.isDeviceOnline, true);
    });

    test('returns true when lastSeenMillis is exactly 45 seconds ago', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Exactly 45 seconds ago - should be online (at threshold)
      final lastSeen = now - (45 * 1000);

      final status = DeviceStatusData(
        online: false,
        lastSeenMillis: lastSeen,
        autoLogicEnabled: false,
      );

      expect(status.isDeviceOnline, true);
    });

    test('returns false when lastSeenMillis is more than 45 seconds ago', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 50 seconds ago - should be offline (beyond 45 second threshold)
      final lastSeen = now - (50 * 1000);

      final status = DeviceStatusData(
        online: false,
        lastSeenMillis: lastSeen,
        autoLogicEnabled: false,
      );

      expect(status.isDeviceOnline, false);
    });

    test('returns false when lastSeenMillis is null and online is false', () {
      final status = DeviceStatusData(
        online: false,
        lastSeenMillis: null,
        autoLogicEnabled: false,
      );

      expect(status.isDeviceOnline, false);
    });

    test('threshold of 45 seconds is appropriate for 30 second data interval', () {
      // Data is sent every 30 seconds
      // A threshold of 45 seconds (1.5x) allows for:
      // - 15 seconds buffer for network latency
      // - Quick detection if device actually goes offline
      const dataIntervalSeconds = 30;
      const onlineThresholdSeconds = 45;

      expect(
        onlineThresholdSeconds,
        greaterThan(dataIntervalSeconds),
        reason: 'Threshold should be greater than data interval',
      );
      expect(
        onlineThresholdSeconds,
        lessThan(dataIntervalSeconds * 2),
        reason: 'Threshold should be less than 2x data interval for responsiveness',
      );
    });
  });

  group('DeviceStatusData connectionStatusLabel Tests', () {
    test('returns "Perangkat offline" when device is offline', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 60 seconds ago - definitely offline
      final lastSeen = now - (60 * 1000);

      final status = DeviceStatusData(
        online: false,
        lastSeenMillis: lastSeen,
        autoLogicEnabled: false,
      );

      expect(status.connectionStatusLabel, 'Perangkat offline');
    });

    test('returns "Terhubung (live)" when lastSeen is less than 5 seconds', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 2 seconds ago - live
      final lastSeen = now - (2 * 1000);

      final status = DeviceStatusData(
        online: false,
        lastSeenMillis: lastSeen,
        autoLogicEnabled: false,
      );

      expect(status.connectionStatusLabel, 'Terhubung (live)');
    });

    test('returns "Terhubung X detik lalu" when lastSeen is between 5 and 45 seconds', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      // 20 seconds ago
      final lastSeen = now - (20 * 1000);

      final status = DeviceStatusData(
        online: false,
        lastSeenMillis: lastSeen,
        autoLogicEnabled: false,
      );

      expect(status.connectionStatusLabel, contains('Terhubung'));
      expect(status.connectionStatusLabel, contains('detik lalu'));
    });

    test('returns "Terhubung" when lastSeenMillis is null but online is true', () {
      final status = DeviceStatusData(
        online: true,
        lastSeenMillis: null,
        autoLogicEnabled: false,
      );

      expect(status.connectionStatusLabel, 'Terhubung');
    });
  });

  group('DeviceStatusData.fromJson Tests', () {
    test('parses isOnline field correctly', () {
      final json = {
        'isOnline': true,
        'lastSeenAt': 1234567890000,
        'autoModeEnabled': true,
      };

      final status = DeviceStatusData.fromJson(json);

      expect(status.online, true);
      expect(status.autoLogicEnabled, true);
    });

    test('parses legacy online field correctly', () {
      final json = {
        'online': true,
        'lastSeen': 1234567890000,
        'autoLogicEnabled': true,
      };

      final status = DeviceStatusData.fromJson(json);

      expect(status.online, true);
      expect(status.autoLogicEnabled, true);
    });

    test('handles missing fields gracefully', () {
      final json = <String, dynamic>{};

      final status = DeviceStatusData.fromJson(json);

      expect(status.online, false);
      expect(status.lastSeenMillis, null);
      expect(status.autoLogicEnabled, false);
    });
  });
}
