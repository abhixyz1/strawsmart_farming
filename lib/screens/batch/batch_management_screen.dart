import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../core/utils/page_transitions.dart';
import '../../core/widgets/timeline_indicator.dart';
import '../../models/cultivation_batch.dart';
import '../../models/user_role.dart';
import '../auth/user_profile_repository.dart';
import '../greenhouse/greenhouse_repository.dart';
import 'batch_repository.dart';
import 'batch_detail_screen.dart';
import 'create_batch_screen.dart';

/// Screen utama untuk manajemen batch tanam
class BatchManagementScreen extends ConsumerWidget {
  const BatchManagementScreen({
    super.key,
    this.showAppBar = false,
  });

  /// Jika true, tampilkan AppBar (untuk navigasi standalone)
  /// Jika false, hanya body (untuk di dalam tab)
  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greenhouse = ref.watch(selectedGreenhouseProvider);
    final activeBatchAsync = ref.watch(activeBatchProvider);
    final allBatchesAsync = ref.watch(allBatchesProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    
    // Get user role for permission check
    final userRole = profileAsync.valueOrNull?.role ?? UserRole.petani;

    if (greenhouse == null) {
      if (showAppBar) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Manajemen Batch'),
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
          ),
          body: _buildNoGreenhouse(context),
        );
      }
      return _buildNoGreenhouse(context);
    }

    final body = RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activeBatchProvider);
        ref.invalidate(allBatchesProvider);
      },
      child: CustomScrollView(
        slivers: [
          // Active Batch Card (langsung tanpa header)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: activeBatchAsync.when(
                data: (batch) => batch != null
                    ? _ActiveBatchCard(batch: batch)
                    : _NoBatchCard(
                        greenhouseId: greenhouse.greenhouseId,
                        canCreate: userRole.canManageBatch,
                      ),
                loading: () => const _LoadingCard(),
                error: (e, _) => _ErrorCard(error: e.toString()),
              ),
            ),
          ),

          // Timeline section header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Riwayat Batch',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Batch history list
          allBatchesAsync.when(
            data: (batches) {
              if (batches.isEmpty) {
                return const SliverToBoxAdapter(
                  child: _EmptyHistory(),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final batch = batches[index];
                    return _BatchHistoryTile(
                      batch: batch,
                      isFirst: index == 0,
                      isLast: index == batches.length - 1,
                    );
                  },
                  childCount: batches.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: _ErrorCard(error: e.toString()),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );

    if (showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manajemen Batch'),
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(activeBatchProvider);
                ref.invalidate(allBatchesProvider);
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: body,
      );
    }

    return body;
  }

  Widget _buildNoGreenhouse(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.agriculture, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Pilih greenhouse terlebih dahulu',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

/// Card untuk batch aktif dengan progress dan fase
class _ActiveBatchCard extends StatelessWidget {
  const _ActiveBatchCard({required this.batch});

  final CultivationBatch batch;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    final phase = batch.currentPhase;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Color(phase.colorValue),
            Color(phase.colorValue).withAlpha(180),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(phase.colorValue).withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.pushFadeSlide(
            BatchDetailScreen(batchId: batch.id),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        phase.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(50),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'AKTIF',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            batch.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Phase info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fase Saat Ini',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              phase.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white24,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hari ke',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${batch.daysSincePlanting}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progress Keseluruhan',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${(batch.progressPercent * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearPercentIndicator(
                      padding: EdgeInsets.zero,
                      lineHeight: 8,
                      percent: batch.progressPercent,
                      backgroundColor: Colors.white24,
                      progressColor: Colors.white,
                      barRadius: const Radius.circular(4),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Phase timeline mini
                _PhaseTimelineMini(
                  currentPhase: phase,
                  phaseProgress: batch.currentPhaseProgress,
                ),

                const SizedBox(height: 16),

                // Info row
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.calendar_today,
                      label: 'Tanam: ${dateFormat.format(batch.plantingDate)}',
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.timer,
                      label: '${batch.daysUntilHarvest} hari lagi',
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
}

/// Mini timeline untuk menampilkan fase
class _PhaseTimelineMini extends StatelessWidget {
  const _PhaseTimelineMini({
    required this.currentPhase,
    required this.phaseProgress,
  });

  final GrowthPhase currentPhase;
  final double phaseProgress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: GrowthPhase.values.map((phase) {
        final isCompleted = phase.index < currentPhase.index;
        final isCurrent = phase == currentPhase;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted || isCurrent
                      ? Colors.white
                      : Colors.white24,
                  border: isCurrent
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.green)
                      : Text(
                          phase.emoji,
                          style: TextStyle(
                            fontSize: 12,
                            color: isCurrent ? null : Colors.white54,
                          ),
                        ),
                ),
              ),
              if (phase != GrowthPhase.harvesting)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted ? Colors.white : Colors.white24,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Chip info kecil
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card jika tidak ada batch aktif
class _NoBatchCard extends ConsumerWidget {
  const _NoBatchCard({
    required this.greenhouseId,
    required this.canCreate,
  });

  final String greenhouseId;
  final bool canCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(50),
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Text('🌱', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Batch Aktif',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mulai periode tanam baru untuk tracking pertumbuhan stroberi',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          if (canCreate)
            FilledButton.icon(
              onPressed: () => context.pushScale(
                CreateBatchScreen(greenhouseId: greenhouseId),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Mulai Batch Baru'),
            )
          else
            Text(
              'Hubungi admin untuk memulai batch baru',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
            ),
        ],
      ),
    );
  }
}

/// Tile untuk riwayat batch dengan timeline
class _BatchHistoryTile extends StatelessWidget {
  const _BatchHistoryTile({
    required this.batch,
    required this.isFirst,
    required this.isLast,
  });

  final CultivationBatch batch;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    final isActive = batch.isActive;

    final theme = Theme.of(context);
    final Color indicatorColor = isActive
        ? theme.colorScheme.primary
        : Colors.grey[300]!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VerticalTimelineIndicator(
            isFirst: isFirst,
            isLast: isLast,
            indicatorSize: 30,
            horizontalPadding: 8,
            beforeLineColor: indicatorColor,
            afterLineColor: Colors.grey[300]!,
            indicator: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? theme.colorScheme.primary
                    : Colors.grey[200],
              ),
              child: Center(
                child: Text(
                  batch.currentPhase.emoji,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.pushFadeSlide(
                  BatchDetailScreen(batchId: batch.id),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? theme.colorScheme.primary.withAlpha(100)
                          : Colors.grey[200]!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              batch.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'AKTIF',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.eco,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            batch.varietyDisplayName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.grass,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${batch.plantCount} tanaman',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(batch.plantingDate),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          if (batch.totalHarvestKg != null) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.inventory_2,
                              size: 14,
                              color: Colors.green[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${batch.totalHarvestKg!.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 12),
                        LinearPercentIndicator(
                          padding: EdgeInsets.zero,
                          lineHeight: 6,
                          percent: batch.progressPercent,
                          backgroundColor: Colors.grey[200],
                          progressColor: Color(batch.currentPhase.colorValue),
                          barRadius: const Radius.circular(3),
                        ),
                      ],
                    ],
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

/// Loading card
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Error card
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty history placeholder
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada riwayat batch',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
