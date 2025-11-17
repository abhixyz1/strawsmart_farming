import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../screens/schedule/watering_schedule_repository.dart';
import '../../services/schedule_executor_service.dart';

/// Widget kartu status jadwal dengan kontrol manual
class ScheduleStatusCard extends ConsumerWidget {
  const ScheduleStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextSchedule = ref.watch(nextScheduleProvider);
    final executionStatus = ref.watch(scheduleExecutionStatusProvider);
    final executorService = ref.watch(scheduleExecutorServiceProvider);

    if (nextSchedule == null) {
      return _buildEmptyCard(context);
    }

    final nextTime = nextSchedule.getNextScheduledTime();
    final status = executionStatus.valueOrNull;

    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Header dengan gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.blue[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((255 * 0.2).round()),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.water_drop,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jadwal Penyiraman Otomatis',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextSchedule.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(status, nextSchedule.enabled),
              ],
            ),
          ),

          // Detail jadwal
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waktu berikutnya
                if (nextTime != null) ...[
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Berikutnya: ',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      Text(
                        '${nextTime.day}/${nextTime.month} • ${nextTime.hour.toString().padLeft(2, '0')}:${nextTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Durasi & threshold
                Row(
                  children: [
                    Icon(Icons.timer, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Durasi: ${nextSchedule.durationSec ~/ 60} menit',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                    if (nextSchedule.moistureThreshold != null) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.water, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Threshold: ${nextSchedule.moistureThreshold}%',
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                    ],
                  ],
                ),

                // Status message jika ada
                if (status != null && status['status'] != 'scheduled') ...[
                  const SizedBox(height: 12),
                  _buildStatusMessage(status),
                ],

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Tombol kontrol
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: executorService == null
                            ? null
                            : () => _handleSkip(context, ref, nextSchedule, executorService),
                        icon: const Icon(Icons.skip_next, size: 18),
                        label: const Text('Lewati'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: executorService == null
                            ? null
                            : () => _handleRunNow(context, ref, nextSchedule, executorService),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Jalankan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => context.pushNamed('schedule'),
                      icon: const Icon(Icons.settings),
                      tooltip: 'Kelola Jadwal',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 40, color: Colors.grey[400]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum ada jadwal penyiraman',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Buat jadwal untuk otomasi pompa',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => context.pushNamed('schedule'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Buat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic>? status, bool enabled) {
    if (!enabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((255 * 0.3).round()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'NONAKTIF',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final statusType = status?['status'] as String?;
    String label;
    Color bgColor;

    switch (statusType) {
      case 'executed':
        label = 'SELESAI';
        bgColor = Colors.green;
        break;
      case 'skipped':
        label = 'DILEWATI';
        bgColor = Colors.orange;
        break;
      case 'error':
        label = 'ERROR';
        bgColor = Colors.red;
        break;
      default:
        label = 'AKTIF';
        bgColor = Colors.greenAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withAlpha((255 * 0.9).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusMessage(Map<String, dynamic> status) {
    final statusType = status['status'] as String?;
    IconData icon;
    Color color;
    String message;

    switch (statusType) {
      case 'executed':
        icon = Icons.check_circle;
        color = Colors.green;
        message = 'Jadwal telah dijalankan';
        break;
      case 'skipped':
        icon = Icons.info;
        color = Colors.orange;
        final reason = status['skipReason'] ?? 'Tidak diketahui';
        message = 'Dilewati: $reason';
        break;
      case 'error':
        icon = Icons.error;
        color = Colors.red;
        final error = status['error'] ?? 'Tidak diketahui';
        message = 'Error: $error';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha((255 * 0.3).round())),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRunNow(
    BuildContext context,
    WidgetRef ref,
    schedule,
    ScheduleExecutorService service,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jalankan Sekarang?'),
        content: Text(
          'Pompa akan dinyalakan selama ${schedule.durationSec ~/ 60} menit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Jalankan'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await service.executeNow(schedule);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pompa telah dinyalakan'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSkip(
    BuildContext context,
    WidgetRef ref,
    schedule,
    ScheduleExecutorService service,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lewati Jadwal?'),
        content: const Text(
          'Jadwal berikutnya akan dilewati dan tidak dijalankan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Lewati'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await service.skipNext(schedule, 'Dilewati oleh pengguna');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Jadwal berikutnya telah dilewati'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
