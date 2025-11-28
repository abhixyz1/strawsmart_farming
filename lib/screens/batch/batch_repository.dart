import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cultivation_batch.dart';
import '../greenhouse/greenhouse_repository.dart';

/// Repository provider untuk batch tanam
final batchRepositoryProvider = Provider<BatchRepository>((ref) {
  return BatchRepository(FirebaseFirestore.instance);
});

/// Provider untuk batch aktif di greenhouse yang dipilih
final activeBatchProvider = StreamProvider<CultivationBatch?>((ref) {
  final greenhouse = ref.watch(selectedGreenhouseProvider);
  if (greenhouse == null) return Stream.value(null);
  
  return ref.watch(batchRepositoryProvider)
      .watchActiveBatch(greenhouse.greenhouseId);
});

/// Provider untuk semua batch di greenhouse yang dipilih
final allBatchesProvider = StreamProvider<List<CultivationBatch>>((ref) {
  final greenhouse = ref.watch(selectedGreenhouseProvider);
  if (greenhouse == null) return Stream.value([]);
  
  return ref.watch(batchRepositoryProvider)
      .watchAllBatches(greenhouse.greenhouseId);
});

/// Provider untuk batch tertentu berdasarkan ID
final batchByIdProvider = StreamProvider.family<CultivationBatch?, String>((ref, batchId) {
  return ref.watch(batchRepositoryProvider).watchBatch(batchId);
});

/// Provider untuk jurnal entries batch tertentu
final batchJournalProvider = StreamProvider.family<List<BatchJournalEntry>, String>((ref, batchId) {
  return ref.watch(batchRepositoryProvider).watchJournalEntries(batchId);
});

/// Provider untuk menghitung statistik batch
final batchStatsProvider = Provider.family<BatchStats, CultivationBatch>((ref, batch) {
  return BatchStats.fromBatch(batch);
});

/// Repository untuk CRUD operasi batch tanam
class BatchRepository {
  BatchRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _batchesCollection =>
      _firestore.collection('cultivationBatches');

  CollectionReference<Map<String, dynamic>> _journalCollection(String batchId) =>
      _batchesCollection.doc(batchId).collection('journal');

