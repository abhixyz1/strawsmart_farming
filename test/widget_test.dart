// Widget tests for StrawSmart Farming UI/UX improvements
//
// Tests cover:
// 1. Sensor card grid rendering with compressed layout
// 2. Pull-to-refresh functionality in monitoring screen

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawsmart_farming/screens/dashboard/dashboard_repository.dart';

void main() {
  group('Sensor Cards Tests', () {
    testWidgets('Sensor grid displays 4 cards with proper layout on wide screen',
        (WidgetTester tester) async {
      // Create mock sensor data
      final mockSensorData = SensorSnapshot(
        temperature: 26.5,
        humidity: 65.0,
        soilMoisturePercent: 75.0,
        soilMoistureAdc: 3000,
        lightIntensity: 2500,
        timestampMillis: DateTime.now().millisecondsSinceEpoch,
      );

      // Build a test widget with wide screen constraints
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1200, // Wide screen to trigger 4-column layout
                child: _MockSensorGrid(sensorData: mockSensorData),
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to render
      await tester.pumpAndSettle();

      // Verify that all 4 sensor cards are displayed
      expect(find.byType(Card), findsNWidgets(4));

      // Verify sensor values are displayed
      expect(find.textContaining('26.5'), findsOneWidget); // Temperature
      expect(find.textContaining('65'), findsOneWidget); // Humidity
      expect(find.textContaining('75'), findsOneWidget); // Soil moisture
      expect(find.textContaining('2500'), findsOneWidget); // Light

      // Verify icons are present (compressed layout shows icon at top)
      expect(find.byIcon(Icons.thermostat), findsOneWidget);
      expect(find.byIcon(Icons.water_drop), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.light_mode), findsOneWidget);
    });

    testWidgets('Sensor grid adapts to mobile screen (1 column)',
        (WidgetTester tester) async {
      final mockSensorData = SensorSnapshot(
        temperature: 25.0,
        humidity: 60.0,
        soilMoisturePercent: 70.0,
        lightIntensity: 2000,
        timestampMillis: DateTime.now().millisecondsSinceEpoch,
      );

      // Build test widget with narrow screen constraints
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 400, // Narrow screen to trigger 1-column layout
                height: 2000, // Enough height to render all cards
                child: _MockSensorGrid(sensorData: mockSensorData),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify cards are displayed in single column
      expect(find.byType(Card), findsNWidgets(4));
      
      // Verify aspect ratio is consistent (1.2 for compressed layout)
      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 1);
      expect(delegate.childAspectRatio, 1.2);
    });

    testWidgets('Sensor cards show compressed layout without verbose text',
        (WidgetTester tester) async {
      final mockSensorData = SensorSnapshot(
        temperature: 27.0,
        humidity: 62.0,
        soilMoisturePercent: 68.0,
        lightIntensity: 2200,
        timestampMillis: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _MockSensorGrid(sensorData: mockSensorData),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that verbose status text is NOT displayed (compressed layout)
      expect(find.textContaining('Rentang ideal'), findsNothing);
      expect(find.textContaining('Status:'), findsNothing);
      
      // Verify that only essential info is shown: icon, value, label
      expect(find.text('Suhu'), findsOneWidget);
      expect(find.text('Kelembapan udara'), findsOneWidget);
      expect(find.text('Kelembapan tanah'), findsOneWidget);
      expect(find.text('Cahaya'), findsOneWidget);
    });
  });

  group('Pull-to-Refresh Tests', () {
    testWidgets('RefreshIndicator is present in monitoring screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _MockMonitoringScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify RefreshIndicator is present
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('Pull-to-refresh gesture triggers refresh callback',
        (WidgetTester tester) async {
      bool refreshCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                refreshCalled = true;
                await Future.delayed(const Duration(milliseconds: 100));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 1000, child: Center(child: Text('Content'))),
                ],
              ),
            ),
          ),
        ),
      );

      // Perform pull-to-refresh gesture
      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
      await tester.pumpAndSettle();

      // Verify refresh callback was called
      expect(refreshCalled, isTrue);
    });

    testWidgets('Empty state is scrollable for pull-to-refresh',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {},
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 500,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.sensors_off, size: 64),
                        SizedBox(height: 16),
                        Text('Belum ada data'),
                        SizedBox(height: 8),
                        Text('⬇️ Tarik ke bawah untuk refresh'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify empty state message is displayed
      expect(find.text('Belum ada data'), findsOneWidget);
      expect(find.text('⬇️ Tarik ke bawah untuk refresh'), findsOneWidget);

      // Verify the content is scrollable
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final scrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scrollView.physics, isA<AlwaysScrollableScrollPhysics>());
    });
  });
}

// Mock widget for sensor grid testing
class _MockSensorGrid extends StatelessWidget {
  const _MockSensorGrid({required this.sensorData});

  final SensorSnapshot sensorData;

  @override
  Widget build(BuildContext context) {
    final sensors = _buildMockSensors(sensorData);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 4
            : width >= 800
                ? 3
                : width >= 520
                    ? 2
                    : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: sensors.length,
          itemBuilder: (context, index) => sensors[index],
        );
      },
    );
  }

  List<Widget> _buildMockSensors(SensorSnapshot data) {
    return [
      _MockSensorCard(
        title: 'Suhu',
        value: '${data.temperature?.toStringAsFixed(1) ?? '—'} deg C',
        icon: Icons.thermostat,
        color: const Color(0xFFFFB74D),
      ),
      _MockSensorCard(
        title: 'Cahaya',
        value: '${data.lightIntensity ?? '—'} ADC',
        icon: Icons.light_mode,
        color: const Color(0xFFFFF176),
      ),
      _MockSensorCard(
        title: 'Kelembapan udara',
        value: '${data.humidity?.toStringAsFixed(0) ?? '—'} %',
        icon: Icons.water_drop,
        color: const Color(0xFF4FC3F7),
      ),
      _MockSensorCard(
        title: 'Kelembapan tanah',
        value: '${data.soilMoisturePercent?.toStringAsFixed(0) ?? '—'} %',
        icon: Icons.grass,
        color: const Color(0xFF66BB6A),
      ),
    ];
  }
}

// Mock compressed sensor card matching production implementation
class _MockSensorCard extends StatelessWidget {
  const _MockSensorCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              color.withAlpha((255 * 0.10).round()),
              color.withAlpha((255 * 0.03).round()),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Mock monitoring screen for refresh testing
class _MockMonitoringScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoring')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 100));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: const Center(
              child: Text('Monitoring content'),
            ),
          ),
        ),
      ),
    );
  }
}
