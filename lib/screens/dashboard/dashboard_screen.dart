import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const stats = [
      _StatData(
        label: 'Active Fields',
        value: '12',
        trend: '+2.1%',
        icon: Icons.terrain_rounded,
        color: Color(0xFF6EC3FF),
      ),
      _StatData(
        label: 'Devices Online',
        value: '34',
        trend: '99%',
        icon: Icons.sensors_rounded,
        color: Color(0xFFFEB95F),
      ),
      _StatData(
        label: 'Alerts',
        value: '03',
        trend: 'New',
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFFF7D7D),
      ),
    ];

    const sensors = [
      _SensorReading(
        title: 'Soil Moisture',
        value: '68%',
        status: 'Optimal',
        icon: Icons.opacity_rounded,
      ),
      _SensorReading(
        title: 'Temperature',
        value: '27°C',
        status: 'Stabil',
        icon: Icons.thermostat_rounded,
      ),
      _SensorReading(
        title: 'Humidity',
        value: '54%',
        status: 'Aman',
        icon: Icons.water_drop_rounded,
      ),
    ];

    const activities = [
      _ActivityLog(
        label: 'Field “Sawah Utara” irrigation cycle selesai.',
        timeAgo: '8 menit lalu',
      ),
      _ActivityLog(
        label: 'Sensor kelembapan mengganti baterai.',
        timeAgo: '1 jam lalu',
      ),
      _ActivityLog(
        label: 'Monitor suhu menandai lonjakan siang.',
        timeAgo: 'Kemarin',
      ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        title: const Text('StrawSmart Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050505), Color(0xFF0F2027), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: _AccentCircle(
                color: colorScheme.primary.withOpacity(0.18),
              ),
            ),
            Positioned(
              bottom: -160,
              left: -20,
              child: _AccentCircle(
                color: colorScheme.secondary.withOpacity(0.16),
              ),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                children: [
                  Text(
                    'Selamat datang kembali 👋',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ringkasan kondisi terkini StrawSmart Farms',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          title: 'Statistik Utama',
                          subtitle: 'Pemantauan realtime hari ini',
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 18,
                          runSpacing: 18,
                          children: stats
                              .map((data) => _StatCard(data: data))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          title: 'Aksi Cepat',
                          subtitle: 'Kelola operasional lapangan',
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: const [
                            _QuickAction(
                              icon: Icons.water_drop_outlined,
                              label: 'Irigasi',
                            ),
                            _QuickAction(
                              icon: Icons.bar_chart_rounded,
                              label: 'Data Harian',
                            ),
                            _QuickAction(
                              icon: Icons.map_rounded,
                              label: 'Peta Lahan',
                            ),
                            _QuickAction(
                              icon: Icons.settings_remote_rounded,
                              label: 'Device',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          title: 'Sensor Snapshot',
                          subtitle: 'Status terpilih dari lahan aktif',
                        ),
                        const SizedBox(height: 12),
                        ...sensors.map(
                          (sensor) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: _SensorTile(sensor: sensor),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          title: 'Aktivitas Terakhir',
                          subtitle: 'Tugas dan notifikasi terbaru',
                        ),
                        const SizedBox(height: 12),
                        ...activities.map(
                          (log) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: _ActivityTile(log: log),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
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
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.35)),
            boxShadow: const [
              BoxShadow(
                blurRadius: 50,
                spreadRadius: -12,
                offset: Offset(0, 32),
                color: Color(0x33000000),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: data.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: data.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: data.color),
          const SizedBox(height: 16),
          Text(
            data.value,
            style: theme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: data.color.darken(),
            ),
          ),
          const SizedBox(height: 4),
          Text(data.label, style: theme.bodySmall),
          const SizedBox(height: 8),
          Text(
            data.trend,
            style: theme.labelSmall?.copyWith(color: data.color.darken()),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: () {},
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _SensorTile extends StatelessWidget {
  const _SensorTile({required this.sensor});

  final _SensorReading sensor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.grey[50],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[200],
            child: Icon(sensor.icon, color: Colors.grey[800]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sensor.title,
                  style: theme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sensor.status,
                  style: theme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            sensor.value,
            style: theme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.log});

  final _ActivityLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.bolt_rounded, color: Color(0xFF6EC3FF)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log.label, style: theme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                log.timeAgo,
                style: theme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccentCircle extends StatelessWidget {
  const _AccentCircle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0.02)]),
      ),
    );
  }
}

class _StatData {
  const _StatData({
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String trend;
  final IconData icon;
  final Color color;
}

class _SensorReading {
  const _SensorReading({
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
  });

  final String title;
  final String value;
  final String status;
  final IconData icon;
}

class _ActivityLog {
  const _ActivityLog({required this.label, required this.timeAgo});

  final String label;
  final String timeAgo;
}

extension on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0, 1));
    return hslDark.toColor();
  }
}
