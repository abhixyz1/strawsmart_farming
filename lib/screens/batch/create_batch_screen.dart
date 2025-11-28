import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/cultivation_batch.dart';
import 'batch_repository.dart';

/// Screen untuk membuat batch tanam baru
class CreateBatchScreen extends ConsumerStatefulWidget {
  const CreateBatchScreen({super.key, required this.greenhouseId});

  final String greenhouseId;

  @override
  ConsumerState<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends ConsumerState<CreateBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _plantCountController = TextEditingController();
  final _notesController = TextEditingController();
  final _customVarietyController = TextEditingController();

  StrawberryVariety _selectedVariety = StrawberryVariety.california;
  DateTime _plantingDate = DateTime.now();
  bool _isLoading = false;
  bool _showAdvanced = false;

  // Phase duration overrides (in days)
  final Map<GrowthPhase, int> _phaseDurations = {};

  @override
  void initState() {
    super.initState();
    // Initialize with defaults
    for (final phase in GrowthPhase.values) {
      _phaseDurations[phase] = CultivationBatch.defaultPhaseDuration(phase);
    }
    // Generate default name
    final now = DateTime.now();
    final monthYear = DateFormat('MMMM yyyy', 'id_ID').format(now);
    _nameController.text = 'Batch $monthYear';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plantCountController.dispose();
    _notesController.dispose();
    _customVarietyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Baru'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header card
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('🌱', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mulai Periode Tanam Baru',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tracking pertumbuhan stroberi dari awal sampai panen',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Basic info section
            Text(
              'Informasi Dasar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Batch',
                hintText: 'Contoh: Batch November 2025',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama batch harus diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Variety
            DropdownButtonFormField<StrawberryVariety>(
              value: _selectedVariety,
              decoration: const InputDecoration(
                labelText: 'Varietas Stroberi',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.eco),
              ),
              items: StrawberryVariety.values.map((variety) {
                return DropdownMenuItem(
                  value: variety,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(variety.label),
                      Text(
                        variety.description,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedVariety = value!);
              },
            ),

            // Custom variety name
            if (_selectedVariety == StrawberryVariety.other) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _customVarietyController,
                decoration: const InputDecoration(
                  labelText: 'Nama Varietas',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
                validator: (value) {
                  if (_selectedVariety == StrawberryVariety.other &&
                      (value == null || value.isEmpty)) {
                    return 'Nama varietas harus diisi';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),

            // Planting date
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal Tanam',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateFormat.format(_plantingDate)),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Plant count
            TextFormField(
              controller: _plantCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah Tanaman',
                hintText: 'Contoh: 100',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.grass),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Jumlah tanaman harus diisi';
                }
                final count = int.tryParse(value);
                if (count == null || count <= 0) {
                  return 'Masukkan angka yang valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Tambahkan catatan tentang batch ini...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // Advanced settings toggle
            InkWell(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      _showAdvanced
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pengaturan Lanjutan',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Advanced settings
            if (_showAdvanced) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Durasi Fase (hari)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sesuaikan durasi setiap fase pertumbuhan',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 16),
                      ...GrowthPhase.values.map((phase) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(phase.colorValue).withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  phase.emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  phase.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  initialValue: _phaseDurations[phase].toString(),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    border: const OutlineInputBorder(),
                                    suffixText: 'hr',
                                    suffixStyle: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  onChanged: (value) {
                                    final days = int.tryParse(value);
                                    if (days != null && days > 0) {
                                      _phaseDurations[phase] = days;
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),

            // Summary card
            _buildSummaryCard(context),
            const SizedBox(height: 24),

            // Submit button
            FilledButton.icon(
              onPressed: _isLoading ? null : _createBatch,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(_isLoading ? 'Menyimpan...' : 'Mulai Batch'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final totalDays = _phaseDurations.values.reduce((a, b) => a + b);
    final estimatedHarvest = _plantingDate.add(Duration(days: totalDays));
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Ringkasan',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                ),
              ],
            ),
            const Divider(),
            _SummaryRow(
              label: 'Total Durasi',
              value: '$totalDays hari',
            ),
            _SummaryRow(
              label: 'Estimasi Panen',
              value: dateFormat.format(estimatedHarvest),
            ),
            _SummaryRow(
              label: 'Varietas',
              value: _selectedVariety.label,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantingDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _plantingDate = picked);
    }
  }

  Future<void> _createBatch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Build phase settings
      final phaseSettings = <GrowthPhase, PhaseSettings>{};
      for (final phase in GrowthPhase.values) {
        phaseSettings[phase] = PhaseSettings(
          durationDays: _phaseDurations[phase]!,
          requirements: PhaseRequirements.defaultFor(phase),
        );
      }

      final batch = CultivationBatch(
        id: '', // Will be set by Firestore
        greenhouseId: widget.greenhouseId,
        name: _nameController.text,
        variety: _selectedVariety,
        customVarietyName: _selectedVariety == StrawberryVariety.other
            ? _customVarietyController.text
            : null,
        plantingDate: _plantingDate,
        plantCount: int.parse(_plantCountController.text),
        phaseSettings: phaseSettings,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        isActive: true,
      );

      await ref.read(batchRepositoryProvider).createBatch(batch);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch berhasil dibuat! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[700]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
