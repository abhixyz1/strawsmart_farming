import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ============================================================
/// MODEL BATCH TANAM STROBERI
/// ============================================================
/// Berdasarkan kondisi budidaya stroberi di Indonesia:
/// - Iklim tropis dataran tinggi (700-1500 mdpl)
/// - Suhu optimal: 17-25°C
/// - Kelembaban: 80-90%
/// - Varietas populer: California, Sweetcharlie, Festival
/// ============================================================

/// Fase pertumbuhan stroberi dengan kebutuhan spesifik
enum GrowthPhase {
  /// Fase 1: Pembibitan (Minggu 1-2)
  /// - Kelembaban tinggi 85-95%
  /// - Cahaya teduh/rendah
  /// - Penyiraman: 2-3x sehari (sedikit)
  seedling,

  /// Fase 2: Vegetatif (Minggu 3-6)
  /// - Pertumbuhan daun aktif
  /// - Pupuk N tinggi
  /// - Penyiraman: 1-2x sehari
  vegetative,

  /// Fase 3: Berbunga (Minggu 7-10)
  /// - Mulai muncul bunga
  /// - Pupuk P-K tinggi, N dikurangi
  /// - Suhu stabil penting
  flowering,

  /// Fase 4: Pembentukan Buah (Minggu 11-14)
  /// - Buah mulai terbentuk
  /// - Pupuk K dominan
  /// - Kelembaban dijaga, hindari basah berlebihan
  fruiting,

  /// Fase 5: Pematangan & Panen (Minggu 15+)
  /// - Buah mulai merah
  /// - Kurangi penyiraman
  /// - Panen setiap 2-3 hari
  harvesting;

  String get label {
    switch (this) {
      case GrowthPhase.seedling:
        return 'Pembibitan';
      case GrowthPhase.vegetative:
        return 'Vegetatif';
      case GrowthPhase.flowering:
        return 'Berbunga';
      case GrowthPhase.fruiting:
        return 'Berbuah';
      case GrowthPhase.harvesting:
        return 'Panen';
    }
  }

  String get description {
    switch (this) {
      case GrowthPhase.seedling:
        return 'Fase awal pertumbuhan bibit, fokus pada penguatan akar';
      case GrowthPhase.vegetative:
        return 'Pertumbuhan daun dan batang aktif';
      case GrowthPhase.flowering:
        return 'Tanaman mulai berbunga, perlu nutrisi khusus';
      case GrowthPhase.fruiting:
        return 'Buah mulai terbentuk dan membesar';
      case GrowthPhase.harvesting:
        return 'Buah matang siap dipanen';
    }
  }

  String get emoji {
    switch (this) {
      case GrowthPhase.seedling:
        return '🌱';
      case GrowthPhase.vegetative:
        return '🌿';
      case GrowthPhase.flowering:
        return '🌸';
      case GrowthPhase.fruiting:
        return '🍓';
      case GrowthPhase.harvesting:
        return '🎉';
    }
  }

  /// Warna untuk UI
  int get colorValue {
    switch (this) {
      case GrowthPhase.seedling:
        return 0xFF81C784; // Light green
      case GrowthPhase.vegetative:
        return 0xFF4CAF50; // Green
      case GrowthPhase.flowering:
        return 0xFFE91E63; // Pink
      case GrowthPhase.fruiting:
        return 0xFFFF5722; // Deep orange
      case GrowthPhase.harvesting:
        return 0xFFF44336; // Red
    }
  }
}

/// Varietas stroberi populer di Indonesia
enum StrawberryVariety {
  california,
  sweetCharlie,
  festival,
  chandler,
  albion,
  other;

  String get label {
    switch (this) {
      case StrawberryVariety.california:
        return 'California';
      case StrawberryVariety.sweetCharlie:
        return 'Sweet Charlie';
      case StrawberryVariety.festival:
        return 'Festival';
      case StrawberryVariety.chandler:
        return 'Chandler';
      case StrawberryVariety.albion:
        return 'Albion';
      case StrawberryVariety.other:
        return 'Lainnya';
    }
  }

