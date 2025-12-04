import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../monitoring/monitoring_screen.dart';
import '../profile/profile_screen.dart';
import '../batch/batch_management_screen.dart';
import '../logs/logs_screen.dart';
import '../../core/widgets/app_shell.dart';
import '../../core/services/schedule_executor_service.dart';
import 'dashboard_repository.dart';
import 'widgets/dashboard_app_bar.dart';
import 'widgets/greenhouse_condition_card.dart';
import 'widgets/pump_control_card.dart';
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

    return AppShell(
      destinations: _destinations,
      selectedIndex: _selectedIndex,
      onIndexChanged: (index) => setState(() => _selectedIndex = index),
      floatingActionButton: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardAppBar(
            title: sectionTitle,
            isHomeTab: _selectedIndex == 0,
          ),
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

            // Section pompa (tanpa header)
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
    if (!isOnline) {
      // Tidak ada aksi - tombol tidak responsif saat offline
      return;
    }

    if (desiredState && mode != ControlMode.manual) {
      // Tidak ada aksi - tombol tidak responsif di mode otomatis
      return;
    }

    setState(() => _isSendingPumpCommand = true);
    try {
      await ref.read(dashboardRepositoryProvider).sendPumpCommand(
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

  Future<void> _setControlMode(ControlMode mode) async {
    if (_isUpdatingControlMode) return;

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

  // ---------------------------------------------------------------------------
  // Helper methods
  // ---------------------------------------------------------------------------
  Object? _errorOrNull<T>(AsyncValue<T> value) {
    return value.maybeWhen(
      error: (error, _) => error,
      orElse: () => null,
    );
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
