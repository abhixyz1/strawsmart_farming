import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'watering_schedule_model.dart';
import 'watering_schedule_repository.dart';

/// State class for schedule form
class ScheduleFormState {
  final String name;
  final List<int> daysOfWeek; // 1-7, Monday=1
  final String timeOfDay; // "HH:mm"
  final int durationSec;
  final bool enabled;
  final int? moistureThreshold; // optional, null = no threshold
  final bool isLoading;
  final String? errorMessage;

  ScheduleFormState({
    this.name = '',
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7], // default: every day
    this.timeOfDay = '06:00',
    this.durationSec = 300, // 5 minutes
    this.enabled = true,
    this.moistureThreshold,
    this.isLoading = false,
    this.errorMessage,
  });

  ScheduleFormState copyWith({
    String? name,
    List<int>? daysOfWeek,
    String? timeOfDay,
    int? durationSec,
    bool? enabled,
    int? moistureThreshold,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ScheduleFormState(
      name: name ?? this.name,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      durationSec: durationSec ?? this.durationSec,
      enabled: enabled ?? this.enabled,
      moistureThreshold: moistureThreshold ?? this.moistureThreshold,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  ScheduleFormState clearError() {
    return copyWith(errorMessage: null, isLoading: false);
  }

  /// Initialize form from existing schedule
  static ScheduleFormState fromSchedule(WateringSchedule schedule) {
    return ScheduleFormState(
      name: schedule.name,
      daysOfWeek: List.from(schedule.daysOfWeek),
      timeOfDay: schedule.timeOfDay,
      durationSec: schedule.durationSec,
      enabled: schedule.enabled,
      moistureThreshold: schedule.moistureThreshold,
    );
  }

  /// Convert form state to schedule model
  WateringSchedule toSchedule(String id) {
    return WateringSchedule(
      id: id,
      name: name,
      daysOfWeek: daysOfWeek,
      timeOfDay: timeOfDay,
      durationSec: durationSec,
      enabled: enabled,
      moistureThreshold: moistureThreshold,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  bool get isValid => name.trim().isNotEmpty && daysOfWeek.isNotEmpty;
}

/// StateNotifier for managing schedule form
class ScheduleFormController extends StateNotifier<ScheduleFormState> {
  final WateringScheduleRepository _repository;

  ScheduleFormController(this._repository) : super(ScheduleFormState());

  void updateName(String name) {
    state = state.copyWith(name: name, errorMessage: null);
  }

  void updateTimeOfDay(String time) {
    state = state.copyWith(timeOfDay: time, errorMessage: null);
  }

  void updateDuration(int seconds) {
    state = state.copyWith(durationSec: seconds, errorMessage: null);
  }

  void toggleDay(int day) {
    final days = List<int>.from(state.daysOfWeek);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      days.add(day);
    }
    days.sort();
    state = state.copyWith(daysOfWeek: days, errorMessage: null);
  }

  void setDaysOfWeek(List<int> days) {
    state = state.copyWith(daysOfWeek: days, errorMessage: null);
  }

  void toggleEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled, errorMessage: null);
  }

  void updateMoistureThreshold(int? threshold) {
    state = state.copyWith(moistureThreshold: threshold, errorMessage: null);
  }

  void initializeFromSchedule(WateringSchedule schedule) {
    state = ScheduleFormState.fromSchedule(schedule);
  }

  void reset() {
    state = ScheduleFormState();
  }

  Future<bool> createSchedule(String uid) async {
    if (!state.isValid) {
      state = state.copyWith(errorMessage: 'Nama jadwal tidak boleh kosong');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final schedule = WateringSchedule(
        id: '', // Will be assigned by Firestore
        name: state.name,
        daysOfWeek: state.daysOfWeek,
        timeOfDay: state.timeOfDay,
        durationSec: state.durationSec,
        enabled: state.enabled,
        moistureThreshold: state.moistureThreshold,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _repository.createSchedule(uid, schedule);

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal membuat jadwal: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> updateSchedule(String uid, String scheduleId) async {
    if (!state.isValid) {
      state = state.copyWith(errorMessage: 'Nama jadwal tidak boleh kosong');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final schedule = WateringSchedule(
        id: scheduleId,
        name: state.name,
        daysOfWeek: state.daysOfWeek,
        timeOfDay: state.timeOfDay,
        durationSec: state.durationSec,
        enabled: state.enabled,
        moistureThreshold: state.moistureThreshold,
        createdAt: DateTime.now(), // Will be ignored in update
        updatedAt: DateTime.now(),
      );

      await _repository.updateSchedule(uid, schedule);

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memperbarui jadwal: ${e.toString()}',
      );
      return false;
    }
  }
}

/// Provider for schedule form controller
final scheduleFormControllerProvider =
    StateNotifierProvider.autoDispose<ScheduleFormController, ScheduleFormState>((ref) {
  final repository = ref.watch(wateringScheduleRepositoryProvider);
  return ScheduleFormController(repository);
});
