import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/user_profile_repository.dart';
import '../monitoring/monitoring_screen.dart';
import '../profile/profile_screen.dart';
import '../logs/logs_screen.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/widgets/schedule_status_card.dart';
import '../../services/schedule_executor_service.dart';
import 'dashboard_repository.dart';

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
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics),
      label: 'Monitoring',
    ),
    NavigationDestination(
      icon: Icon(Icons.document_scanner_outlined),
      selectedIcon: Icon(Icons.document_scanner),
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
            onRefresh: _selectedIndex == 0 ? _refreshRealtimeFeeds : null,
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
    // Tab Pengaturan (index 3)
    if (_selectedIndex == 3) {
      return const ProfileScreen();
    }

    // Tab Monitoring (index 1)
    if (_selectedIndex == 1) {
      return const MonitoringScreen();
    }

    // Tab Laporan (index 2)
    if (_selectedIndex == 2) {
      return const LaporanScreen();
    }

    // Tab Beranda (index 0)
    final profileAsync = ref.watch(currentUserProfileProvider);
    final displayName = profileAsync.when<String?>(
      data: (profile) => profile?.name,
      loading: () => null,
      error: (_, __) => null,
    );

    return SingleChildScrollView(
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
          const ScheduleStatusCard(), // Kartu jadwal otomatis dengan kontrol
          const SizedBox(height: 32),
          _SectionHeader(
            title: 'Kontrol lingkungan',
            subtitle: 'Pantau pompa nutrisi & insight budidaya StrawSmart.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final pumpCard = _buildPumpCard(
                statusAsync,
                pumpAsync,
                controlModeAsync,
              );
              const tipsCard = _CultivationTipsCard();
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: pumpCard),
                    const SizedBox(width: 16),
                    Expanded(child: tipsCard),
                  ],
                );
              }
              return Column(
                children: [
                  pumpCard,
                  const SizedBox(height: 16),
                  tipsCard,
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'Grafik aktivitas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withAlpha((255 * 0.45).round()),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Placeholder Chart\nIntegrasikan package chart pilihan Anda di sini.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
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
            final columns = width >= 1100
                ? 4
                : width >= 800
                    ? 3
                    : width >= 520
                  ? 2
                  : 1;
            final aspectRatio = width >= 1100
              ? 2.2
              : width >= 800
                ? 1.6
                : width >= 520
                  ? 1.35
                  : _mobileSensorCardAspectRatio(width);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: aspectRatio,
              ),
              itemCount: sensors.length,
              itemBuilder: (context, index) {
                final sensor = sensors[index];
                return _SensorStatusCard(
                  sensor: sensor,
                  compact: columns == 1,
                );
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
            durationSeconds: desiredState ? 30 : 0,
          );
      final suffix = status?.online == true
          ? ''
          : ' (node offline - perintah akan dijalankan saat online)';
      _showSnackBar('Perintah pompa dikirim$suffix');
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

  double _mobileSensorCardAspectRatio(double availableWidth) {
    if (availableWidth <= 0) {
      return 1.2;
    }
    final double targetHeight = availableWidth < 360 ? 210 : 190;
    final ratio = availableWidth / targetHeight;
    final num clampedRatio = ratio.clamp(1.2, 2.1);
    return clampedRatio.toDouble();
  }
}

class _DashboardAppBar extends StatelessWidget {
  const _DashboardAppBar({
    required this.title,
    this.onRefresh,
  });

  final String title;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
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
          if (onRefresh != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Refresh Data',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRefresh,
            ),
          ],
        ],
      ),
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
  const _SensorStatusCard({
    required this.sensor,
    this.compact = false,
  });

  final _SensorStatus sensor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              sensor.color.withAlpha((255 * 0.12).round()),
              sensor.color.withAlpha((255 * 0.04).round()),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(sensor.icon, color: sensor.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sensor.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    sensor.module,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: sensor.color.darken(),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              sensor.value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              sensor.status,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[700]),
            ),
            if (compact)
              const SizedBox(height: 12)
            else
              const Spacer(),
            Text(
              'Rentang ideal: ${sensor.range}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PumpStatusCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final online = status?.online ?? false;
    final wifi = status?.wifiSignalStrength;
    final autoLogic = status?.autoLogicEnabled ?? false;
    final canTogglePump = !isSendingPump;

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
                  'Pompa nutrisi',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: pump.isOn,
                  onChanged: canTogglePump ? onPumpToggle : null,
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoPill(
                  icon: online ? Icons.check_circle : Icons.error_outline,
                  label: online ? 'Perangkat online' : 'Perangkat offline',
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

class _CultivationTipsCard extends StatelessWidget {
  const _CultivationTipsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.spa, color: Colors.pink[400]),
                const SizedBox(width: 8),
                Text(
                  'Insight budidaya stroberi',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TipTile(
              icon: Icons.sunny,
              title: 'Cahaya 12 jam',
              message: 'Pastikan grow light menyala minimal 12 jam/hari.',
            ),
            const SizedBox(height: 10),
            _TipTile(
              icon: Icons.thermostat,
              title: 'Jaga suhu 24-28 deg C',
              message: 'Aktifkan kipas otomatis jika suhu di atas 28 deg C.',
            ),
            const SizedBox(height: 10),
            _TipTile(
              icon: Icons.water_drop,
              title: 'Kelembapan 60%',
              message: 'Gunakan fogger Wokwi jika kelembapan turun drastis.',
            ),
          ],
        ),
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  const _TipTile({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
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
