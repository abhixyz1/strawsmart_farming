import 'package:flutter_test/flutter_test.dart';
import 'package:strawsmart_farming/core/services/strawberry_guidance.dart';
import 'package:strawsmart_farming/models/guidance_item.dart';
import 'package:strawsmart_farming/screens/dashboard/dashboard_repository.dart';

void main() {
  group('StrawberryGuidanceService', () {
    late StrawberryGuidanceService service;

    setUp(() {
      service = StrawberryGuidanceService.instance;
    });

    test('returns empty list when snapshot is null', () {
      final recommendations = service.getRecommendations(null);
      expect(recommendations, isEmpty);
    });

    test('returns optimal recommendations for ideal conditions', () {
      final snapshot = SensorSnapshot(
        temperature: 26.0, // Optimal 24-28
        humidity: 62.0, // Optimal 55-70
        soilMoisturePercent: 40.0, // Optimal 35-45
        lightIntensity: 1400, // Optimal 1200-1600 ADC
      );

      final recommendations = service.getRecommendations(snapshot);

      expect(recommendations, isNotEmpty);

      // All should be info priority (3)
      final criticalCount = recommendations.where((r) => r.isCritical).length;
      final warningCount = recommendations.where((r) => r.isWarning).length;
      final infoCount = recommendations.where((r) => r.isInfo).length;

      expect(criticalCount, 0);
      expect(warningCount, 0);
      expect(infoCount, greaterThan(0));
    });

    test('detects critical high temperature', () {
      final snapshot = SensorSnapshot(
        temperature: 34.0, // Critical high (>32)
        humidity: 60.0,
        soilMoisturePercent: 40.0,
        lightIntensity: 1400,
      );

      final recommendations = service.getRecommendations(snapshot);

      final tempCritical = recommendations.firstWhere(
        (r) => r.type == GuidanceType.temperature && r.isCritical,
        orElse: () => throw Exception('No critical temp recommendation found'),
      );

      expect(tempCritical.title, contains('Terlalu Tinggi'));
      expect(tempCritical.priority, 1);
    });

    test('detects critical low temperature', () {
      final snapshot = SensorSnapshot(
        temperature: 16.0, // Critical low (<18)
        humidity: 60.0,
        soilMoisturePercent: 40.0,
        lightIntensity: 1400,
      );

      final recommendations = service.getRecommendations(snapshot);

      final tempCritical = recommendations.firstWhere(
        (r) => r.type == GuidanceType.temperature && r.isCritical,
      );

      expect(tempCritical.title, contains('Terlalu Rendah'));
      expect(tempCritical.priority, 1);
    });

    test('detects warning for slightly high humidity', () {
      final snapshot = SensorSnapshot(
        temperature: 26.0,
        humidity: 75.0, // Warning (>70 but <85)
        soilMoisturePercent: 40.0,
        lightIntensity: 1400,
      );

      final recommendations = service.getRecommendations(snapshot);

      final humidityWarning = recommendations.firstWhere(
        (r) => r.type == GuidanceType.humidity && r.isWarning,
      );

      expect(humidityWarning.priority, 2);
    });

    test('detects critical dry soil', () {
      final snapshot = SensorSnapshot(
        temperature: 26.0,
        humidity: 60.0,
        soilMoisturePercent: 20.0, // Critical (<25)
        lightIntensity: 1400,
      );

      final recommendations = service.getRecommendations(snapshot);

      final soilCritical = recommendations.firstWhere(
        (r) => r.type == GuidanceType.soilMoisture && r.isCritical,
      );

      expect(soilCritical.title, contains('Sangat Kering'));
      expect(soilCritical.description, contains('Segera aktifkan penyiraman'));
    });

    test('detects critical wet soil', () {
      final snapshot = SensorSnapshot(
        temperature: 26.0,
        humidity: 60.0,
        soilMoisturePercent: 65.0, // Critical (>60)
        lightIntensity: 1400,
      );

      final recommendations = service.getRecommendations(snapshot);

      final soilCritical = recommendations.firstWhere(
        (r) => r.type == GuidanceType.soilMoisture && r.isCritical,
      );

      expect(soilCritical.title, contains('Terlalu Basah'));
      expect(soilCritical.description, contains('akar busuk'));
    });

    test('detects low light condition', () {
      final snapshot = SensorSnapshot(
        temperature: 26.0,
        humidity: 60.0,
        soilMoisturePercent: 40.0,
        lightIntensity: 600, // Critical (<800)
      );

      final recommendations = service.getRecommendations(snapshot);

      final lightCritical = recommendations.firstWhere(
        (r) => r.type == GuidanceType.light && r.isCritical,
      );

      expect(lightCritical.title, contains('Tidak Cukup'));
      expect(lightCritical.description, contains('grow light'));
    });

    test('detects heat stress combo (high temp + low humidity)', () {
      final snapshot = SensorSnapshot(
        temperature: 30.0, // High (>28)
        humidity: 50.0, // Low (<55)
        soilMoisturePercent: 40.0,
        lightIntensity: 1400,
      );

      final recommendations = service.getRecommendations(snapshot);

      final heatStress = recommendations.firstWhere(
        (r) => r.title.contains('Heat Stress'),
        orElse: () => throw Exception('No heat stress recommendation'),
      );

      expect(heatStress.priority, 1);
      expect(heatStress.type, GuidanceType.ventilation);
      expect(heatStress.description, contains('misting'));
    });

    test('detects fungal risk combo (high temp + high humidity)', () {
      final snapshot = SensorSnapshot(
        temperature: 30.0, // High (>28)
        humidity: 75.0, // High (>70)
        soilMoisturePercent: 40.0,
        lightIntensity: 1400,
      );

      final recommendations = service.getRecommendations(snapshot);

      final fungalRisk = recommendations.firstWhere(
        (r) => r.title.contains('Jamur'),
      );

      expect(fungalRisk.priority, 1);
      expect(fungalRisk.type, GuidanceType.ventilation);
      expect(fungalRisk.description, contains('sirkulasi udara'));
    });

    test('detects dehydration risk combo (dry soil + low humidity)', () {
      final snapshot = SensorSnapshot(
        temperature: 26.0,
        humidity: 50.0, // Low (<55)
        soilMoisturePercent: 30.0, // Low (<35)
        lightIntensity: 1400,
      );

      final recommendations = service.getRecommendations(snapshot);

      final dehydrationRisk = recommendations.firstWhere(
        (r) => r.title.contains('Dehidrasi'),
      );

      expect(dehydrationRisk.priority, 1);
      expect(dehydrationRisk.type, GuidanceType.watering);
      expect(dehydrationRisk.description, contains('Segera siram'));
    });

    test('sorts recommendations by priority (critical first)', () {
      final snapshot = SensorSnapshot(
        temperature: 34.0, // Critical
        humidity: 75.0, // Warning
        soilMoisturePercent: 40.0, // Optimal
        lightIntensity: 1400, // Optimal
      );

      final recommendations = service.getRecommendations(snapshot);

      expect(recommendations.isNotEmpty, true);

      // First recommendation should be critical (priority 1)
      expect(recommendations.first.priority, 1);

      // Verify sorted order
      for (int i = 0; i < recommendations.length - 1; i++) {
        expect(
          recommendations[i].priority <= recommendations[i + 1].priority,
          true,
          reason: 'Recommendations should be sorted by priority',
        );
      }
    });

    test('includes sensor values in recommendations', () {
      final snapshot = SensorSnapshot(
        temperature: 32.0,
        humidity: 60.0,
        soilMoisturePercent: 40.0,
        lightIntensity: 1400,
      );

      final recommendations = service.getRecommendations(snapshot);

      final tempRec = recommendations.firstWhere(
        (r) => r.type == GuidanceType.temperature,
      );

      expect(tempRec.sensorValue, isNotNull);
      expect(tempRec.sensorValue, contains('32'));
    });

    test('handles partial sensor data gracefully', () {
      // Only temperature available
      final snapshot = SensorSnapshot(
        temperature: 26.0,
        humidity: null,
        soilMoisturePercent: null,
        lightIntensity: null,
      );

      final recommendations = service.getRecommendations(snapshot);

      // Should only have temperature recommendation
      expect(recommendations, isNotEmpty);
      expect(recommendations.length, 1);
      expect(recommendations.first.type, GuidanceType.temperature);
    });
  });
}
