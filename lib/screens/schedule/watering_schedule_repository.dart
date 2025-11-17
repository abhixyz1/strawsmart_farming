import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_repository.dart';
import 'watering_schedule_model.dart';

final wateringScheduleRepositoryProvider = Provider<WateringScheduleRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return WateringScheduleRepository(firestore);
});

final wateringSchedulesProvider = StreamProvider<List<WateringSchedule>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  
  return ref.read(wateringScheduleRepositoryProvider).watchSchedules(user.uid);
});

final nextScheduleProvider = Provider<WateringSchedule?>((ref) {
  final schedules = ref.watch(wateringSchedulesProvider).valueOrNull ?? [];
  final enabledSchedules = schedules.where((s) => s.enabled).toList();
  
  if (enabledSchedules.isEmpty) return null;
  
  // Find schedule with earliest next occurrence
  WateringSchedule? next;
  DateTime? nextTime;
  
  for (final schedule in enabledSchedules) {
    final scheduleTime = schedule.getNextScheduledTime();
    if (scheduleTime != null) {
      if (nextTime == null || scheduleTime.isBefore(nextTime)) {
        nextTime = scheduleTime;
        next = schedule;
      }
    }
  }
  
  return next;
});

class WateringScheduleRepository {
  WateringScheduleRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _schedulesCollection(String uid) {
    return _firestore.collection('wateringSchedules').doc(uid).collection('items');
  }

  Stream<List<WateringSchedule>> watchSchedules(String uid) {
    return _schedulesCollection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WateringSchedule.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> createSchedule(String uid, WateringSchedule schedule) async {
    await _schedulesCollection(uid).add(schedule.toFirestoreCreate());
  }

  Future<void> updateSchedule(String uid, WateringSchedule schedule) async {
    await _schedulesCollection(uid).doc(schedule.id).update(schedule.toFirestore());
  }

  Future<void> deleteSchedule(String uid, String scheduleId) async {
    await _schedulesCollection(uid).doc(scheduleId).delete();
  }

  Future<void> toggleEnabled(String uid, String scheduleId, bool enabled) async {
    await _schedulesCollection(uid).doc(scheduleId).update({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
