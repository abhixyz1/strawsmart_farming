import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/user_profile_repository.dart';
import '../greenhouse/greenhouse_repository.dart';
import '../monitoring/monitoring_screen.dart';
import '../profile/profile_screen.dart';
import '../batch/batch_management_screen.dart';
import '../logs/logs_screen.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/schedule_status_card.dart';
import '../../services/schedule_executor_service.dart';
import '../../widgets/greenhouse_selector.dart';
import 'dashboard_repository.dart';
import 'widgets/strawberry_guidance_section.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isSendingPumpCommand = false;
  bool _isUpdatingControlMode = false;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Beranda',
    ),
    NavigationDestination(
      icon: Icon(Icons.show_chart_outlined),
      selectedIcon: Icon(Icons.show_chart),
      label: 'Monitoring',
    ),
    NavigationDestination(
      icon: Icon(Icons.eco_outlined),
      selectedIcon: Icon(Icons.eco),
      label: 'Batch',
    ),
    NavigationDestination(
      icon: Icon(Icons.description_outlined),
      selectedIcon: Icon(Icons.description),
      label: 'Laporan',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Pengaturan',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final latestAsync = ref.watch(latestTelemetryProvider);
    final statusAsync = ref.watch(deviceStatusProvider);
    final pumpAsync = ref.watch(pumpStatusProvider);
    final controlModeAsync = ref.watch(controlModeProvider);
    final sectionTitle = _destinations[_selectedIndex].label;
    
    // Aktivasi schedule executor service
    ref.watch(scheduleExecutorServiceProvider);
    
    return AppShell(
      destinations: _destinations,
      selectedIndex: _selectedIndex,
      onIndexChanged: (index) => setState(() => _selectedIndex = index),
      floatingActionButton: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardAppBar(
            title: sectionTitle,
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildBody(
              sectionTitle,
              latestAsync,
              statusAsync,
              pumpAsync,
              controlModeAsync,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    String sectionTitle,
    AsyncValue<SensorSnapshot?> latestAsync,
    AsyncValue<DeviceStatusData?> statusAsync,
    AsyncValue<PumpStatusData?> pumpAsync,
    AsyncValue<ControlMode> controlModeAsync,
  ) {
    // Tab Pengaturan (index 4)
    if (_selectedIndex == 4) {
      return const ProfileScreen();
    }

    // Tab Monitoring (index 1)
    if (_selectedIndex == 1) {
      return const MonitoringScreen();
    }

    // Tab Batch (index 2)
    if (_selectedIndex == 2) {
      return const BatchManagementScreen();
    }

    // Tab Laporan (index 3)
    if (_selectedIndex == 3) {
      return const LaporanScreen();
    }

    // Tab Beranda (index 0)
    final profileAsync = ref.watch(currentUserProfileProvider);
    final displayName = profileAsync.when<String?>(
      data: (profile) => profile?.name,
      loading: () => null,
      error: (_, __) => null,
    );

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async {
        // Invalidate all providers to refresh data
        ref.invalidate(latestTelemetryProvider);
        ref.invalidate(deviceStatusProvider);
        ref.invalidate(pumpStatusProvider);
        ref.invalidate(controlModeProvider);
        
        // Add haptic feedback
        HapticFeedback.mediumImpact();
        
        // Small delay for better UX
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroHeader(userName: displayName),
            const SizedBox(height: 28),
            _SectionHeader(
              title: 'Sensor Wokwi real-time',
              subtitle:
                  'Terhubung ke modul virtual untuk suhu, cahaya, kelembapan, dan tanah.',
            ),
            const SizedBox(height: 16),
            _buildSensorSection(latestAsync),
            const SizedBox(height: 32),
            const StrawberryGuidanceSection(), // Insight budidaya stroberi
            const SizedBox(height: 32),
            const ScheduleStatusCard(), // Kartu jadwal otomatis dengan kontrol
            const SizedBox(height: 32),
            _SectionHeader(
              title: 'Kontrol lingkungan',
              subtitle: 'Pantau pompa air & insight budidaya StrawSmart.',
            ),
            const SizedBox(height: 16),
            _buildPumpCard(
              statusAsync,
              pumpAsync,
              controlModeAsync,
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildSensorSection(AsyncValue<SensorSnapshot?> latestAsync) {
    // Get cached value even during loading/refresh
    final data = latestAsync.valueOrNull;
    final error = latestAsync.error;

    // Show error if exists and no cached data
    if (error != null && data == null) {
      return _SectionMessageCard(
        icon: Icons.error_outline,
        message: 'Gagal memuat data sensor: $error',
      );
    }

    // Show empty state if no data and not loading
    if (data == null && !latestAsync.isLoading) {
      return const _SectionMessageCard(
        icon: Icons.sensors_off,
        message:
            'Belum ada data sensor dari perangkat. Pastikan simulasi Wokwi berjalan dan node terhubung ke Firebase.',
      );
    }

    // Show loading message only on very first load
    if (data == null && latestAsync.isLoading) {
      return const _SectionMessageCard(
        icon: Icons.sensors_off,
        message: 'Menunggu data sensor dari perangkat...',
      );
    }

    // Show data (cached or fresh)
    final sensors = _sensorStatusesFromData(data!);
    final lastUpdated = data.timestampMillis != null 
        ? _formatTimeAgo(DateTime.fromMillisecondsSinceEpoch(data.timestampMillis!)) 
        : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Terakhir diperbarui $lastUpdated',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // Minimal 2 kolom di mobile (≤520px), 3 di tablet, 4 di desktop
            final columns = width >= 1100
                ? 4
                : width >= 800
                    ? 3
                    : 2; // Minimal 2 kolom untuk mobile
            // Compressed cards dengan aspect ratio 1.2 untuk visual density optimal
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemCount: sensors.length,
              itemBuilder: (context, index) {
                final sensor = sensors[index];
                return _SensorStatusCard(sensor: sensor);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPumpCard(
    AsyncValue<DeviceStatusData?> statusAsync,
    AsyncValue<PumpStatusData?> pumpAsync,
    AsyncValue<ControlMode> controlModeAsync,
  ) {
    // Use valueOrNull to get cached data even during refresh
    final status = statusAsync.valueOrNull;
    final pump = pumpAsync.valueOrNull;
    final controlMode = controlModeAsync.valueOrNull ?? ControlMode.auto;
    final pumpError = _errorOrNull(pumpAsync) ?? _errorOrNull(statusAsync);

    // Show error if exists and no cached data
    if (pumpError != null && pump == null) {
      return _SectionMessageCard(
        icon: Icons.error_outline,
        message: 'Gagal memuat status pompa: $pumpError',
      );
    }

    // Show loading only on very first load
    if (pump == null && pumpAsync.isLoading && !pumpAsync.hasValue) {
      return const _SectionMessageCard(
        icon: Icons.water_drop_outlined,
        message: 'Menunggu status pompa dari perangkat...',
      );
    }

    // Show empty state if no data available
    if (pump == null) {
      return const _SectionMessageCard(
        icon: Icons.sensors,
        message: 'Menunggu perangkat melaporkan status pompa.',
      );
    }

    final runtimeLabel = _pumpRuntimeLabel(status, pump);

    return _PumpStatusCard(
      status: status,
      pump: pump,
      controlMode: controlMode,
      runtimeLabel: runtimeLabel,
      isSendingPump: _isSendingPumpCommand,
      isUpdatingMode: _isUpdatingControlMode,
      onPumpToggle: (value) => _handlePumpToggle(value, controlMode, status),
      onModeChange: _setControlMode,
      onRefresh: _refreshRealtimeFeeds,
    );
  }

  List<_SensorStatus> _sensorStatusesFromData(SensorSnapshot data) {
    final soilPercent = data.soilMoisturePercent;
    final lightPercent = data.lightIntensity == null
        ? null
        : (data.lightIntensity!.clamp(0, 4095) / 4095) * 100;

    String lightStatus;
    if (lightPercent == null) {
      lightStatus = 'Menunggu data cahaya dari sensor LDR.';
    } else if (lightPercent < 40) {
      lightStatus = 'Intensitas rendah, tingkatkan grow light.';
    } else if (lightPercent > 85) {
      lightStatus = 'Sangat terang, pertimbangkan menurunkan intensitas.';
    } else {
      lightStatus = 'Cahaya stabil untuk fase vegetatif.';
    }

    return [
      _SensorStatus(
        title: 'Suhu',
        module: 'Wokwi DHT22',
        value: data.temperature != null
            ? '${data.temperature!.toStringAsFixed(1)} deg C'
            : '—',
        status: _describeRange(
          data.temperature,
          min: 24,
          max: 28,
          low: 'Di bawah target siang (24-28 deg C).',
          high: 'Lebih panas dari target, cek exhaust.',
          ok: 'Suhu berada di rentang ideal.',
        ),
        range: '24-28 deg C',
        icon: Icons.thermostat,
        color: const Color(0xFFFFB74D),
      ),
      _SensorStatus(
        title: 'Cahaya',
        module: 'Wokwi LDR',
        value: data.lightIntensity == null
            ? '—'
            : '${data.lightIntensity} ADC (${lightPercent!.toStringAsFixed(0)}%)',
        status: lightStatus,
        range: '15-20k lux',
        icon: Icons.light_mode,
        color: const Color(0xFFFFF176),
      ),
      _SensorStatus(
        title: 'Kelembapan udara',
        module: 'Wokwi DHT22',
        value: data.humidity != null
            ? '${data.humidity!.toStringAsFixed(0)} %'
            : '—',
        status: _describeRange(
          data.humidity,
          min: 55,
          max: 70,
          low: 'Humidifier siap dinyalakan (di bawah 55%).',
          high: 'Kelembapan tinggi, aktifkan exhaust.',
          ok: 'Kelembapan nyaman untuk stroberi.',
        ),
        range: '55-70 %',
        icon: Icons.water_drop,
        color: const Color(0xFF4FC3F7),
      ),
      _SensorStatus(
        title: 'Kelembapan tanah',
        module: 'Wokwi Soil',
        value: soilPercent != null
            ? '${soilPercent.toStringAsFixed(0)} %'
            : '—',
        status: _describeRange(
          soilPercent,
          min: 35,
          max: 45,
          low: 'Tanah kering, fuzzy logic siap menjadwalkan siram.',
          high: 'Media lembap, tunda penyiraman.',
          ok: 'Tanah berada di zona ideal (35-45%).',
        ),
        range: '35-45 %',
        icon: Icons.grass,
        color: const Color(0xFF81C784),
      ),
    ];
  }

  String _describeRange(
    double? value, {
    required double min,
    required double max,
    required String low,
    required String high,
    required String ok,
  }) {
    if (value == null) {
      return 'Menunggu data sensor dari node ESP32.';
    }
    if (value < min) return low;
    if (value > max) return high;
    return ok;
  }

  Duration? _pumpRuntime(
    DeviceStatusData? status,
    PumpStatusData? pump,
  ) {
    final uptime = status?.uptimeMillis;
    final lastChange = pump?.lastChangeMillis;
    if (uptime == null || lastChange == null) {
      return null;
    }
    final diff = uptime - lastChange;
    if (diff < 0) {
      return null;
    }
    return Duration(milliseconds: diff);
  }

  String? _pumpRuntimeLabel(DeviceStatusData? status, PumpStatusData? pump) {
    final runtime = _pumpRuntime(status, pump);
    if (runtime == null) {
      return null;
    }
    final formatted = _formatDuration(runtime);
    if (pump?.isOn == true) {
      return 'Pompa aktif selama $formatted';
    }
    return 'Pompa berhenti $formatted lalu';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours >= 1) {
      final minutes = duration.inMinutes % 60;
      return '${duration.inHours} jam $minutes mnt';
    }
    if (duration.inMinutes >= 1) {
      final seconds = duration.inSeconds % 60;
      return '${duration.inMinutes} mnt $seconds dtk';
    }
    return '${duration.inSeconds} dtk';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} detik lalu';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays == 1) {
      return 'kemarin';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return 'lebih dari seminggu lalu';
    }
  }

  Object? _errorOrNull<T>(AsyncValue<T> value) {
    return value.maybeWhen(
      error: (error, _) => error,
      orElse: () => null,
    );
  }

  void _refreshRealtimeFeeds() {
    ref.invalidate(latestTelemetryProvider);
    ref.invalidate(deviceStatusProvider);
    ref.invalidate(pumpStatusProvider);
    ref.invalidate(controlModeProvider);
    _showSnackBar('Sinkronisasi data Firebase dimulai...');
  }

  Future<void> _handlePumpToggle(
    bool desiredState,
    ControlMode mode,
    DeviceStatusData? status,
  ) async {
    if (_isSendingPumpCommand) {
      return;
    }

    // Check if device is online before allowing pump toggle
    final isOnline = status?.isDeviceOnline ?? false;
    if (!isOnline) {
      _showSnackBar(
        'Tidak dapat mengontrol pompa. ${status?.connectionStatusLabel ?? "Perangkat offline"}.',
        isError: true,
      );
      return;
    }

    if (desiredState && mode != ControlMode.manual) {
      _showSnackBar(
        'Aktifkan mode manual terlebih dahulu sebelum menyalakan pompa.',
        isError: true,
      );
      return;
    }

    setState(() => _isSendingPumpCommand = true);
    try {
      await ref.read(dashboardRepositoryProvider).sendPumpCommand(
            turnOn: desiredState,
            durationSeconds: desiredState ? 60 : 0, // 60s for ON, 0 for OFF
          );
      _showSnackBar('Perintah pompa dikirim ke perangkat.');
    } catch (e) {
      _showSnackBar('Gagal mengirim perintah: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSendingPumpCommand = false);
      }
    }
  }

  Future<void> _setControlMode(ControlMode mode) async {
    if (_isUpdatingControlMode) {
      return;
    }
    setState(() => _isUpdatingControlMode = true);
    try {
      await ref.read(dashboardRepositoryProvider).setControlMode(mode);
      _showSnackBar('Mode kontrol diubah ke ${mode.label}.');
    } catch (e) {
      _showSnackBar('Gagal memperbarui mode: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUpdatingControlMode = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? theme.colorScheme.error : theme.colorScheme.primary,
      ),
    );
  }

}

class _DashboardAppBar extends ConsumerWidget {
  const _DashboardAppBar({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShowSelector = ref.watch(shouldShowGreenhouseSelectorProvider);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'StrawSmart Dashboard',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                          .onSurfaceVariant
                          .withAlpha((255 * 0.7).round()),
                        ),
                  ),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Notifikasi',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
            ],
          ),
          // Greenhouse selector - hanya tampil untuk admin/owner dengan >1 GH
          if (shouldShowSelector) ...[
            const SizedBox(height: 12),
            const GreenhouseSelector(),
          ] else ...[
            // Tampilkan nama greenhouse aktif untuk semua user
            const SizedBox(height: 8),
            const _SingleGreenhouseChip(),
          ],
        ],
      ),
    );
  }
}

