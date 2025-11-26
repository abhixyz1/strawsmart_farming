import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'watering_schedule_model.dart';
import 'watering_schedule_repository.dart';
import 'watering_schedule_controller.dart';
import '../auth/auth_repository.dart';
import '../auth/user_profile_repository.dart';

class WateringScheduleScreen extends ConsumerWidget {
  const WateringScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Harap login terlebih dahulu')),
      );
    }

    // Cek role untuk permission
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final canManageSchedule = profile?.role.canManageSchedule ?? false;

    final schedulesAsync = ref.watch(wateringSchedulesProvider);
    final nextSchedule = ref.watch(nextScheduleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Penyiraman'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // Info box untuk Owner (view only)
          if (!canManageSchedule)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha((255 * 0.1).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withAlpha((255 * 0.3).round())),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mode monitoring - Anda hanya dapat melihat jadwal penyiraman',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: schedulesAsync.when(
              data: (schedules) {
                if (schedules.isEmpty) {
                  return _buildEmptyState(context, ref, user.uid, canManageSchedule);
                }
                return Column(
                  children: [
                    if (nextSchedule != null) _buildNextScheduleCard(nextSchedule),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: schedules.length,
                        itemBuilder: (context, index) {
                          return _buildScheduleCard(
                            context,
                            ref,
                            user.uid,
                            schedules[index],
                            canManageSchedule,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
            ),
          ),
        ],
      ),
      // FAB hanya untuk Admin & Petani
      floatingActionButton: canManageSchedule
          ? FloatingActionButton.extended(
              onPressed: () => _showScheduleDialog(context, ref, user.uid),
              backgroundColor: Colors.green,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Jadwal'),
            )
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, String uid, bool canManage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.water_drop_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Belum ada jadwal penyiraman',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (canManage)
            ElevatedButton.icon(
            onPressed: () => _showScheduleDialog(context, ref, uid),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Jadwal Pertama'),
          ),
        ],
      ),
    );
  }

  Widget _buildNextScheduleCard(WateringSchedule schedule) {
    final nextTime = schedule.getNextScheduledTime();
    if (nextTime == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blue, Colors.lightBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Penyiraman Berikutnya',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  schedule.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('EEEE, d MMM yyyy • HH:mm', 'id_ID').format(nextTime),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(
    BuildContext context,
    WidgetRef ref,
    String uid,
    WateringSchedule schedule,
    bool canManage,
  ) {
    final repository = ref.read(wateringScheduleRepositoryProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: schedule.enabled ? Colors.green : Colors.grey,
          child: Icon(
            schedule.enabled ? Icons.water_drop : Icons.water_drop_outlined,
            color: Colors.white,
          ),
        ),
        title: Text(
          schedule.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${schedule.daysDisplay} • ${schedule.timeOfDay}'),
            Text('Durasi: ${schedule.durationSec ~/ 60} menit'),
            if (schedule.moistureThreshold != null)
              Text('Threshold: ${schedule.moistureThreshold}%'),
          ],
        ),
        // Hanya tampilkan menu edit/delete untuk Admin & Petani
        trailing: canManage
            ? PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    _showScheduleDialog(
                      context,
                      ref,
                      uid,
                      existingSchedule: schedule,
                    );
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Hapus Jadwal'),
                        content: Text('Yakin ingin menghapus "${schedule.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await repository.deleteSchedule(uid, schedule.id);
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              )
            : null,
        // Toggle enable/disable hanya untuk Admin & Petani
        onTap: canManage
            ? () async {
                await repository.toggleEnabled(uid, schedule.id, !schedule.enabled);
              }
            : null,
      ),
    );
  }

  void _showScheduleDialog(
    BuildContext context,
    WidgetRef ref,
    String uid, {
    WateringSchedule? existingSchedule,
  }) {
    showDialog(
      context: context,
      builder: (context) => _ScheduleFormDialog(
        uid: uid,
        existingSchedule: existingSchedule,
      ),
    );
  }
}

class _ScheduleFormDialog extends ConsumerStatefulWidget {
  const _ScheduleFormDialog({
    required this.uid,
    this.existingSchedule,
  });

  final String uid;
  final WateringSchedule? existingSchedule;

  @override
  ConsumerState<_ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends ConsumerState<_ScheduleFormDialog> {
  final _nameController = TextEditingController();
  bool _useMoistureThreshold = false;
  double _moistureValue = 40;

  @override
  void initState() {
    super.initState();
    if (widget.existingSchedule != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(scheduleFormControllerProvider.notifier)
            .initializeFromSchedule(widget.existingSchedule!);
        _nameController.text = widget.existingSchedule!.name;
        if (widget.existingSchedule!.moistureThreshold != null) {
          _useMoistureThreshold = true;
          _moistureValue = widget.existingSchedule!.moistureThreshold!.toDouble();
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(scheduleFormControllerProvider);
    final controller = ref.read(scheduleFormControllerProvider.notifier);

    return AlertDialog(
      title: Text(widget.existingSchedule == null ? 'Tambah Jadwal' : 'Edit Jadwal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Jadwal',
                border: OutlineInputBorder(),
              ),
              onChanged: controller.updateName,
            ),
            const SizedBox(height: 16),
            const Text('Hari', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (index) {
                final day = index + 1;
                final isSelected = formState.daysOfWeek.contains(day);
                final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                return FilterChip(
                  label: Text(dayNames[index]),
                  selected: isSelected,
                  onSelected: (_) => controller.toggleDay(day),
                  selectedColor: Colors.green,
                );
              }),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Waktu'),
              subtitle: Text(formState.timeOfDay),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final parts = formState.timeOfDay.split(':');
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: int.parse(parts[0]),
                    minute: int.parse(parts[1]),
                  ),
                );
                if (time != null) {
                  controller.updateTimeOfDay(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            Text('Durasi: ${formState.durationSec ~/ 60} menit'),
            Slider(
              value: formState.durationSec.toDouble(),
              min: 60,
              max: 1800,
              divisions: 29,
              label: '${formState.durationSec ~/ 60} menit',
              onChanged: (value) => controller.updateDuration(value.toInt()),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Gunakan Threshold Kelembapan'),
              value: _useMoistureThreshold,
              onChanged: (value) {
                setState(() => _useMoistureThreshold = value);
                controller.updateMoistureThreshold(value ? _moistureValue.toInt() : null);
              },
            ),
            if (_useMoistureThreshold) ...[
              Text('Threshold: ${_moistureValue.toInt()}%'),
              Slider(
                value: _moistureValue,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${_moistureValue.toInt()}%',
                onChanged: (value) {
                  setState(() => _moistureValue = value);
                  controller.updateMoistureThreshold(value.toInt());
                },
              ),
            ],
            if (formState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  formState.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: formState.isLoading
              ? null
              : () async {
                  bool success;
                  if (widget.existingSchedule == null) {
                    success = await controller.createSchedule(widget.uid);
                  } else {
                    success = await controller.updateSchedule(
                      widget.uid,
                      widget.existingSchedule!.id,
                    );
                  }
                  if (success && context.mounted) {
                    Navigator.pop(context);
                  }
                },
          child: formState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.existingSchedule == null ? 'Tambah' : 'Simpan'),
        ),
      ],
    );
  }
}
