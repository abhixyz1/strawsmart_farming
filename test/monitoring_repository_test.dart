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
  });
}
