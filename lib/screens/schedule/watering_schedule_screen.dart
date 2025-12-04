import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'watering_schedule_model.dart';
import 'watering_schedule_repository.dart';
import 'watering_schedule_controller.dart';
import '../auth/auth_repository.dart';
import '../auth/user_profile_repository.dart';

// ============================================================================
// WATERING SCHEDULE SCREEN - Modern & Eye-catching Design with Strawberry Theme
// ============================================================================

class WateringScheduleScreen extends ConsumerWidget {
  const WateringScheduleScreen({super.key});

  // Strawberry theme colors
  static const _primaryGreen = Color(0xFF6B9080);
  static const _darkGreen = Color(0xFF5A7D6E);
  static const _accentGreen = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Harap login terlebih dahulu')),
      );
    }

    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final canManageSchedule = profile?.role.canManageSchedule ?? false;

    final schedulesAsync = ref.watch(wateringSchedulesProvider);
    final nextSchedule = ref.watch(nextScheduleProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text(
          'Jadwal Penyiraman',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Curved header decoration
          Container(
            height: 30,
            decoration: const BoxDecoration(
              color: _primaryGreen,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          // Info box for Owner
          if (!canManageSchedule)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildInfoCard(
                icon: Icons.visibility_outlined,
                text: 'Mode monitoring - Anda hanya dapat melihat jadwal',
                color: const Color(0xFF64B5F6),
              ),
            ),
          Expanded(
            child: schedulesAsync.when(
              data: (schedules) {
                if (schedules.isEmpty) {
                  return _buildEmptyState(context, ref, user.uid, canManageSchedule);
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (nextSchedule != null) ...[
                      _buildNextScheduleCard(context, nextSchedule),
                      const SizedBox(height: 20),
                    ],
                    // Section header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _primaryGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Semua Jadwal',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2D3436),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _primaryGreen.withAlpha((255 * 0.1).round()),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${schedules.length} jadwal',
                              style: const TextStyle(
                                color: _primaryGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Schedule cards
                    ...schedules.map((schedule) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildScheduleCard(
                        context,
                        ref,
                        user.uid,
                        schedule,
                        canManageSchedule,
                      ),
                    )),
                    const SizedBox(height: 80), // Space for FAB
                  ],
                );
              },
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _primaryGreen.withAlpha((255 * 0.1).round()),
                        shape: BoxShape.circle,
                      ),
                      child: const CircularProgressIndicator(
                        color: _primaryGreen,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Memuat jadwal...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: canManageSchedule
          ? FloatingActionButton.extended(
              onPressed: () => _showScheduleDialog(context, ref, user.uid),
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Tambah Jadwal',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha((255 * 0.3).round())),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha((255 * 0.2).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color.withAlpha((255 * 0.9).round()),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, String uid, bool canManage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty state illustration
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: _primaryGreen.withAlpha((255 * 0.1).round()),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _primaryGreen.withAlpha((255 * 0.15).round()),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_drop_outlined,
                  size: 60,
                  color: _primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ada Jadwal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D3436),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat jadwal penyiraman untuk\nmengatur irigasi otomatis',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            if (canManage)
              ElevatedButton.icon(
                onPressed: () => _showScheduleDialog(context, ref, uid),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Buat Jadwal Pertama',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextScheduleCard(BuildContext context, WateringSchedule schedule) {
    final nextTime = schedule.getNextScheduledTime();
    if (nextTime == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final difference = nextTime.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    String countdown;
    if (hours > 0) {
      countdown = '${hours}j ${minutes}m lagi';
    } else if (minutes > 0) {
      countdown = '$minutes menit lagi';
    } else {
      countdown = 'Segera';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [_primaryGreen, _darkGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withAlpha((255 * 0.3).round()),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative elements
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha((255 * 0.08).round()),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -15,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha((255 * 0.05).round()),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((255 * 0.2).round()),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            const Text(
                              'Penyiraman Berikutnya',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Countdown badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          countdown,
                          style: const TextStyle(
                            color: _primaryGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Schedule info
                  Row(
                    children: [
                      // Water drop icon with animation feel
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((255 * 0.15).round()),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.water_drop_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(nextTime),
                              style: TextStyle(
                                color: Colors.white.withAlpha((255 * 0.8).round()),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: Colors.white.withAlpha((255 * 0.7).round()),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('HH:mm').format(nextTime),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '• ${schedule.durationSec ~/ 60} menit',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha((255 * 0.7).round()),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canManage
              ? () async {
                  await repository.toggleEnabled(uid, schedule.id, !schedule.enabled);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: schedule.enabled
                        ? const LinearGradient(
                            colors: [_primaryGreen, _darkGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: schedule.enabled ? null : Colors.grey[200],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    schedule.enabled ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                    color: schedule.enabled ? Colors.white : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Schedule info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              schedule.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: schedule.enabled 
                                    ? const Color(0xFF2D3436) 
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          // Enable/disable chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: schedule.enabled
                                  ? _accentGreen.withAlpha((255 * 0.15).round())
                                  : Colors.grey.withAlpha((255 * 0.15).round()),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              schedule.enabled ? 'Aktif' : 'Nonaktif',
                              style: TextStyle(
                                color: schedule.enabled ? _accentGreen : Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Time & days
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            schedule.timeOfDay,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              schedule.daysDisplay,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Duration & threshold
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.timer_outlined,
                            '${schedule.durationSec ~/ 60}m',
                          ),
                          const SizedBox(width: 8),
                          if (schedule.moistureThreshold != null)
                            _buildInfoChip(
                              Icons.water_outlined,
                              '${schedule.moistureThreshold}%',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action menu
                if (canManage)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                          builder: (context) => _DeleteConfirmDialog(
                            scheduleName: schedule.name,
                          ),
                        );
                        if (confirm == true) {
                          await repository.deleteSchedule(uid, schedule.id);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 18, color: _primaryGreen),
                            const SizedBox(width: 8),
                            const Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('Hapus', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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

// ============================================================================
// DELETE CONFIRM DIALOG
// ============================================================================

class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog({required this.scheduleName});

  final String scheduleName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha((255 * 0.1).round()),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.delete_outline, color: Colors.red),
          ),
          const SizedBox(width: 12),
          const Text('Hapus Jadwal'),
        ],
      ),
      content: Text('Yakin ingin menghapus "$scheduleName"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Hapus'),
        ),
      ],
    );
  }
}

// ============================================================================
// SCHEDULE FORM DIALOG - Redesigned
// ============================================================================

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

  static const _primaryGreen = Color(0xFF6B9080);

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primaryGreen.withAlpha((255 * 0.15).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              color: _primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.existingSchedule == null ? 'Tambah Jadwal' : 'Edit Jadwal',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nama Jadwal',
                hintText: 'Contoh: Pagi Hari',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primaryGreen, width: 2),
                ),
                prefixIcon: const Icon(Icons.label_outline),
              ),
              onChanged: controller.updateName,
            ),
            const SizedBox(height: 20),

            // Days selector
            const Text(
              'Hari Aktif',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (index) {
                final day = index + 1;
                final isSelected = formState.daysOfWeek.contains(day);
                final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                return GestureDetector(
                  onTap: () => controller.toggleDay(day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryGreen : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _primaryGreen : Colors.grey[300]!,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        dayNames[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Time picker
            InkWell(
              onTap: () async {
                final parts = formState.timeOfDay.split(':');
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: int.parse(parts[0]),
                    minute: int.parse(parts[1]),
                  ),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: _primaryGreen,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (time != null) {
                  controller.updateTimeOfDay(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: _primaryGreen),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waktu',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          formState.timeOfDay,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Duration slider
            const Text(
              'Durasi Penyiraman',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _primaryGreen,
                      inactiveTrackColor: _primaryGreen.withAlpha((255 * 0.2).round()),
                      thumbColor: _primaryGreen,
                      overlayColor: _primaryGreen.withAlpha((255 * 0.2).round()),
                    ),
                    child: Slider(
                      value: formState.durationSec.toDouble(),
                      min: 60,
                      max: 1800,
                      divisions: 29,
                      onChanged: (value) => controller.updateDuration(value.toInt()),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _primaryGreen.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${formState.durationSec ~/ 60} menit',
                    style: const TextStyle(
                      color: _primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Moisture threshold toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: const Text(
                      'Threshold Kelembapan',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Siram hanya jika kelembapan di bawah nilai',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _useMoistureThreshold,
                    activeTrackColor: _primaryGreen,
                    activeThumbColor: _primaryGreen,
                    onChanged: (value) {
                      setState(() => _useMoistureThreshold = value);
                      controller.updateMoistureThreshold(value ? _moistureValue.toInt() : null);
                    },
                  ),
                  if (_useMoistureThreshold)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: _primaryGreen,
                                inactiveTrackColor: _primaryGreen.withAlpha((255 * 0.2).round()),
                                thumbColor: _primaryGreen,
                              ),
                              child: Slider(
                                value: _moistureValue,
                                min: 0,
                                max: 100,
                                divisions: 20,
                                onChanged: (value) {
                                  setState(() => _moistureValue = value);
                                  controller.updateMoistureThreshold(value.toInt());
                                },
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _primaryGreen.withAlpha((255 * 0.1).round()),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_moistureValue.toInt()}%',
                              style: const TextStyle(
                                color: _primaryGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Error message
            if (formState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          formState.errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Batal',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.existingSchedule == null ? 'Tambah' : 'Simpan',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }
}
