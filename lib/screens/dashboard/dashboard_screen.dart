import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../../core/widgets/app_shell.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;
  bool _pumpOn = true;

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
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final sectionTitle = _destinations[_selectedIndex].label;
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
            onLogout: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody(sectionTitle)),
        ],
      ),
    );
  }

  Widget _buildBody(String sectionTitle) {
    if (_selectedIndex != 0) {
      return Center(
        child: Text(
          '$sectionTitle akan tersedia segera.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeroHeader(),
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Sensor Wokwi real-time',
            subtitle:
                'Terhubung ke modul virtual untuk suhu, cahaya, kelembapan, dan tanah.',
          ),
          const SizedBox(height: 16),
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
                          : 1.2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: _sensorStatuses.length,
                itemBuilder: (context, index) {
                  final sensor = _sensorStatuses[index];
                  return _SensorStatusCard(sensor: sensor);
                },
              );
            },
          ),
          const SizedBox(height: 32),
          _SectionHeader(
            title: 'Kontrol lingkungan',
            subtitle: 'Pantau pompa nutrisi & insight budidaya StrawSmart.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final pumpCard = _PumpStatusCard(
                pumpOn: _pumpOn,
                onChanged: (value) => setState(() => _pumpOn = value),
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
                          .withOpacity(0.45),
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
}

class _DashboardAppBar extends StatelessWidget {
  const _DashboardAppBar({
    required this.title,
    required this.onLogout,
  });

  final String title;
  final VoidCallback onLogout;

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
                          .withOpacity(0.7),
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
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
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
              'Selamat datang kembali, Grower!',
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
        color: Colors.white.withOpacity(0.2),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              sensor.color.withOpacity(0.12),
              sensor.color.withOpacity(0.04),
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
  const _PumpStatusCard({required this.pumpOn, required this.onChanged});

  final bool pumpOn;
  final ValueChanged<bool> onChanged;

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
                Icon(
                  Icons.water_drop_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pompa nutrisi',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: pumpOn,
                  onChanged: onChanged,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              pumpOn
                  ? 'Status: ON - Nutrisi sedang dialirkan ke bedengan.'
                  : 'Status: OFF - Pompa siap dijalankan otomatis.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Jadwal berikutnya - 14:30 WIB',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () {},
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

class _SensorStatus {
  const _SensorStatus({
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

const List<_SensorStatus> _sensorStatuses = [
  _SensorStatus(
    title: 'Suhu',
    module: 'Wokwi DHT22',
    value: '26.4 deg C',
    status: 'Stabil - Target siang 27 deg C',
    range: '24-28 deg C',
    icon: Icons.thermostat,
    color: Color(0xFFFFB74D),
  ),
  _SensorStatus(
    title: 'Cahaya',
    module: 'Wokwi LDR',
    value: '18.700 lux',
    status: 'Grow light aktif 80%',
    range: '15-20k lux',
    icon: Icons.light_mode,
    color: Color(0xFFFFF176),
  ),
  _SensorStatus(
    title: 'Kelembapan udara',
    module: 'Wokwi DHT22',
    value: '62%',
    status: 'Fogger standby',
    range: '55-70%',
    icon: Icons.water_drop,
    color: Color(0xFF4FC3F7),
  ),
  _SensorStatus(
    title: 'Kelembapan tanah',
    module: 'Wokwi Soil',
    value: '41%',
    status: 'Drip system siap dijalankan',
    range: '35-45%',
    icon: Icons.grass,
    color: Color(0xFF81C784),
  ),
];

extension on Color {
  Color darken([double amount = .1]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark =
        hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