/// Chip kecil untuk menampilkan greenhouse aktif
class _SingleGreenhouseChip extends ConsumerWidget {
  const _SingleGreenhouseChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedGreenhouseProvider);
    
    if (selected == null) return const SizedBox.shrink();
    
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 14,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            selected.displayName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final name = (userName == null || userName!.trim().isEmpty)
        ? 'Grower'
        : userName!.trim();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF59C173), Color(0xFF8A2387)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selamat datang kembali, $name!',
              style: theme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Integrasi Wokwi memastikan rumah kaca stroberi Anda terpantau 24/7.',
              style: theme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _HeroChip(icon: Icons.device_hub, label: '4 sensor aktif'),
                _HeroChip(icon: Icons.auto_awesome, label: 'AI rekomendasi siap'),
                _HeroChip(icon: Icons.shield_moon, label: 'Mode malam otomatis'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((255 * 0.2).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _SensorStatusCard extends StatelessWidget {
  const _SensorStatusCard({required this.sensor});

  final _SensorStatus sensor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              sensor.color.withAlpha((255 * 0.10).round()),
              sensor.color.withAlpha((255 * 0.03).round()),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon at top
            Icon(
              sensor.icon,
              color: sensor.color,
              size: 28,
            ),
            const SizedBox(height: 8),
            // Value in center (large)
            Text(
              sensor.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: sensor.color.darken(0.2),
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Label at bottom (small)
            Text(
              sensor.title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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

class _PumpStatusCard extends ConsumerWidget {
  const _PumpStatusCard({
    required this.status,
    required this.pump,
    required this.controlMode,
    required this.runtimeLabel,
    required this.isSendingPump,
    required this.isUpdatingMode,
    required this.onPumpToggle,
    required this.onModeChange,
    required this.onRefresh,
  });

  final DeviceStatusData? status;
  final PumpStatusData pump;
  final ControlMode controlMode;
  final String? runtimeLabel;
  final bool isSendingPump;
  final bool isUpdatingMode;
  final ValueChanged<bool> onPumpToggle;
  final ValueChanged<ControlMode> onModeChange;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final online = status?.isDeviceOnline ?? false;
    final connectionLabel = status?.connectionStatusLabel ?? 'Status tidak diketahui';
    final wifi = status?.wifiSignalStrength;
    final autoLogic = status?.autoLogicEnabled ?? false;
    
    // Get user role for permission check
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final canControlPump = profile?.role.canControlPump ?? false;
    final canTogglePump = !isSendingPump && online && canControlPump;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pompa air',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Owner hanya bisa lihat status, tidak bisa toggle
                if (canControlPump)
                  Switch.adaptive(
                    value: pump.isOn,
                    onChanged: canTogglePump ? onPumpToggle : null,
                  )
                else
                  // Status indicator untuk Owner (view only)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: pump.isOn 
                          ? Colors.green.withAlpha((255 * 0.15).round())
                          : Colors.grey.withAlpha((255 * 0.15).round()),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          pump.isOn ? Icons.power : Icons.power_off,
                          size: 16,
                          color: pump.isOn ? Colors.green[700] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          pump.isOn ? 'AKTIF' : 'MATI',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: pump.isOn ? Colors.green[700] : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              pump.isOn
                  ? 'Status: ON - Nutrisi sedang dialirkan ke bedengan.'
                  : 'Status: OFF - Pompa siap dijalankan otomatis.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            if (runtimeLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                runtimeLabel!,
                style: theme.textTheme.labelMedium,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Mode kontrol: ${controlMode.label} (${controlMode == ControlMode.auto ? 'fuzzy logic aktif' : 'manual override'})',
              style: theme.textTheme.bodyMedium,
            ),
            // Hanya tampilkan kontrol mode untuk user yang bisa kontrol pompa
            if (canControlPump) ...[
              const SizedBox(height: 16),
              SegmentedButton<ControlMode>(
                segments: const [
                  ButtonSegment(
                    value: ControlMode.auto,
                    icon: Icon(Icons.smart_toy_outlined),
                    label: Text('Auto'),
                  ),
                  ButtonSegment(
                    value: ControlMode.manual,
                    icon: Icon(Icons.touch_app_outlined),
                    label: Text('Manual'),
                  ),
                ],
                selected: {controlMode},
                onSelectionChanged: isUpdatingMode
                    ? null
                    : (selection) {
                        final target = selection.first;
                        if (target != controlMode) {
                          onModeChange(target);
                        }
                      },
              ),
            ] else ...[
              // Info box untuk Owner (view only)
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha((255 * 0.5).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mode monitoring - Anda hanya dapat melihat status pompa',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoPill(
                  icon: online ? Icons.check_circle : Icons.error_outline,
                  label: connectionLabel,
                  background:
                      (online ? Colors.green : Colors.red).withAlpha((255 * 0.12).round()),
                  foreground: online ? Colors.green[800]! : Colors.red[700]!,
                ),
                if (wifi != null)
                  _InfoPill(
                    icon: Icons.wifi_tethering,
                    label: '$wifi dBm WiFi',
                    background: colorScheme.primary.withAlpha((255 * 0.1).round()),
                    foreground: colorScheme.primary,
                  ),
                _InfoPill(
                  icon: Icons.auto_awesome,
                  label: autoLogic ? 'Fuzzy logic aktif' : 'Fuzzy logic off',
                  background: autoLogic
                      ? colorScheme.secondaryContainer.withAlpha((255 * 0.3).round())
                      : Colors.grey.withAlpha((255 * 0.15).round()),
                  foreground: autoLogic
                      ? colorScheme.secondary
                      : Colors.grey[700]!,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRefresh,
              icon: const Icon(Icons.sync),
              label: const Text('Sinkronkan dengan Wokwi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionMessageCard extends StatelessWidget {
  const _SectionMessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SensorStatus {
  _SensorStatus({
    required this.title,
    required this.module,
    required this.value,
    required this.status,
    required this.range,
    required this.icon,
    required this.color,
  });

  final String title;
  final String module;
  final String value;
  final String status;
  final String range;
  final IconData icon;
  final Color color;
}

extension on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark =
        hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