  String get description {
    switch (this) {
      case StrawberryVariety.california:
        return 'Paling populer di Indonesia, buah besar, manis';
      case StrawberryVariety.sweetCharlie:
        return 'Sangat manis, cocok dataran tinggi';
      case StrawberryVariety.festival:
        return 'Tahan penyakit, produksi tinggi';
      case StrawberryVariety.chandler:
        return 'Buah besar, cocok untuk komersial';
      case StrawberryVariety.albion:
        return 'Berbuah sepanjang tahun (everbearing)';
      case StrawberryVariety.other:
        return 'Varietas lainnya';
    }
  }

  /// Estimasi durasi total hingga panen (hari)
  int get daysToHarvest {
    switch (this) {
      case StrawberryVariety.california:
        return 90;
      case StrawberryVariety.sweetCharlie:
        return 85;
      case StrawberryVariety.festival:
        return 95;
      case StrawberryVariety.chandler:
        return 100;
      case StrawberryVariety.albion:
        return 80;
      case StrawberryVariety.other:
        return 90;
    }
  }
}

/// Model utama Batch Tanam
class CultivationBatch {
  const CultivationBatch({
    required this.id,
    required this.greenhouseId,
    required this.name,
    required this.variety,
    required this.plantingDate,
    required this.plantCount,
    required this.phaseSettings,
    this.customVarietyName,
    this.notes,
    this.isActive = true,
    this.harvestDate,
    this.totalHarvestKg,
    this.estimatedCost,
    this.photoUrls = const [],
    this.createdAt,
    this.updatedAt,
    // Hybrid phase transition fields
    this.phaseTransitions = const {},
    this.currentPhaseOverride,
  });

  final String id;
  final String greenhouseId;
  final String name; // e.g., "Batch #1 - November 2025"
  final StrawberryVariety variety;
  final String? customVarietyName; // Jika variety == other
  final DateTime plantingDate;
  final int plantCount; // Jumlah tanaman
  final Map<GrowthPhase, PhaseSettings> phaseSettings;
  final String? notes;
  final bool isActive;
  final DateTime? harvestDate;
  final double? totalHarvestKg;
  final double? estimatedCost; // Biaya operasional
  final List<String> photoUrls;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Hybrid Phase Transition: Manual override tanggal perpindahan fase
  /// Key = fase, Value = tanggal aktual masuk fase tersebut
  final Map<GrowthPhase, DateTime> phaseTransitions;
  
  /// Override fase saat ini (jika petani manually set)
  final GrowthPhase? currentPhaseOverride;

  /// Hitung fase saat ini - HYBRID: cek override dulu, lalu hitung otomatis
  GrowthPhase get currentPhase {
    // Jika ada manual override, gunakan itu
    if (currentPhaseOverride != null) {
      return currentPhaseOverride!;
    }
    
    // Jika ada phase transitions, cari fase terakhir yang sudah dimulai
    if (phaseTransitions.isNotEmpty) {
      final now = DateTime.now();
      GrowthPhase latestPhase = GrowthPhase.seedling;
      
      for (final phase in GrowthPhase.values) {
        final transitionDate = phaseTransitions[phase];
        if (transitionDate != null && transitionDate.isBefore(now)) {
          latestPhase = phase;
        }
      }
      return latestPhase;
    }
    
    // Fallback: hitung otomatis berdasarkan durasi
    return _calculatePhaseByDuration();
  }
  
  /// Hitung fase berdasarkan durasi (metode lama)
  GrowthPhase _calculatePhaseByDuration() {
    final daysSincePlanting = DateTime.now().difference(plantingDate).inDays;
    
    int cumulativeDays = 0;
    for (final phase in GrowthPhase.values) {
      cumulativeDays += phaseSettings[phase]?.durationDays ?? defaultPhaseDuration(phase);
      if (daysSincePlanting < cumulativeDays) {
        return phase;
      }
    }
    return GrowthPhase.harvesting;
  }

  /// Cek apakah fase tertentu sudah dimulai (ada transition date)
  bool isPhaseStarted(GrowthPhase phase) {
    return phaseTransitions.containsKey(phase);
  }

  /// Dapatkan tanggal mulai fase tertentu
  DateTime? getPhaseStartDate(GrowthPhase phase) {
    if (phaseTransitions.containsKey(phase)) {
      return phaseTransitions[phase];
    }
    // Fallback: estimasi berdasarkan durasi
    return _estimatePhaseStartDate(phase);
  }
  
