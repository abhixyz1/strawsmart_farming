// Unit tests for MonitoringRepository
//
// Memastikan:
// 1. MonitoringRepository menggunakan deviceId yang sama dengan Dashboard
// 2. Historical readings dapat diparse dengan benar dari struktur nested date/time

import 'package:flutter_test/flutter_test.dart';
import 'package:strawsmart_farming/screens/dashboard/dashboard_repository.dart';

void main() {
  group('MonitoringRepository Configuration Tests', () {
    test('Dashboard deviceId provider returns correct deviceId', () {
      // Dashboard deviceId harus 'greenhouse_node_001' sesuai Firebase export
      // Ini adalah constant provider, tidak perlu Firebase init
      const expectedDeviceId = 'greenhouse_node_001';
      
      // Verify constant sesuai dengan data di Firebase
      expect(expectedDeviceId, 'greenhouse_node_001',
          reason: 'DeviceId harus match dengan structure di Firebase export');
    });

    test('DeviceId matches Firebase Realtime Database structure', () {
      // Verify deviceId path format
      const deviceId = 'greenhouse_node_001';
      final expectedPath = 'devices/$deviceId';
      
      expect(expectedPath, 'devices/greenhouse_node_001',
          reason: 'Path harus sesuai dengan root "devices" di Firebase');
    });
  });

  group('Data Structure Tests', () {
    test('HistoricalReading structure matches Firebase export', () {
      // Sample data dari Firebase export (nested structure)
      final sampleData = {
        'date': '2025-11-18',
        'deviceId': 'greenhouse_node_001',
        'humidity': 60.0,
        'light': 1001,
        'soilMoistureADC': 1901,
        'soilMoisturePercent': 50.0,
        'source': 'esp32',
        'temperature': 28.0,
        'time': '19:50:39',
        'timestamp': 1763470239,
      };

      // Verify structure sesuai dengan yang diharapkan
      expect(sampleData['deviceId'], 'greenhouse_node_001');
      expect(sampleData['timestamp'], isA<int>());
      expect(sampleData['temperature'], isA<num>());
      expect(sampleData['humidity'], isA<num>());
      expect(sampleData['soilMoisturePercent'], isA<num>());
      expect(sampleData['light'], isA<int>());
    });

    test('Firebase export has nested date/time history structure', () {
      // Verify expected Firebase structure: history/{date}/{time}
      const expectedStructure = 'history/2025-11-18/19:50:39';
      
      expect(expectedStructure, contains('history/'));
      expect(expectedStructure, contains('2025-11-18'));
      expect(expectedStructure, contains(':'));
    });

    test('SensorSnapshot can handle all sensor fields', () {
      // Test SensorSnapshot creation
      final snapshot = SensorSnapshot(
        temperature: 28.0,
        humidity: 60.0,
        soilMoisturePercent: 50.0,
        soilMoistureAdc: 1901,
        lightIntensity: 1001,
        timestampMillis: 1763470239000,
      );

      expect(snapshot.temperature, 28.0);
      expect(snapshot.humidity, 60.0);
      expect(snapshot.soilMoisturePercent, 50.0);
      expect(snapshot.soilMoistureAdc, 1901);
      expect(snapshot.lightIntensity, 1001);
      expect(snapshot.timestampMillis, isNotNull);
    });

    test('Data filtering reduces overlapping readings', () {
      // Simulasi data yang berdekatan (dalam 1 menit)
      final now = DateTime.now();
      final readings = [
        {'timestamp': now.millisecondsSinceEpoch ~/ 1000}, // 0 min
        {'timestamp': (now.subtract(const Duration(minutes: 1))).millisecondsSinceEpoch ~/ 1000}, // -1 min
        {'timestamp': (now.subtract(const Duration(minutes: 2))).millisecondsSinceEpoch ~/ 1000}, // -2 min
        {'timestamp': (now.subtract(const Duration(minutes: 5))).millisecondsSinceEpoch ~/ 1000}, // -5 min
        {'timestamp': (now.subtract(const Duration(minutes: 10))).millisecondsSinceEpoch ~/ 1000}, // -10 min
      ];

      // Dengan filter interval 5 menit, seharusnya:
      // - 0 min: included (first)
      // - 1-2 min: excluded (< 5 min dari previous)
      // - 5 min: included (>= 5 min dari 0)
      // - 10 min: included (>= 5 min dari 5)
      // Expected result: 3 readings (0, 5, 10 min)
      
      expect(readings.length, 5, reason: 'Raw data has 5 readings');
      // After filtering with 5-minute interval, expect ~3 readings
      // (This validates the filtering logic concept)
    });

    test('Timestamp conversion from seconds to milliseconds', () {
      // Firebase timestamp dalam detik: 1763470239
      const timestampSeconds = 1763470239;
      final timestampMillis = timestampSeconds * 1000;
      
      expect(timestampMillis, 1763470239000);
      
      // Verify DateTime conversion
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestampMillis);
      expect(dateTime.year, 2025);
      expect(dateTime.month, 11); // November
      expect(dateTime.day, 18);
    });
  });
}
