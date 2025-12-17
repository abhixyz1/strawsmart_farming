import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../monitoring/monitoring_screen.dart';
import '../profile/profile_screen.dart';
import '../batch/batch_management_screen.dart';
import '../logs/logs_screen.dart';
import '../greenhouse/greenhouse_repository.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/services/schedule_executor_service.dart';
import '../../core/services/anomaly_detection_service.dart';
import '../batch/batch_repository.dart';
import 'dashboard_repository.dart';
import 'widgets/dashboard_app_bar.dart';
import 'widgets/greenhouse_condition_card.dart';
import 'widgets/pump_control_card.dart';
import 'widgets/schedule_info_card.dart';
import 'widgets/common_widgets.dart';
import 'widgets/strawberry_guidance_section.dart';

// ============================================================================
// DASHBOARD SCREEN - Layar utama aplikasi StrawSmart
// ============================================================================

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isSendingPumpCommand = false;
  bool _isUpdatingControlMode = false;

  // Rate limiting for mode switching
  DateTime? _lastModeChangeTime;
  int _modeChangeCount = 0;
  static const _modeChangeThreshold = 3; // Max changes allowed
  static const _modeChangeCooldown = Duration(seconds: 10); // Reset window

  // Rate limiting for pump toggle
  DateTime? _lastPumpToggleTime;
  int _pumpToggleCount = 0;
  static const _pumpToggleThreshold = 5; // Max toggles allowed
  static const _pumpToggleCooldown = Duration(seconds: 15); // Reset window

  // Throttling untuk anomaly detection agar tidak check terlalu sering
  DateTime? _lastAnomalyCheck;
  static const _anomalyCheckInterval = Duration(
    seconds: 30,
  ); // Check setiap 30 detik (sesuai sensor update)

  // ---------------------------------------------------------------------------
  // Konstanta navigasi
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Build utama
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final latestAsync = ref.watch(latestTelemetryProvider);
    final statusAsync = ref.watch(deviceStatusProvider);
    final pumpAsync = ref.watch(pumpStatusProvider);
    final controlModeAsync = ref.watch(controlModeProvider);
    final sectionTitle = _destinations[_selectedIndex].label;

    // Aktivasi schedule executor service
    ref.watch(scheduleExecutorServiceProvider);

    // Monitor anomali sensor dan trigger notifikasi
    _monitorSensorAnomalies(latestAsync, statusAsync);

    return AppShell(
      destinations: _destinations,
      selectedIndex: _selectedIndex,
      onIndexChanged: (index) => setState(() => _selectedIndex = index),
      floatingActionButton: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardAppBar(title: sectionTitle, isHomeTab: _selectedIndex == 0),
          // Divider hanya untuk tab selain home (home sudah ada background)
          if (_selectedIndex != 0) const Divider(height: 1),
          Expanded(
            child: _buildBody(
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

  // ---------------------------------------------------------------------------
  // Body berdasarkan tab yang dipilih
  // ---------------------------------------------------------------------------
  Widget _buildBody(
    AsyncValue<SensorSnapshot?> latestAsync,
    AsyncValue<DeviceStatusData?> statusAsync,
    AsyncValue<PumpStatusData?> pumpAsync,
    AsyncValue<ControlMode> controlModeAsync,
  ) {
    switch (_selectedIndex) {
      case 1:
        return const MonitoringScreen();
      case 2:
        return const BatchManagementScreen();
      case 3:
        return const LaporanScreen();
      case 4:
        return const ProfileScreen();
      default:
        return _buildHomeTab(
          latestAsync,
          statusAsync,
          pumpAsync,
          controlModeAsync,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Tab Beranda
  // ---------------------------------------------------------------------------
  Widget _buildHomeTab(
    AsyncValue<SensorSnapshot?> latestAsync,
    AsyncValue<DeviceStatusData?> statusAsync,
    AsyncValue<PumpStatusData?> pumpAsync,
    AsyncValue<ControlMode> controlModeAsync,
  ) {
    // Cek apakah user punya akses ke greenhouse
    final available = ref.watch(availableGreenhousesProvider).valueOrNull ?? [];
    final selected = ref.watch(selectedGreenhouseProvider);

    // Jika user tidak punya akses sama sekali, tampilkan empty state
    if (available.isEmpty) {
      return RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.eco_outlined,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withAlpha((255 * 0.3).round()),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Belum Ada Akses Greenhouse',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hubungi admin untuk mendapatkan akses\nke greenhouse',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Jika user punya akses tapi belum ada greenhouse yang dipilih
    if (selected == null) {
      return RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_searching,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withAlpha((255 * 0.5).round()),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Memuat Greenhouse...',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mohon tunggu sebentar',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // User sudah punya akses dan sudah memilih greenhouse - tampilkan data normal
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kartu kondisi greenhouse (suhu besar + sensor tiles menyatu)
            _buildConditionSection(latestAsync),
            const SizedBox(height: 24),

            // Insight budidaya stroberi
            const StrawberryGuidanceSection(),
            const SizedBox(height: 24),

            // Section jadwal penyiraman (dibawah guidance)
            const ScheduleInfoCard(),
            const SizedBox(height: 24),

            // Section pompa control
            _buildPumpSection(statusAsync, pumpAsync, controlModeAsync),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section kondisi (suhu besar + sensor tiles menyatu)
  // ---------------------------------------------------------------------------
  Widget _buildConditionSection(AsyncValue<SensorSnapshot?> latestAsync) {
    final data = latestAsync.valueOrNull;

    // Kartu kondisi greenhouse dengan data sensor
    return GreenhouseConditionCard(snapshot: data);
  }

  // ---------------------------------------------------------------------------
  // Section pompa
  // ---------------------------------------------------------------------------
  Widget _buildPumpSection(
    AsyncValue<DeviceStatusData?> statusAsync,
    AsyncValue<PumpStatusData?> pumpAsync,
    AsyncValue<ControlMode> controlModeAsync,
  ) {
    final status = statusAsync.valueOrNull;
    final pump = pumpAsync.valueOrNull;
    final controlMode = controlModeAsync.valueOrNull ?? ControlMode.auto;
    final pumpError = _errorOrNull(pumpAsync) ?? _errorOrNull(statusAsync);

    // Error tanpa cached data
    if (pumpError != null && pump == null) {
      return SectionMessageCard(
        icon: Icons.error_outline,
        message: 'Gagal memuat status pompa: $pumpError',
      );
    }

    // Loading pertama kali
    if (pump == null && pumpAsync.isLoading && !pumpAsync.hasValue) {
      return const SectionMessageCard(
        icon: Icons.water_drop_outlined,
        message: 'Menunggu status pompa dari perangkat...',
      );
    }

    // Tidak ada data
    if (pump == null) {
      return const SectionMessageCard(
        icon: Icons.sensors,
        message: 'Menunggu perangkat melaporkan status pompa.',
      );
    }

    return PumpControlCard(
      status: status,
      pump: pump,
      controlMode: controlMode,
      runtimeLabel: _pumpRuntimeLabel(status, pump),
      isSendingPump: _isSendingPumpCommand,
      isUpdatingMode: _isUpdatingControlMode,
      onPumpToggle: (value) => _handlePumpToggle(value, controlMode, status),
      onModeChange: _setControlMode,
      onRefresh: _refreshRealtimeFeeds,
    );
  }

  // ---------------------------------------------------------------------------
  // Anomaly Detection Monitoring
  // ---------------------------------------------------------------------------
  void _monitorSensorAnomalies(
    AsyncValue<SensorSnapshot?> latestAsync,
    AsyncValue<DeviceStatusData?> statusAsync,
  ) {
    // Throttling: hanya check setiap 5 menit
    final now = DateTime.now();
    if (_lastAnomalyCheck != null) {
      final timeSinceLastCheck = now.difference(_lastAnomalyCheck!);
      if (timeSinceLastCheck < _anomalyCheckInterval) {
        return; // Skip check jika belum 5 menit
      }
    }

    // Only monitor when data is available
    if (latestAsync.valueOrNull == null || statusAsync.valueOrNull == null) {
      return;
    }

    // Update last check time
    _lastAnomalyCheck = now;

    final sensorData = latestAsync.value!;
    final status = statusAsync.value!;
    final deviceId = ref.read(dashboardDeviceIdProvider);
    final deviceName = 'Greenhouse $deviceId';
    final activeBatch = ref.read(activeBatchProvider).valueOrNull;

    // Get anomaly detection service
    final anomalyService = ref.read(anomalyDetectionServiceProvider);

    // Check sensor readings untuk anomali
    Future.microtask(() async {
      await anomalyService.checkSensorReadings(
        deviceId: deviceId,
        deviceName: deviceName,
        temperature: sensorData.temperature,
        humidity: sensorData.humidity,
        soilMoisture: sensorData.soilMoisturePercent,
        soilPh: null, // pH sensor not yet implemented
        currentPhase: activeBatch?.currentPhase,
        phaseRequirements: activeBatch?.currentRequirements,
      );

      // Check device online status
      await anomalyService.checkDeviceStatus(
        deviceId: deviceId,
        deviceName: deviceName,
        isOnline: status.online,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Event handlers
  // ---------------------------------------------------------------------------
  Future<void> _onRefresh() async {
    ref.invalidate(latestTelemetryProvider);
    ref.invalidate(deviceStatusProvider);
    ref.invalidate(pumpStatusProvider);
    ref.invalidate(controlModeProvider);

    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _refreshRealtimeFeeds() {
    ref.invalidate(latestTelemetryProvider);
    ref.invalidate(deviceStatusProvider);
    ref.invalidate(pumpStatusProvider);
    ref.invalidate(controlModeProvider);
    // Refresh tanpa notifikasi
  }

  Future<void> _handlePumpToggle(
    bool desiredState,
    ControlMode mode,
    DeviceStatusData? status,
  ) async {
    if (_isSendingPumpCommand) return;

    final isOnline = status?.isDeviceOnline ?? false;

    // Alert jika device offline
    if (!isOnline) {
      _showOfflineAlert();
      return;
    }

    // Alert jika mode auto dan mencoba menyalakan pompa
    if (desiredState && mode != ControlMode.manual) {
      _showAutoModeAlert();
      return;
    }

    // Rate limiting untuk pump toggle
    final now = DateTime.now();
    if (_lastPumpToggleTime != null) {
      final elapsed = now.difference(_lastPumpToggleTime!);
      if (elapsed < _pumpToggleCooldown) {
        _pumpToggleCount++;
        if (_pumpToggleCount >= _pumpToggleThreshold) {
          _showPumpRateLimitAlert();
          return;
        }
      } else {
        // Reset counter after cooldown
        _pumpToggleCount = 1;
      }
    } else {
      _pumpToggleCount = 1;
    }
    _lastPumpToggleTime = now;

    setState(() => _isSendingPumpCommand = true);
    try {
      await ref
          .read(dashboardRepositoryProvider)
          .sendPumpCommand(
            turnOn: desiredState,
            durationSeconds: desiredState ? 60 : 0,
          );
      // Sukses tanpa notifikasi
    } catch (e) {
      // Gagal tanpa notifikasi
    } finally {
      if (mounted) setState(() => _isSendingPumpCommand = false);
    }
  }

  void _showOfflineAlert() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350).withAlpha((255 * 0.1).round()),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: Color(0xFFEF5350),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Perangkat Offline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Tidak dapat mengontrol pompa karena\nperangkat tidak terhubung.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF5350),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Mengerti'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAutoModeAlert() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF9575CD).withAlpha((255 * 0.1).round()),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_mode_rounded,
                size: 40,
                color: Color(0xFF9575CD),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Mode Otomatis Aktif',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Pompa dikontrol oleh sistem Fuzzy.\nGanti ke mode Manual untuk kontrol manual.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9575CD),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Mengerti'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPumpRateLimitAlert() {
    if (!mounted) return;

    final remainingSeconds = _lastPumpToggleTime != null
        ? (_pumpToggleCooldown.inSeconds -
                  DateTime.now().difference(_lastPumpToggleTime!).inSeconds)
              .clamp(0, _pumpToggleCooldown.inSeconds)
        : _pumpToggleCooldown.inSeconds;

    showDialog(
      context: context,
      builder: (context) => _PumpRateLimitDialog(
        initialSeconds: remainingSeconds,
        onComplete: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _setControlMode(ControlMode mode) async {
    if (_isUpdatingControlMode) return;

    // Rate limiting check
    final now = DateTime.now();
    if (_lastModeChangeTime != null) {
      final elapsed = now.difference(_lastModeChangeTime!);
      if (elapsed < _modeChangeCooldown) {
        _modeChangeCount++;
        if (_modeChangeCount >= _modeChangeThreshold) {
          _showRateLimitAlert();
          return;
        }
      } else {
        // Reset counter after cooldown
        _modeChangeCount = 1;
      }
    } else {
      _modeChangeCount = 1;
    }
    _lastModeChangeTime = now;

    setState(() => _isUpdatingControlMode = true);
    try {
      await ref.read(dashboardRepositoryProvider).setControlMode(mode);
      // Sukses tanpa notifikasi
    } catch (e) {
      // Gagal tanpa notifikasi
    } finally {
      if (mounted) setState(() => _isUpdatingControlMode = false);
    }
  }

  void _showRateLimitAlert() {
    if (!mounted) return;

    // Calculate remaining cooldown time
    final remainingSeconds = _lastModeChangeTime != null
        ? (_modeChangeCooldown.inSeconds -
                  DateTime.now().difference(_lastModeChangeTime!).inSeconds)
              .clamp(0, _modeChangeCooldown.inSeconds)
        : _modeChangeCooldown.inSeconds;

    showDialog(
      context: context,
      builder: (context) => _RateLimitDialog(
        initialSeconds: remainingSeconds,
        onComplete: () => Navigator.pop(context),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper methods
  // ---------------------------------------------------------------------------
  Object? _errorOrNull<T>(AsyncValue<T> value) {
    return value.maybeWhen(error: (error, _) => error, orElse: () => null);
  }

  String? _pumpRuntimeLabel(DeviceStatusData? status, PumpStatusData? pump) {
    final runtime = _pumpRuntime(status, pump);
    if (runtime == null) return null;

    final formatted = _formatDuration(runtime);
    if (pump?.isOn == true) {
      return 'Pompa aktif selama $formatted';
    }
    return 'Pompa berhenti $formatted lalu';
  }

  Duration? _pumpRuntime(DeviceStatusData? status, PumpStatusData? pump) {
    final uptime = status?.uptimeMillis;
    final lastChange = pump?.lastChangeMillis;
    if (uptime == null || lastChange == null) return null;

    final diff = uptime - lastChange;
    if (diff < 0) return null;
    return Duration(milliseconds: diff);
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
}

// =============================================================================
// Rate Limit Dialog with Countdown Timer
// =============================================================================

class _RateLimitDialog extends StatefulWidget {
  const _RateLimitDialog({
    required this.initialSeconds,
    required this.onComplete,
  });

  final int initialSeconds;
  final VoidCallback onComplete;

  @override
  State<_RateLimitDialog> createState() => _RateLimitDialogState();
}

class _RateLimitDialogState extends State<_RateLimitDialog> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _remainingSeconds <= 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Animated timer circle
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: isComplete
                      ? 1.0
                      : _remainingSeconds / widget.initialSeconds,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.withAlpha((255 * 0.2).round()),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete
                        ? const Color(0xFF66BB6A)
                        : const Color(0xFFFFB74D),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isComplete ? Icons.check_rounded : Icons.timer_rounded,
                    size: 28,
                    color: isComplete
                        ? const Color(0xFF66BB6A)
                        : const Color(0xFFFFB74D),
                  ),
                  if (!isComplete) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$_remainingSeconds',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFB74D),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Title
          Text(
            isComplete ? 'Siap!' : 'Terlalu Cepat!',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          // Message
          Text(
            isComplete
                ? 'Anda dapat mengubah mode kembali.'
                : 'Tunggu $_remainingSeconds detik sebelum\nmengubah mode lagi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 20),
          // Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onComplete,
              style: FilledButton.styleFrom(
                backgroundColor: isComplete
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFFFFB74D),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isComplete ? 'Lanjutkan' : 'Mengerti'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Pump Rate Limit Dialog - Dialog untuk rate limit toggle pompa
// ============================================================================

class _PumpRateLimitDialog extends StatefulWidget {
  const _PumpRateLimitDialog({
    required this.initialSeconds,
    required this.onComplete,
  });

  final int initialSeconds;
  final VoidCallback onComplete;

  @override
  State<_PumpRateLimitDialog> createState() => _PumpRateLimitDialogState();
}

class _PumpRateLimitDialogState extends State<_PumpRateLimitDialog> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _remainingSeconds <= 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          // Animated timer circle with water drop icon
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: isComplete
                      ? 1.0
                      : _remainingSeconds / widget.initialSeconds,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey.withAlpha((255 * 0.2).round()),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete
                        ? const Color(0xFF66BB6A)
                        : const Color(0xFF42A5F5),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isComplete ? Icons.check_rounded : Icons.water_drop_rounded,
                    size: 28,
                    color: isComplete
                        ? const Color(0xFF66BB6A)
                        : const Color(0xFF42A5F5),
                  ),
                  if (!isComplete) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$_remainingSeconds',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF42A5F5),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Title
          Text(
            isComplete ? 'Siap!' : 'Pompa Perlu Istirahat',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          // Message
          Text(
            isComplete
                ? 'Anda dapat mengontrol pompa kembali.'
                : 'Terlalu sering toggle pompa.\nTunggu $_remainingSeconds detik.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 20),
          // Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onComplete,
              style: FilledButton.styleFrom(
                backgroundColor: isComplete
                    ? const Color(0xFF66BB6A)
                    : const Color(0xFF42A5F5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isComplete ? 'Lanjutkan' : 'Mengerti'),
            ),
          ),
        ],
      ),
    );
  }
}