  DateTime _estimatePhaseStartDate(GrowthPhase phase) {
    int daysToPhase = 0;
    for (final p in GrowthPhase.values) {
      if (p == phase) break;
      daysToPhase += phaseSettings[p]?.durationDays ?? defaultPhaseDuration(p);
    }
    return plantingDate.add(Duration(days: daysToPhase));
  }

  /// Hari sejak tanam
  int get daysSincePlanting => DateTime.now().difference(plantingDate).inDays;

  /// Persentase progress keseluruhan
  double get progressPercent {
    final totalDays = _totalCycleDays;
    final progress = daysSincePlanting / totalDays;
    return progress.clamp(0.0, 1.0);
  }

  /// Total hari dalam satu siklus tanam
  int get _totalCycleDays {
    int total = 0;
    for (final phase in GrowthPhase.values) {
      total += phaseSettings[phase]?.durationDays ?? defaultPhaseDuration(phase);
    }
    return total;
  }

  /// Estimasi tanggal panen
  DateTime get estimatedHarvestDate {
    return plantingDate.add(Duration(days: _totalCycleDays));
  }

  /// Hari tersisa sampai panen
  int get daysUntilHarvest {
    final remaining = estimatedHarvestDate.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// Progress dalam fase saat ini (0.0 - 1.0)
  double get currentPhaseProgress {
    final daysSincePhaseStart = _daysSincePhaseStart;
    final phaseDuration = phaseSettings[currentPhase]?.durationDays ?? 
                          defaultPhaseDuration(currentPhase);
    return (daysSincePhaseStart / phaseDuration).clamp(0.0, 1.0);
  }

  int get _daysSincePhaseStart {
    int cumulativeDays = 0;
    for (final phase in GrowthPhase.values) {
      if (phase == currentPhase) {
        return daysSincePlanting - cumulativeDays;
      }
      cumulativeDays += phaseSettings[phase]?.durationDays ?? defaultPhaseDuration(phase);
    }
    return 0;
  }

  /// Durasi default per fase (hari) - public untuk akses dari luar
  static int defaultPhaseDuration(GrowthPhase phase) {
    switch (phase) {
      case GrowthPhase.seedling:
        return 14; // 2 minggu
      case GrowthPhase.vegetative:
        return 28; // 4 minggu
      case GrowthPhase.flowering:
        return 21; // 3 minggu
      case GrowthPhase.fruiting:
        return 21; // 3 minggu
      case GrowthPhase.harvesting:
        return 30; // Ongoing, ~1 bulan
    }
  }

  /// Nama varietas untuk display
  String get varietyDisplayName {
    if (variety == StrawberryVariety.other && customVarietyName != null) {
      return customVarietyName!;
    }
    return variety.label;
  }

  /// Rekomendasi kebutuhan saat ini
  PhaseRequirements get currentRequirements {
    return phaseSettings[currentPhase]?.requirements ?? 
           PhaseRequirements.defaultFor(currentPhase);
  }

  factory CultivationBatch.fromFirestore(String id, Map<String, dynamic> data) {
    // Parse phase settings
    final phaseSettingsData = data['phaseSettings'] as Map<String, dynamic>? ?? {};
    final phaseSettings = <GrowthPhase, PhaseSettings>{};
    
    for (final phase in GrowthPhase.values) {
      final phaseData = phaseSettingsData[phase.name] as Map<String, dynamic>?;
      if (phaseData != null) {
        phaseSettings[phase] = PhaseSettings.fromJson(phaseData);
      } else {
        phaseSettings[phase] = PhaseSettings.defaultFor(phase);
      }
    }

    return CultivationBatch(
      id: id,
      greenhouseId: data['greenhouseId'] as String? ?? '',
      name: data['name'] as String? ?? 'Batch Tanpa Nama',
      variety: StrawberryVariety.values.firstWhere(
        (v) => v.name == data['variety'],
        orElse: () => StrawberryVariety.california,
      ),
      customVarietyName: data['customVarietyName'] as String?,
      plantingDate: (data['plantingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      plantCount: data['plantCount'] as int? ?? 0,
      phaseSettings: phaseSettings,
      notes: data['notes'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      harvestDate: (data['harvestDate'] as Timestamp?)?.toDate(),
      totalHarvestKg: (data['totalHarvestKg'] as num?)?.toDouble(),
      estimatedCost: (data['estimatedCost'] as num?)?.toDouble(),
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      // Parse phase transitions
      phaseTransitions: _parsePhaseTransitions(data['phaseTransitions']),
      currentPhaseOverride: data['currentPhaseOverride'] != null
          ? GrowthPhase.values.firstWhere(
              (p) => p.name == data['currentPhaseOverride'],
              orElse: () => GrowthPhase.seedling,
            )
          : null,
    );
  }

  static Map<GrowthPhase, DateTime> _parsePhaseTransitions(dynamic data) {
    if (data == null) return {};
    final map = data as Map<String, dynamic>;
    final result = <GrowthPhase, DateTime>{};
    for (final entry in map.entries) {
      final phase = GrowthPhase.values.firstWhere(
        (p) => p.name == entry.key,
        orElse: () => GrowthPhase.seedling,
      );
      if (entry.value is Timestamp) {
        result[phase] = (entry.value as Timestamp).toDate();
      }
    }
    return result;
  }

  Map<String, dynamic> toFirestore() {
    final phaseSettingsMap = <String, dynamic>{};
    for (final entry in phaseSettings.entries) {
      phaseSettingsMap[entry.key.name] = entry.value.toJson();
    }

    final phaseTransitionsMap = <String, dynamic>{};
    for (final entry in phaseTransitions.entries) {
      phaseTransitionsMap[entry.key.name] = Timestamp.fromDate(entry.value);
    }

    return {
      'greenhouseId': greenhouseId,
      'name': name,
      'variety': variety.name,
      'customVarietyName': customVarietyName,
      'plantingDate': Timestamp.fromDate(plantingDate),
      'plantCount': plantCount,
      'phaseSettings': phaseSettingsMap,
      'notes': notes,
      'isActive': isActive,
      'harvestDate': harvestDate != null ? Timestamp.fromDate(harvestDate!) : null,
      'totalHarvestKg': totalHarvestKg,
      'estimatedCost': estimatedCost,
      'photoUrls': photoUrls,
      'phaseTransitions': phaseTransitionsMap,
      'currentPhaseOverride': currentPhaseOverride?.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  CultivationBatch copyWith({
    String? id,
    String? greenhouseId,
    String? name,
    StrawberryVariety? variety,
    String? customVarietyName,
    DateTime? plantingDate,
    int? plantCount,
    Map<GrowthPhase, PhaseSettings>? phaseSettings,
    String? notes,
    bool? isActive,
    DateTime? harvestDate,
    double? totalHarvestKg,
    double? estimatedCost,
    List<String>? photoUrls,
    Map<GrowthPhase, DateTime>? phaseTransitions,
    GrowthPhase? currentPhaseOverride,
    bool clearPhaseOverride = false,
  }) {
    return CultivationBatch(
      id: id ?? this.id,
      greenhouseId: greenhouseId ?? this.greenhouseId,
      name: name ?? this.name,
      variety: variety ?? this.variety,
      customVarietyName: customVarietyName ?? this.customVarietyName,
      plantingDate: plantingDate ?? this.plantingDate,
      plantCount: plantCount ?? this.plantCount,
      phaseSettings: phaseSettings ?? this.phaseSettings,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      harvestDate: harvestDate ?? this.harvestDate,
      totalHarvestKg: totalHarvestKg ?? this.totalHarvestKg,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      photoUrls: photoUrls ?? this.photoUrls,
      phaseTransitions: phaseTransitions ?? this.phaseTransitions,
      currentPhaseOverride: clearPhaseOverride 
          ? null 
          : (currentPhaseOverride ?? this.currentPhaseOverride),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Pengaturan per fase (bisa dikustomisasi per batch)
class PhaseSettings {
  const PhaseSettings({
    required this.durationDays,
    required this.requirements,
  });

  final int durationDays;
  final PhaseRequirements requirements;

  factory PhaseSettings.defaultFor(GrowthPhase phase) {
    return PhaseSettings(
      durationDays: CultivationBatch.defaultPhaseDuration(phase),
      requirements: PhaseRequirements.defaultFor(phase),
    );
  }

  factory PhaseSettings.fromJson(Map<String, dynamic> json) {
    return PhaseSettings(
      durationDays: json['durationDays'] as int? ?? 14,
      requirements: PhaseRequirements.fromJson(
        json['requirements'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'durationDays': durationDays,
      'requirements': requirements.toJson(),
    };
  }
}

/// Kebutuhan per fase: suhu, kelembaban, penyiraman, pupuk
class PhaseRequirements {
  const PhaseRequirements({
    required this.minTemp,
    required this.maxTemp,
    required this.minHumidity,
    required this.maxHumidity,
    required this.minSoilMoisture,
    required this.maxSoilMoisture,
    required this.wateringPerDay,
    required this.wateringDurationSec,
    required this.fertilizers,
    this.lightHoursPerDay,
    this.notes,
  });

  final double minTemp; // °C
  final double maxTemp;
  final double minHumidity; // %
  final double maxHumidity;
  final double minSoilMoisture; // %
  final double maxSoilMoisture;
  final int wateringPerDay; // Kali per hari
  final int wateringDurationSec; // Detik per penyiraman
  final List<FertilizerRecommendation> fertilizers;
  final int? lightHoursPerDay;
  final String? notes;

  /// Kebutuhan default per fase berdasarkan best practice stroberi Indonesia
  factory PhaseRequirements.defaultFor(GrowthPhase phase) {
    switch (phase) {
      case GrowthPhase.seedling:
        return PhaseRequirements(
          minTemp: 18,
          maxTemp: 24,
          minHumidity: 85,
          maxHumidity: 95,
          minSoilMoisture: 70,
          maxSoilMoisture: 85,
          wateringPerDay: 3,
          wateringDurationSec: 20,
          lightHoursPerDay: 8,
          fertilizers: [
            FertilizerRecommendation(
              name: 'NPK 15-15-15',
              dosage: '0.5 gram/liter',
              frequency: 'Seminggu sekali',
              notes: 'Pupuk akar, konsentrasi rendah',
            ),
          ],
          notes: 'Jaga kelembaban tinggi, hindari sinar matahari langsung',
        );

      case GrowthPhase.vegetative:
        return PhaseRequirements(
          minTemp: 17,
          maxTemp: 25,
          minHumidity: 75,
          maxHumidity: 85,
          minSoilMoisture: 60,
          maxSoilMoisture: 75,
          wateringPerDay: 2,
          wateringDurationSec: 45,
          lightHoursPerDay: 12,
          fertilizers: [
            FertilizerRecommendation(
              name: 'NPK 20-10-10',
              dosage: '2 gram/liter',
              frequency: 'Seminggu sekali',
              notes: 'Nitrogen tinggi untuk pertumbuhan daun',
            ),
            FertilizerRecommendation(
              name: 'Pupuk Daun (Gandasil D)',
              dosage: '2 gram/liter',
              frequency: '2 minggu sekali',
              notes: 'Semprot pagi/sore',
            ),
          ],
          notes: 'Fokus pertumbuhan daun, pastikan nutrisi N tercukupi',
        );

      case GrowthPhase.flowering:
        return PhaseRequirements(
          minTemp: 18,
          maxTemp: 25,
          minHumidity: 70,
          maxHumidity: 80,
          minSoilMoisture: 55,
          maxSoilMoisture: 70,
          wateringPerDay: 2,
          wateringDurationSec: 40,
          lightHoursPerDay: 14,
          fertilizers: [
            FertilizerRecommendation(
              name: 'NPK 10-20-20',
              dosage: '2 gram/liter',
              frequency: 'Seminggu sekali',
              notes: 'P-K tinggi untuk pembungaan',
            ),
            FertilizerRecommendation(
              name: 'Pupuk Bunga (Gandasil B)',
              dosage: '2 gram/liter',
              frequency: 'Seminggu sekali',
              notes: 'Merangsang pembungaan',
            ),
            FertilizerRecommendation(
              name: 'Kalsium Boron',
              dosage: '1 gram/liter',
              frequency: '2 minggu sekali',
              notes: 'Mencegah bunga rontok',
            ),
          ],
          notes: 'Kurangi N, tingkatkan P-K. Jaga suhu stabil.',
        );

      case GrowthPhase.fruiting:
        return PhaseRequirements(
          minTemp: 18,
          maxTemp: 26,
          minHumidity: 65,
          maxHumidity: 75,
          minSoilMoisture: 50,
          maxSoilMoisture: 65,
          wateringPerDay: 2,
          wateringDurationSec: 35,
          lightHoursPerDay: 14,
          fertilizers: [
            FertilizerRecommendation(
              name: 'NPK 12-12-36',
              dosage: '2 gram/liter',
              frequency: 'Seminggu sekali',
              notes: 'Kalium tinggi untuk kualitas buah',
            ),
            FertilizerRecommendation(
              name: 'Pupuk Kalium (KCl)',
              dosage: '1 gram/liter',
              frequency: '2 minggu sekali',
              notes: 'Meningkatkan rasa manis',
            ),
          ],
          notes: 'Hindari kelembaban berlebihan untuk mencegah busuk buah',
        );

      case GrowthPhase.harvesting:
        return PhaseRequirements(
          minTemp: 18,
          maxTemp: 26,
          minHumidity: 60,
          maxHumidity: 70,
          minSoilMoisture: 45,
          maxSoilMoisture: 60,
          wateringPerDay: 1,
          wateringDurationSec: 30,
          lightHoursPerDay: 12,
          fertilizers: [
            FertilizerRecommendation(
              name: 'NPK 10-10-30',
              dosage: '1.5 gram/liter',
              frequency: '2 minggu sekali',
              notes: 'Maintenance, K untuk kualitas',
            ),
          ],
          notes: 'Panen pagi hari saat embun sudah kering. Panen tiap 2-3 hari.',
        );
    }
  }

  factory PhaseRequirements.fromJson(Map<String, dynamic> json) {
    final fertilizersData = json['fertilizers'] as List<dynamic>? ?? [];
    
    return PhaseRequirements(
      minTemp: (json['minTemp'] as num?)?.toDouble() ?? 18,
      maxTemp: (json['maxTemp'] as num?)?.toDouble() ?? 25,
      minHumidity: (json['minHumidity'] as num?)?.toDouble() ?? 70,
      maxHumidity: (json['maxHumidity'] as num?)?.toDouble() ?? 85,
      minSoilMoisture: (json['minSoilMoisture'] as num?)?.toDouble() ?? 50,
      maxSoilMoisture: (json['maxSoilMoisture'] as num?)?.toDouble() ?? 70,
      wateringPerDay: json['wateringPerDay'] as int? ?? 2,
      wateringDurationSec: json['wateringDurationSec'] as int? ?? 30,
      lightHoursPerDay: json['lightHoursPerDay'] as int?,
      fertilizers: fertilizersData
          .map((f) => FertilizerRecommendation.fromJson(f as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minTemp': minTemp,
      'maxTemp': maxTemp,
      'minHumidity': minHumidity,
      'maxHumidity': maxHumidity,
      'minSoilMoisture': minSoilMoisture,
      'maxSoilMoisture': maxSoilMoisture,
      'wateringPerDay': wateringPerDay,
      'wateringDurationSec': wateringDurationSec,
      'lightHoursPerDay': lightHoursPerDay,
      'fertilizers': fertilizers.map((f) => f.toJson()).toList(),
      'notes': notes,
    };
  }
}

/// Rekomendasi pupuk
class FertilizerRecommendation {
  const FertilizerRecommendation({
    required this.name,
    required this.dosage,
    required this.frequency,
    this.notes,
  });

  final String name;
  final String dosage;
  final String frequency;
  final String? notes;

  factory FertilizerRecommendation.fromJson(Map<String, dynamic> json) {
    return FertilizerRecommendation(
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'notes': notes,
    };
  }
}

/// Catatan harian/jurnal batch
class BatchJournalEntry {
  const BatchJournalEntry({
    required this.id,
    required this.batchId,
    required this.date,
    required this.type,
    this.title,
    this.description,
    this.photoUrls = const [],
    this.fertilizerUsed,
    this.harvestKg,
    this.weatherNote,
    this.createdAt,
  });

  final String id;
  final String batchId;
  final DateTime date;
  final JournalEntryType type;
  final String? title;
  final String? description;
  final List<String> photoUrls;
  final FertilizerRecommendation? fertilizerUsed;
  final double? harvestKg; // Jika type == harvest
  final String? weatherNote;
  final DateTime? createdAt;

  factory BatchJournalEntry.fromFirestore(String id, Map<String, dynamic> data) {
    return BatchJournalEntry(
      id: id,
      batchId: data['batchId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: JournalEntryType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => JournalEntryType.note,
      ),
      title: data['title'] as String?,
      description: data['description'] as String?,
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
      fertilizerUsed: data['fertilizerUsed'] != null
          ? FertilizerRecommendation.fromJson(
              data['fertilizerUsed'] as Map<String, dynamic>)
          : null,
      harvestKg: (data['harvestKg'] as num?)?.toDouble(),
      weatherNote: data['weatherNote'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'batchId': batchId,
      'date': Timestamp.fromDate(date),
      'type': type.name,
      'title': title,
      'description': description,
      'photoUrls': photoUrls,
      'fertilizerUsed': fertilizerUsed?.toJson(),
      'harvestKg': harvestKg,
      'weatherNote': weatherNote,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

enum JournalEntryType {
  note,
  fertilizing,
  watering,
  pestControl,
  pruning,
  harvest,
  issue,
  milestone,
  weather,
  inspection,
  photo;

  String get label {
    switch (this) {
      case JournalEntryType.note:
        return 'Catatan';
      case JournalEntryType.fertilizing:
        return 'Pemupukan';
      case JournalEntryType.watering:
        return 'Penyiraman';
      case JournalEntryType.pestControl:
        return 'Pengendalian Hama';
      case JournalEntryType.pruning:
        return 'Pemangkasan';
      case JournalEntryType.harvest:
        return 'Panen';
      case JournalEntryType.issue:
        return 'Masalah';
      case JournalEntryType.milestone:
        return 'Milestone';
      case JournalEntryType.weather:
        return 'Cuaca';
      case JournalEntryType.inspection:
        return 'Inspeksi';
      case JournalEntryType.photo:
        return 'Foto Progress';
    }
  }

  String get emoji {
    switch (this) {
      case JournalEntryType.note:
        return '📝';
      case JournalEntryType.fertilizing:
        return '🧪';
      case JournalEntryType.watering:
        return '💧';
      case JournalEntryType.pestControl:
        return '🐛';
      case JournalEntryType.pruning:
        return '✂️';
      case JournalEntryType.harvest:
        return '🍓';
      case JournalEntryType.issue:
        return '⚠️';
      case JournalEntryType.milestone:
        return '🎯';
      case JournalEntryType.weather:
        return '🌤️';
      case JournalEntryType.inspection:
        return '🔍';
      case JournalEntryType.photo:
        return '📷';
    }
  }

  int get colorValue {
    switch (this) {
      case JournalEntryType.note:
        return 0xFF9E9E9E; // Grey
      case JournalEntryType.fertilizing:
        return 0xFF4CAF50; // Green
      case JournalEntryType.watering:
        return 0xFF2196F3; // Blue
      case JournalEntryType.pestControl:
        return 0xFFFF9800; // Orange
      case JournalEntryType.pruning:
        return 0xFF795548; // Brown
      case JournalEntryType.harvest:
        return 0xFFF44336; // Red
      case JournalEntryType.issue:
        return 0xFFE91E63; // Pink
      case JournalEntryType.milestone:
        return 0xFF9C27B0; // Purple
      case JournalEntryType.weather:
        return 0xFF00BCD4; // Cyan
      case JournalEntryType.inspection:
        return 0xFF607D8B; // Blue Grey
      case JournalEntryType.photo:
        return 0xFF3F51B5; // Indigo
    }
  }

  /// Color as Flutter Color object
  Color get color => Color(colorValue);

  /// Icon for this entry type
  IconData get icon {
    switch (this) {
      case JournalEntryType.note:
        return Icons.note;
      case JournalEntryType.fertilizing:
        return Icons.science;
      case JournalEntryType.watering:
        return Icons.water_drop;
      case JournalEntryType.pestControl:
        return Icons.bug_report;
      case JournalEntryType.pruning:
        return Icons.content_cut;
      case JournalEntryType.harvest:
        return Icons.agriculture;
      case JournalEntryType.issue:
        return Icons.warning;
      case JournalEntryType.milestone:
        return Icons.flag;
      case JournalEntryType.weather:
        return Icons.wb_sunny;
      case JournalEntryType.inspection:
        return Icons.search;
      case JournalEntryType.photo:
        return Icons.photo_camera;
    }
  }
}
