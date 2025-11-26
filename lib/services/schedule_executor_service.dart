import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/schedule/watering_schedule_model.dart';
import '../screens/schedule/watering_schedule_repository.dart';
import '../screens/dashboard/dashboard_repository.dart';

/// Service untuk mengeksekusi jadwal penyiraman otomatis
class ScheduleExecutorService {
  ScheduleExecutorService({
    required this.deviceId,
    required this.database,
    required this.ref,
  }) {
    _initialize();
  }

  final String deviceId;
  final FirebaseDatabase database;
  final Ref ref;
  
  Timer? _checkTimer;
  String? _lastExecutedScheduleId;
  DateTime? _lastExecutionTime;
  bool _isExecuting = false;

  void _initialize() {
    // Check setiap 30 detik apakah ada jadwal yang perlu dijalankan
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAndExecuteSchedule();
    });

    // Sync jadwal berikutnya ke RTDB untuk display di firmware
    ref.listen<WateringSchedule?>(nextScheduleProvider, (prev, next) {
      _syncScheduleToRTDB(next);
    });
  }

  Future<void> _checkAndExecuteSchedule() async {
    if (_isExecuting) return;

    final nextSchedule = ref.read(nextScheduleProvider);
    if (nextSchedule == null || !nextSchedule.enabled) return;

    final nextRun = nextSchedule.getNextScheduledTime();
    if (nextRun == null) return;

    final now = DateTime.now();
    final diff = nextRun.difference(now);

    // Jika waktu eksekusi sudah tiba (dalam 1 menit terakhir)
    if (diff.inSeconds <= 60 && diff.inSeconds >= 0) {
      // Cek apakah sudah dijalankan sebelumnya
      if (_lastExecutedScheduleId == nextSchedule.id &&
          _lastExecutionTime != null &&
          now.difference(_lastExecutionTime!).inMinutes < 5) {
        return; // Skip jika baru saja dijalankan
      }

      await _executeSchedule(nextSchedule);
    }
  }

  Future<void> _executeSchedule(WateringSchedule schedule) async {
    _isExecuting = true;

    try {
      // Cek kelembaban tanah jika ada threshold
      if (schedule.moistureThreshold != null) {
        final telemetry = ref.read(latestTelemetryProvider).valueOrNull;
        final soilMoisture = telemetry?.soilMoisturePercent;

        if (soilMoisture != null && soilMoisture >= schedule.moistureThreshold!) {
          // Tanah sudah cukup lembab, tunda jadwal
          await _markScheduleSkipped(
            schedule,
            'Tanah sudah lembab ($soilMoisture%)',
          );
          _isExecuting = false;
          return;
        }
      }

      // Jalankan pompa
      final repo = ref.read(dashboardRepositoryProvider);
      await repo.sendPumpCommand(
        turnOn: true,
        durationSeconds: schedule.durationSec,
      );

      // Catat eksekusi
      _lastExecutedScheduleId = schedule.id;
      _lastExecutionTime = DateTime.now();

      await _markScheduleExecuted(schedule);
    } catch (e) {
      await _markScheduleError(schedule, e.toString());
    } finally {
      _isExecuting = false;
    }
  }

  Future<void> _syncScheduleToRTDB(WateringSchedule? schedule) async {
    final ref = database.ref('devices/$deviceId/control/schedule');

    if (schedule == null) {
      await ref.remove();
      return;
    }

    final nextRun = schedule.getNextScheduledTime();

    await ref.set({
      'scheduleId': schedule.id,
      'name': schedule.name,
      'nextRun': nextRun?.millisecondsSinceEpoch,
      'durationSec': schedule.durationSec,
      'moistureThreshold': schedule.moistureThreshold,
      'enabled': schedule.enabled,
      'status': 'scheduled',
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> _markScheduleExecuted(WateringSchedule schedule) async {
    final ref = database.ref('devices/$deviceId/control/schedule');
    await ref.update({
      'status': 'executed',
      'lastExecutedAt': ServerValue.timestamp,
      'executedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _markScheduleSkipped(
    WateringSchedule schedule,
    String reason,
  ) async {
    final ref = database.ref('devices/$deviceId/control/schedule');
    await ref.update({
      'status': 'skipped',
      'skipReason': reason,
      'skippedAt': ServerValue.timestamp,
    });
  }

  Future<void> _markScheduleError(WateringSchedule schedule, String error) async {
    final ref = database.ref('devices/$deviceId/control/schedule');
    await ref.update({
      'status': 'error',
      'error': error,
      'errorAt': ServerValue.timestamp,
    });
  }

  /// Manual trigger - jalankan jadwal sekarang
  Future<void> executeNow(WateringSchedule schedule) async {
    await _executeSchedule(schedule);
  }

  /// Skip jadwal berikutnya
  Future<void> skipNext(WateringSchedule schedule, String reason) async {
    await _markScheduleSkipped(schedule, reason);
  }

  void dispose() {
    _checkTimer?.cancel();
  }
}

/// Provider untuk schedule executor
final scheduleExecutorServiceProvider = Provider.autoDispose<ScheduleExecutorService?>((ref) {
  // Hanya aktif jika ada next schedule
  final nextSchedule = ref.watch(nextScheduleProvider);
  if (nextSchedule == null) return null;

  final db = FirebaseDatabase.instance;
  // Gunakan deviceId dari selected greenhouse
  final deviceId = ref.watch(dashboardDeviceIdProvider);

  final service = ScheduleExecutorService(
    deviceId: deviceId,
    database: db,
    ref: ref,
  );

  ref.onDispose(() => service.dispose());

  return service;
});

/// Provider untuk status eksekusi jadwal dari RTDB
final scheduleExecutionStatusProvider = StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final db = FirebaseDatabase.instance;
  // Gunakan deviceId dari selected greenhouse
  final deviceId = ref.watch(dashboardDeviceIdProvider);

  return db
      .ref('devices/$deviceId/control/schedule')
      .onValue
      .map((event) => event.snapshot.value as Map<String, dynamic>?);
});
