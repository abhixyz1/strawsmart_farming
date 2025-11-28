import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../core/widgets/timeline_indicator.dart';
import '../../models/cultivation_batch.dart';
import '../../models/batch_daily_stats.dart';
import '../../services/photo_upload_service.dart';
import 'batch_repository.dart';
import 'daily_stats_repository.dart';

/// Screen detail batch dengan info lengkap, timeline fase, dan jurnal
class BatchDetailScreen extends ConsumerStatefulWidget {
  const BatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  ConsumerState<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends ConsumerState<BatchDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batchAsync = ref.watch(batchByIdProvider(widget.batchId));
    final journalAsync = ref.watch(batchJournalProvider(widget.batchId));

    return batchAsync.when(
      data: (batch) {
        if (batch == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Batch tidak ditemukan')),
            body: const Center(child: Text('Data batch tidak tersedia')),
          );
        }

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _buildSliverAppBar(context, batch),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    tabBar: TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(icon: Icon(Icons.timeline), text: 'Fase'),
                        Tab(icon: Icon(Icons.menu_book), text: 'Jurnal'),
                        Tab(icon: Icon(Icons.eco), text: 'Nutrisi'),
                        Tab(icon: Icon(Icons.history), text: 'Timeline'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _PhaseTimelineTab(batch: batch),
                _JournalTab(
                  batch: batch,
                  journalAsync: journalAsync,
                  onAddEntry: () => _showAddJournalDialog(batch),
                ),
                _NutrientTab(batch: batch),
                _TimelineTab(
                  batch: batch,
                  batchId: widget.batchId,
                  journalAsync: journalAsync,
                ),
              ],
            ),
          ),
          floatingActionButton: batch.isActive
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddJournalDialog(batch),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Jurnal'),
                )
              : null,
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddJournalDialog(CultivationBatch batch) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    JournalEntryType selectedType = JournalEntryType.note;
    double? harvestKg;
    List<XFile> selectedPhotos = [];
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tambah Jurnal',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<JournalEntryType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipe Jurnal',
                    border: OutlineInputBorder(),
                  ),
                  items: JournalEntryType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Text(type.emoji),
                          const SizedBox(width: 8),
                          Text(type.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setModalState(() => selectedType = value!);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (selectedType == JournalEntryType.harvest) ...[
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Hasil Panen (kg)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => harvestKg = double.tryParse(v),
                  ),
                ],
                const SizedBox(height: 16),
                // Photo Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.photo_camera, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Foto Progress (Opsional)',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Photo preview
                      if (selectedPhotos.isNotEmpty) ...[
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: selectedPhotos.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: FutureBuilder<dynamic>(
                                        future: selectedPhotos[index].readAsBytes(),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return Container(
                                              width: 80,
                                              height: 80,
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              ),
                                            );
                                          }
                                          return Image.memory(
                                            snapshot.data!,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            selectedPhotos.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Photo buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: const Text('Galeri'),
                              onPressed: selectedPhotos.length >= 5
                                  ? null
                                  : () async {
                                      final photoService = ref.read(photoUploadServiceProvider);
                                      final images = await photoService.pickMultipleImages(
                                        maxImages: 5 - selectedPhotos.length,
                                      );
                                      if (images.isNotEmpty) {
                                        setModalState(() {
                                          selectedPhotos.addAll(images);
                                        });
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: const Text('Kamera'),
                              onPressed: selectedPhotos.length >= 5
                                  ? null
                                  : () async {
                                      final photoService = ref.read(photoUploadServiceProvider);
                                      final image = await photoService.pickImage(
                                        source: ImageSource.camera,
                                      );
                                      if (image != null) {
                                        setModalState(() {
                                          selectedPhotos.add(image);
                                        });
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      if (selectedPhotos.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${selectedPhotos.length}/5 foto dipilih',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          setModalState(() => isUploading = true);
                          
                          try {
                            // Create journal entry first to get ID
                            final tempId = DateTime.now().millisecondsSinceEpoch.toString();
                            List<String> photoUrls = [];
                            
                            // Upload photos if any
                            if (selectedPhotos.isNotEmpty) {
                              final photoService = ref.read(photoUploadServiceProvider);
                              photoUrls = await photoService.uploadMultiplePhotos(
                                batchId: batch.id,
                                journalId: tempId,
                                imageFiles: selectedPhotos,
                              );
                            }
                            
                            final entry = BatchJournalEntry(
                              id: '',
                              batchId: batch.id,
                              date: DateTime.now(),
                              type: selectedType,
                              title: titleController.text.isEmpty
                                  ? null
                                  : titleController.text,
                              description: descController.text.isEmpty
                                  ? null
                                  : descController.text,
                              photoUrls: photoUrls,
                              harvestKg: harvestKg,
                            );
                            
                            await ref
                                .read(batchRepositoryProvider)
                                .addJournalEntry(entry);
                            
                            if (mounted) Navigator.pop(context);
                          } catch (e) {
                            setModalState(() => isUploading = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                  child: isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(selectedPhotos.isNotEmpty
                          ? 'Simpan dengan ${selectedPhotos.length} Foto'
                          : 'Simpan'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, CultivationBatch batch) {
    final phase = batch.currentPhase;
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Color(phase.colorValue),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(phase.colorValue),
                Color(phase.colorValue).withAlpha(180),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          phase.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (batch.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                margin: const EdgeInsets.only(bottom: 4),
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
                            Text(
                              batch.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              batch.varietyDisplayName,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress
                  Row(
                    children: [
                      CircularPercentIndicator(
                        radius: 36,
                        lineWidth: 6,
                        percent: batch.progressPercent,
                        backgroundColor: Colors.white24,
                        progressColor: Colors.white,
                        center: Text(
                          '${(batch.progressPercent * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fase: ${phase.label}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hari ke-${batch.daysSincePlanting} • ${batch.daysUntilHarvest} hari lagi',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        Icons.calendar_today,
                        'Tanam: ${dateFormat.format(batch.plantingDate)}',
                      ),
                      _buildInfoChip(
                        Icons.grass,
                        '${batch.plantCount} tanaman',
                      ),
                      if (batch.totalHarvestKg != null)
                        _buildInfoChip(
                          Icons.inventory_2,
                          'Panen: ${batch.totalHarvestKg!.toStringAsFixed(1)} kg',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) => _handleMenuAction(value, batch),
          itemBuilder: (context) => [
            if (batch.isActive)
              const PopupMenuItem(
                value: 'complete',
                child: ListTile(
                  leading: Icon(Icons.check_circle),
                  title: Text('Selesaikan Batch'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            const PopupMenuItem(
              value: 'export',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Export Data'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Hapus Batch', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
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
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, CultivationBatch batch) async {
    switch (action) {
      case 'complete':
        _showCompleteDialog(batch);
        break;
      case 'export':
        // TODO: Implement export
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export akan segera tersedia')),
        );
        break;
      case 'delete':
        _showDeleteDialog(batch);
        break;
    }
  }

  void _showCompleteDialog(CultivationBatch batch) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selesaikan Batch?'),
        content: const Text(
          'Batch akan ditandai selesai dan tidak bisa diubah lagi. '
          'Anda bisa mulai batch baru setelah ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(batchRepositoryProvider).completeBatch(batch.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Batch berhasil diselesaikan')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Selesaikan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(CultivationBatch batch) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Batch?'),
        content: Text(
          'Batch "${batch.name}" akan dihapus permanen beserta semua data jurnal. '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(batchRepositoryProvider).deleteBatch(batch.id);
                if (mounted) {
                  Navigator.pop(context); // Back to list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Batch berhasil dihapus')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

/// Delegate untuk TabBar sticky
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate({required this.tabBar});

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

/// Tab Timeline Fase
class _PhaseTimelineTab extends StatelessWidget {
  const _PhaseTimelineTab({required this.batch});

  final CultivationBatch batch;

  @override
  Widget build(BuildContext context) {
    final currentPhase = batch.currentPhase;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Phase summary card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fase Pertumbuhan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentPhase.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Timeline
        ...GrowthPhase.values.map((phase) {
          final settings = batch.phaseSettings[phase];
          final requirements = PhaseRequirements.defaultFor(phase);
          final isCompleted = phase.index < currentPhase.index;
          final isCurrent = phase == currentPhase;
          final isPending = phase.index > currentPhase.index;

          return _PhaseCard(
            phase: phase,
            durationDays: settings?.durationDays ?? CultivationBatch.defaultPhaseDuration(phase),
            requirements: requirements,
            isCompleted: isCompleted,
            isCurrent: isCurrent,
            isPending: isPending,
            progress: isCurrent ? batch.currentPhaseProgress : null,
          );
        }),
      ],
    );
  }
}

/// Card untuk setiap fase
class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.phase,
    required this.durationDays,
    required this.requirements,
    required this.isCompleted,
    required this.isCurrent,
    required this.isPending,
    this.progress,
  });

  final GrowthPhase phase;
  final int durationDays;
  final PhaseRequirements requirements;
  final bool isCompleted;
  final bool isCurrent;
  final bool isPending;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final daysText = '$durationDays hari';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? Color(phase.colorValue)
                      : isCompleted
                          ? Colors.green
                          : Colors.grey[300],
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: Color(phase.colorValue).withAlpha(100),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : Text(
                          phase.emoji,
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
              if (phase != GrowthPhase.harvesting)
                Container(
                  width: 2,
                  height: 100,
                  color: isCompleted ? Colors.green : Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Phase content
          Expanded(
            child: Card(
              color: isCurrent
                  ? Color(phase.colorValue).withAlpha(25)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            phase.label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isPending ? Colors.grey : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Color(phase.colorValue)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            daysText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isCurrent ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Progress for current phase
                    if (isCurrent && progress != null) ...[
                      LinearPercentIndicator(
                        padding: EdgeInsets.zero,
                        lineHeight: 6,
                        percent: progress!,
                        backgroundColor: Colors.grey[200],
                        progressColor: Color(phase.colorValue),
                        barRadius: const Radius.circular(3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Progress: ${(progress! * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(phase.colorValue),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Requirements summary
                    Text(
                      phase.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isPending ? Colors.grey : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Environment requirements
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _RequirementChip(
                          icon: Icons.thermostat,
                          label: '${requirements.minTemp.toInt()}-${requirements.maxTemp.toInt()}°C',
                          isPending: isPending,
                        ),
                        _RequirementChip(
                          icon: Icons.water_drop,
                          label: '${requirements.minHumidity.toInt()}-${requirements.maxHumidity.toInt()}%',
                          isPending: isPending,
                        ),
                        _RequirementChip(
                          icon: Icons.grass,
                          label: '${requirements.minSoilMoisture.toInt()}-${requirements.maxSoilMoisture.toInt()}%',
                          isPending: isPending,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementChip extends StatelessWidget {
  const _RequirementChip({
    required this.icon,
    required this.label,
    required this.isPending,
  });

  final IconData icon;
  final String label;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPending ? Colors.grey[100] : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isPending ? Colors.grey : Colors.blue[700],
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isPending ? Colors.grey : Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab Jurnal
class _JournalTab extends StatelessWidget {
  const _JournalTab({
    required this.batch,
    required this.journalAsync,
    required this.onAddEntry,
  });

  final CultivationBatch batch;
  final AsyncValue<List<BatchJournalEntry>> journalAsync;
  final VoidCallback onAddEntry;

  @override
  Widget build(BuildContext context) {
    return journalAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Belum ada catatan',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tambahkan jurnal untuk tracking aktivitas',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),
                if (batch.isActive)
                  FilledButton.icon(
                    onPressed: onAddEntry,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Catatan'),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _JournalEntryCard(entry: entry);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

/// Tampilkan foto dalam dialog fullscreen
void _showPhotoViewer(BuildContext context, List<String> photoUrls, int initialIndex) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => _PhotoViewerScreen(
        photoUrls: photoUrls,
        initialIndex: initialIndex,
      ),
    ),
  );
}

/// Card untuk jurnal entry
class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({required this.entry});

  final BatchJournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final entryType = entry.type;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(entryType.colorValue).withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(entryType.emoji, style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entryType.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        dateFormat.format(entry.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (entry.title != null) ...[
              const SizedBox(height: 12),
              Text(
                entry.title!,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
            if (entry.description != null) ...[
              const SizedBox(height: 8),
              Text(
                entry.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
            // Data khusus berdasarkan tipe
            if (entry.fertilizerUsed != null) ...[
              const SizedBox(height: 8),
              _DataRow(
                icon: Icons.science,
                label: 'Pupuk',
                value: entry.fertilizerUsed!.name,
              ),
              const SizedBox(height: 4),
              _DataRow(
                icon: Icons.scale,
                label: 'Dosis',
                value: entry.fertilizerUsed!.dosage,
              ),
            ],
            if (entry.harvestKg != null) ...[
              const SizedBox(height: 8),
              _DataRow(
                icon: Icons.inventory_2,
                label: 'Hasil Panen',
                value: '${entry.harvestKg} kg',
                valueColor: Colors.green,
              ),
            ],
            if (entry.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: entry.photoUrls.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _showPhotoViewer(context, entry.photoUrls, index),
                      child: Container(
                        width: 80,
                        height: 80,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(entry.photoUrls[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: entry.photoUrls.length > 1 && index == 0
                            ? Align(
                                alignment: Alignment.bottomRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '+${entry.photoUrls.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Tab Nutrisi & Pupuk
class _NutrientTab extends StatelessWidget {
  const _NutrientTab({required this.batch});

  final CultivationBatch batch;

  @override
  Widget build(BuildContext context) {
    final currentPhase = batch.currentPhase;
    final requirements = PhaseRequirements.defaultFor(currentPhase);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current phase recommendation
        Card(
          color: Color(currentPhase.colorValue).withAlpha(25),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      currentPhase.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Rekomendasi ${currentPhase.label}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Environment requirements
                _RequirementSection(
                  title: 'Kondisi Lingkungan',
                  items: [
                    _ReqItem(
                      Icons.thermostat,
                      'Suhu',
                      '${requirements.minTemp.toInt()}-${requirements.maxTemp.toInt()}°C',
                    ),
                    _ReqItem(
                      Icons.water_drop,
                      'Kelembaban',
                      '${requirements.minHumidity.toInt()}-${requirements.maxHumidity.toInt()}%',
                    ),
                    _ReqItem(
                      Icons.grass,
                      'Kelembaban Tanah',
                      '${requirements.minSoilMoisture.toInt()}-${requirements.maxSoilMoisture.toInt()}%',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Watering
                _RequirementSection(
                  title: 'Penyiraman',
                  items: [
                    _ReqItem(
                      Icons.schedule,
                      'Frekuensi',
                      '${requirements.wateringPerDay}x/hari',
                    ),
                    _ReqItem(
                      Icons.water,
                      'Durasi',
                      '${requirements.wateringDurationSec} detik',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Fertilizer recommendations
        Text(
          'Rekomendasi Pupuk per Fase',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        ...GrowthPhase.values.map((phase) {
          final req = PhaseRequirements.defaultFor(phase);
          final isCurrent = phase == currentPhase;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isCurrent ? Color(phase.colorValue).withAlpha(15) : null,
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(phase.colorValue).withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(phase.emoji, style: const TextStyle(fontSize: 16)),
              ),
              title: Row(
                children: [
                  Text(
                    phase.label,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Color(phase.colorValue),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SEKARANG',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                req.fertilizers.isNotEmpty
                    ? req.fertilizers.first.name
                    : 'Tidak ada rekomendasi',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              children: req.fertilizers.map((fert) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _FertilizerCard(fertilizer: fert),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }
}

class _RequirementSection extends StatelessWidget {
  const _RequirementSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_ReqItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(item.icon, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    '${item.label}: ',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _ReqItem {
  final IconData icon;
  final String label;
  final String value;

  _ReqItem(this.icon, this.label, this.value);
}

class _FertilizerCard extends StatelessWidget {
  const _FertilizerCard({required this.fertilizer});

  final FertilizerRecommendation fertilizer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fertilizer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (fertilizer.notes != null) ...[
            Text(
              fertilizer.notes!,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              _FertChip(Icons.scale, fertilizer.dosage),
              const SizedBox(width: 8),
              _FertChip(Icons.repeat, fertilizer.frequency),
            ],
          ),
        ],
      ),
    );
  }
}

class _FertChip extends StatelessWidget {
  const _FertChip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.green[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.green[700]),
          ),
        ],
      ),
    );
  }
}

/// Tab Timeline - Menampilkan timeline kronologis aktivitas batch
class _TimelineTab extends ConsumerWidget {
  const _TimelineTab({
    required this.batch,
    required this.batchId,
    required this.journalAsync,
  });

  final CultivationBatch batch;
  final String batchId;
  final AsyncValue<List<BatchJournalEntry>> journalAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyStatsAsync = ref.watch(batchDailyStatsProvider(batchId));

    return journalAsync.when(
      data: (entries) {
        // Build timeline items from various sources
        final timelineItems = <_TimelineItem>[];

        // Add planting date as first item
        timelineItems.add(_TimelineItem(
          date: batch.plantingDate,
          type: _TimelineItemType.milestone,
          title: 'Mulai Penanaman',
          subtitle: batch.variety.label,
          icon: Icons.nature_people,
          color: Colors.green,
        ));

        // Add phase transitions
        batch.phaseTransitions.forEach((phase, date) {
          timelineItems.add(_TimelineItem(
            date: date,
            type: _TimelineItemType.phaseChange,
            title: 'Fase ${phase.label}',
            subtitle: 'Transisi fase pertumbuhan',
            icon: Icons.trending_up,
            color: Color(phase.colorValue),
          ));
        });

        // Add journal entries
        for (final entry in entries) {
          timelineItems.add(_TimelineItem(
            date: entry.date,
            type: _TimelineItemType.journal,
            title: entry.title ?? entry.type.label,
            subtitle: entry.description,
            icon: entry.type.icon,
            color: entry.type.color,
            extra: entry.type == JournalEntryType.harvest
                ? 'Panen: ${entry.harvestKg?.toStringAsFixed(1)} kg'
                : null,
          ));
        }

        // Sort by date descending (newest first)
        timelineItems.sort((a, b) => b.date.compareTo(a.date));

        if (timelineItems.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timeline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Belum ada aktivitas'),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            // Daily Stats Summary (last 7 days)
            SliverToBoxAdapter(
              child: dailyStatsAsync.when(
                data: (stats) {
                  if (stats.isEmpty) return const SizedBox.shrink();
                  // Take last 7 days only
                  final weekStats = stats.take(7).toList();
                  return _WeeklyStatsCard(stats: weekStats);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            // Timeline
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = timelineItems[index];
                    final isFirst = index == 0;
                    final isLast = index == timelineItems.length - 1;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VerticalTimelineIndicator(
                            isFirst: isFirst,
                            isLast: isLast,
                            indicatorSize: 32,
                            horizontalPadding: 8,
                            beforeLineColor: Colors.grey[300],
                            afterLineColor: Colors.grey[300],
                            indicator: Container(
                              decoration: BoxDecoration(
                                color: item.color.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(color: item.color, width: 2),
                              ),
                              child: Icon(item.icon, size: 16, color: item.color),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                              child: _TimelineCard(item: item),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: timelineItems.length,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

enum _TimelineItemType { milestone, phaseChange, journal }

class _TimelineItem {
  final DateTime date;
  final _TimelineItemType type;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final String? extra;

  _TimelineItem({
    required this.date,
    required this.type,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.extra,
  });
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.item});

  final _TimelineItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  DateFormat('d MMM').format(item.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (item.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                item.subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (item.extra != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.extra!,
                  style: TextStyle(
                    fontSize: 12,
                    color: item.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeeklyStatsCard extends StatelessWidget {
  const _WeeklyStatsCard({required this.stats});

  final List<BatchDailyStats> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    // Calculate averages with null safety
    final tempValues = stats.where((s) => s.avgTemperature != null).map((s) => s.avgTemperature!).toList();
    final humidityValues = stats.where((s) => s.avgHumidity != null).map((s) => s.avgHumidity!).toList();
    final soilValues = stats.where((s) => s.avgSoilMoisture != null).map((s) => s.avgSoilMoisture!).toList();
    
    final avgTemp = tempValues.isNotEmpty ? tempValues.reduce((a, b) => a + b) / tempValues.length : 0.0;
    final avgHumidity = humidityValues.isNotEmpty ? humidityValues.reduce((a, b) => a + b) / humidityValues.length : 0.0;
    final avgSoil = soilValues.isNotEmpty ? soilValues.reduce((a, b) => a + b) / soilValues.length : 0.0;
    final totalAlerts = stats.expand((s) => s.alerts).length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Ringkasan 7 Hari Terakhir',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                if (totalAlerts > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning, size: 14, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text(
                          '$totalAlerts Peringatan',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatItem(
                  icon: Icons.thermostat,
                  label: 'Suhu Rata²',
                  value: '${avgTemp.toStringAsFixed(1)}°C',
                  color: Colors.orange,
                ),
                _StatItem(
                  icon: Icons.water_drop,
                  label: 'Kelembaban',
                  value: '${avgHumidity.toStringAsFixed(0)}%',
                  color: Colors.blue,
                ),
                _StatItem(
                  icon: Icons.grass,
                  label: 'Tanah',
                  value: '${avgSoil.toStringAsFixed(0)}%',
                  color: Colors.brown,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen untuk melihat foto dalam fullscreen
class _PhotoViewerScreen extends StatefulWidget {
  const _PhotoViewerScreen({
    required this.photoUrls,
    required this.initialIndex,
  });

  final List<String> photoUrls;
  final int initialIndex;

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          'Foto ${_currentIndex + 1} dari ${widget.photoUrls.length}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photoUrls.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                widget.photoUrls[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.white, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Gagal memuat foto',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: widget.photoUrls.length > 1
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.photoUrls.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == index
                            ? Colors.white
                            : Colors.white38,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
