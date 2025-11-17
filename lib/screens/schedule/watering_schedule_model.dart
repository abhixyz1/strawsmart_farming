import 'package:cloud_firestore/cloud_firestore.dart';

class WateringSchedule {
  const WateringSchedule({
    required this.id,
    required this.name,
    required this.daysOfWeek,
    required this.timeOfDay,
    required this.durationSec,
    required this.enabled,
    this.moistureThreshold,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final List<int> daysOfWeek; // 1-7 (Monday-Sunday)
  final String timeOfDay; // "HH:mm" format
  final int durationSec;
  final bool enabled;
  final int? moistureThreshold; // 0-100, if null no threshold check
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory WateringSchedule.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final daysOfWeekData = data['daysOfWeek'];
    final daysOfWeek = daysOfWeekData is List
        ? daysOfWeekData.map((e) => e as int).toList()
        : <int>[];

    return WateringSchedule(
      id: id,
      name: data['name'] as String? ?? '',
      daysOfWeek: daysOfWeek,
      timeOfDay: data['timeOfDay'] as String? ?? '08:00',
      durationSec: data['durationSec'] as int? ?? 30,
      enabled: data['enabled'] as bool? ?? true,
      moistureThreshold: data['moistureThreshold'] as int?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'daysOfWeek': daysOfWeek,
      'timeOfDay': timeOfDay,
      'durationSec': durationSec,
      'enabled': enabled,
      'moistureThreshold': moistureThreshold,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  WateringSchedule copyWith({
    String? id,
    String? name,
    List<int>? daysOfWeek,
    String? timeOfDay,
    int? durationSec,
    bool? enabled,
    int? moistureThreshold,
    bool clearThreshold = false,
  }) {
    return WateringSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      durationSec: durationSec ?? this.durationSec,
      enabled: enabled ?? this.enabled,
      moistureThreshold: clearThreshold ? null : (moistureThreshold ?? this.moistureThreshold),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Returns next scheduled DateTime for this schedule
  DateTime? getNextScheduledTime() {
    if (!enabled || daysOfWeek.isEmpty) return null;

    final now = DateTime.now();
    final timeParts = timeOfDay.split(':');
    if (timeParts.length != 2) return null;

    final hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;

    // Check today first
    final todaySchedule = DateTime(now.year, now.month, now.day, hour, minute);
    final todayWeekday = now.weekday; // 1-7 (Monday-Sunday)

    if (daysOfWeek.contains(todayWeekday) && todaySchedule.isAfter(now)) {
      return todaySchedule;
    }

    // Find next day in the week
    for (int i = 1; i <= 7; i++) {
      final checkDate = now.add(Duration(days: i));
      final checkWeekday = checkDate.weekday;
      if (daysOfWeek.contains(checkWeekday)) {
        return DateTime(checkDate.year, checkDate.month, checkDate.day, hour, minute);
      }
    }

    return null;
  }

  /// Formats time for display
  String get formattedTime => timeOfDay;

  /// Gets day names for display
  String get daysDisplay {
    final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    if (daysOfWeek.isEmpty) return 'Tidak ada hari dipilih';
    if (daysOfWeek.length == 7) return 'Setiap hari';
    
    final sortedDays = daysOfWeek.toList()..sort();
    return sortedDays.map((day) => dayNames[day - 1]).join(', ');
  }
}