  /// Watch batch aktif untuk greenhouse tertentu
  Stream<CultivationBatch?> watchActiveBatch(String greenhouseId) {
    return _batchesCollection
        .where('greenhouseId', isEqualTo: greenhouseId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return CultivationBatch.fromFirestore(doc.id, doc.data());
    });
  }

  /// Watch semua batch untuk greenhouse (active + history)
  /// 
  /// Note: Menggunakan client-side sorting untuk menghindari kebutuhan 
  /// composite index Firestore yang kadang lambat ter-deploy.
  Stream<List<CultivationBatch>> watchAllBatches(String greenhouseId) {
    return _batchesCollection
        .where('greenhouseId', isEqualTo: greenhouseId)
        .snapshots()
        .map((snapshot) {
      final batches = snapshot.docs
          .map((doc) => CultivationBatch.fromFirestore(doc.id, doc.data()))
          .toList();
      // Client-side sort by plantingDate descending
      batches.sort((a, b) => b.plantingDate.compareTo(a.plantingDate));
      return batches;
    });
  }

  /// Watch batch tertentu
  Stream<CultivationBatch?> watchBatch(String batchId) {
    return _batchesCollection.doc(batchId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return CultivationBatch.fromFirestore(snapshot.id, snapshot.data()!);
    });
  }

  /// Buat batch baru
  Future<String> createBatch(CultivationBatch batch) async {
    // Nonaktifkan batch lama di greenhouse yang sama
    await _deactivateExistingBatches(batch.greenhouseId);

    final docRef = await _batchesCollection.add(batch.toFirestoreCreate());
    return docRef.id;
  }

  /// Update batch
  Future<void> updateBatch(CultivationBatch batch) async {
    await _batchesCollection.doc(batch.id).update(batch.toFirestore());
  }

  /// ============ PHASE TRANSITION (HYBRID) ============

  /// Pindah ke fase berikutnya secara manual
  Future<void> transitionToNextPhase(String batchId) async {
    final doc = await _batchesCollection.doc(batchId).get();
    if (!doc.exists) return;

    final batch = CultivationBatch.fromFirestore(doc.id, doc.data()!);
    final currentPhase = batch.currentPhase;
    
    // Cari fase berikutnya
    final currentIndex = GrowthPhase.values.indexOf(currentPhase);
    if (currentIndex >= GrowthPhase.values.length - 1) return; // Sudah di fase terakhir
    
    final nextPhase = GrowthPhase.values[currentIndex + 1];
    
    // Update phase transitions dengan tanggal sekarang
    final newTransitions = Map<GrowthPhase, DateTime>.from(batch.phaseTransitions);
    newTransitions[nextPhase] = DateTime.now();

    await _batchesCollection.doc(batchId).update({
      'phaseTransitions': newTransitions.map(
        (k, v) => MapEntry(k.name, Timestamp.fromDate(v)),
      ),
      'currentPhaseOverride': nextPhase.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Otomatis tambah journal entry untuk milestone
    await addJournalEntry(BatchJournalEntry(
      id: '',
      batchId: batchId,
      date: DateTime.now(),
      type: JournalEntryType.milestone,
      title: 'Masuk Fase ${nextPhase.label}',
      description: 'Tanaman dipindahkan ke fase ${nextPhase.label} secara manual',
    ));
  }

  /// Set fase secara manual (override)
  Future<void> setPhaseManually(String batchId, GrowthPhase phase) async {
    final doc = await _batchesCollection.doc(batchId).get();
    if (!doc.exists) return;

    final batch = CultivationBatch.fromFirestore(doc.id, doc.data()!);
    
    // Update phase transitions
    final newTransitions = Map<GrowthPhase, DateTime>.from(batch.phaseTransitions);
    newTransitions[phase] = DateTime.now();

    await _batchesCollection.doc(batchId).update({
      'phaseTransitions': newTransitions.map(
        (k, v) => MapEntry(k.name, Timestamp.fromDate(v)),
      ),
      'currentPhaseOverride': phase.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Otomatis tambah journal entry
    await addJournalEntry(BatchJournalEntry(
      id: '',
      batchId: batchId,
      date: DateTime.now(),
      type: JournalEntryType.milestone,
      title: 'Fase diubah ke ${phase.label}',
      description: 'Fase diatur secara manual ke ${phase.label}',
    ));
  }

  /// Reset ke mode otomatis (hapus override)
  Future<void> resetToAutomaticPhase(String batchId) async {
    await _batchesCollection.doc(batchId).update({
      'currentPhaseOverride': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Tandai batch selesai (harvest complete)
  Future<void> completeBatch(String batchId, {
    DateTime? harvestDate,
    double? totalHarvestKg,
  }) async {
    await _batchesCollection.doc(batchId).update({
      'isActive': false,
      'harvestDate': harvestDate != null 
          ? Timestamp.fromDate(harvestDate) 
          : FieldValue.serverTimestamp(),
      'totalHarvestKg': totalHarvestKg,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Hapus batch
  Future<void> deleteBatch(String batchId) async {
    // Hapus jurnal entries dulu
    final journalDocs = await _journalCollection(batchId).get();
    for (final doc in journalDocs.docs) {
      await doc.reference.delete();
    }
    // Hapus batch
    await _batchesCollection.doc(batchId).delete();
  }

  /// Nonaktifkan batch yang ada di greenhouse
  Future<void> _deactivateExistingBatches(String greenhouseId) async {
    final existing = await _batchesCollection
        .where('greenhouseId', isEqualTo: greenhouseId)
        .where('isActive', isEqualTo: true)
        .get();

    for (final doc in existing.docs) {
      await doc.reference.update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ============ JOURNAL OPERATIONS ============

  /// Watch jurnal entries untuk batch
  Stream<List<BatchJournalEntry>> watchJournalEntries(String batchId) {
    return _journalCollection(batchId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BatchJournalEntry.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Tambah jurnal entry
  Future<String> addJournalEntry(BatchJournalEntry entry) async {
    final docRef = await _journalCollection(entry.batchId)
        .add(entry.toFirestore());
    
    // Update total harvest jika entry adalah harvest
    if (entry.type == JournalEntryType.harvest && entry.harvestKg != null) {
      await _updateTotalHarvest(entry.batchId, entry.harvestKg!);
    }
    
    return docRef.id;
  }

  /// Update jurnal entry
  Future<void> updateJournalEntry(String batchId, BatchJournalEntry entry) async {
    await _journalCollection(batchId).doc(entry.id).update(entry.toFirestore());
  }

  /// Hapus jurnal entry
  Future<void> deleteJournalEntry(String batchId, String entryId) async {
    await _journalCollection(batchId).doc(entryId).delete();
  }

  /// Update total harvest pada batch
  Future<void> _updateTotalHarvest(String batchId, double harvestKg) async {
    await _firestore.runTransaction((transaction) async {
      final batchDoc = await transaction.get(_batchesCollection.doc(batchId));
      if (!batchDoc.exists) return;
      
      final currentTotal = (batchDoc.data()?['totalHarvestKg'] as num?)?.toDouble() ?? 0.0;
      transaction.update(batchDoc.reference, {
        'totalHarvestKg': currentTotal + harvestKg,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Get batch statistics
  Future<Map<String, dynamic>> getBatchStatistics(String greenhouseId) async {
    final batches = await _batchesCollection
        .where('greenhouseId', isEqualTo: greenhouseId)
        .get();

    double totalHarvest = 0;
    int totalBatches = batches.docs.length;
    int completedBatches = 0;

    for (final doc in batches.docs) {
      final data = doc.data();
      totalHarvest += (data['totalHarvestKg'] as num?)?.toDouble() ?? 0;
      if (data['isActive'] == false && data['harvestDate'] != null) {
        completedBatches++;
      }
    }

    return {
      'totalBatches': totalBatches,
      'completedBatches': completedBatches,
      'activeBatches': totalBatches - completedBatches,
      'totalHarvestKg': totalHarvest,
    };
  }
}

/// Helper class untuk statistik batch
class BatchStats {
  const BatchStats({
    required this.daysInCurrentPhase,
    required this.daysUntilNextPhase,
    required this.daysUntilHarvest,
    required this.overallProgress,
    required this.phaseProgress,
    required this.isOnTrack,
    this.healthStatus,
  });

  final int daysInCurrentPhase;
  final int daysUntilNextPhase;
  final int daysUntilHarvest;
  final double overallProgress;
  final double phaseProgress;
  final bool isOnTrack;
  final String? healthStatus;

  factory BatchStats.fromBatch(CultivationBatch batch) {
    final currentPhaseSettings = batch.phaseSettings[batch.currentPhase];
    final phaseDuration = currentPhaseSettings?.durationDays ?? 14;
    
    int daysInPhase = 0;
    int cumulativeDays = 0;
    
    for (final phase in GrowthPhase.values) {
      if (phase == batch.currentPhase) {
        daysInPhase = batch.daysSincePlanting - cumulativeDays;
        break;
      }
      cumulativeDays += batch.phaseSettings[phase]?.durationDays ?? 
                        CultivationBatch.defaultPhaseDuration(phase);
    }

    final daysUntilNextPhase = phaseDuration - daysInPhase;
    
    return BatchStats(
      daysInCurrentPhase: daysInPhase,
      daysUntilNextPhase: daysUntilNextPhase < 0 ? 0 : daysUntilNextPhase,
      daysUntilHarvest: batch.daysUntilHarvest,
      overallProgress: batch.progressPercent,
      phaseProgress: batch.currentPhaseProgress,
      isOnTrack: daysInPhase <= phaseDuration,
      healthStatus: _determineHealthStatus(batch),
    );
  }

  static String? _determineHealthStatus(CultivationBatch batch) {
    // Bisa ditambahkan logika berdasarkan sensor data
    if (batch.progressPercent >= 0.9) {
      return 'Hampir panen!';
    } else if (batch.currentPhase == GrowthPhase.flowering) {
      return 'Fase kritis - perhatikan suhu';
    }
    return null;
  }
}
