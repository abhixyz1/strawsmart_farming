/// Model untuk item rekomendasi budidaya stroberi
class GuidanceItem {
  /// Judul singkat rekomendasi
  final String title;
  
  /// Deskripsi lengkap rekomendasi
  final String description;
  
  /// Tingkat prioritas (1 = critical, 2 = warning, 3 = info)
  final int priority;
  
  /// Tipe rekomendasi untuk menentukan icon
  final GuidanceType type;
  
  /// Nilai sensor yang memicu rekomendasi (opsional)
  final String? sensorValue;

  const GuidanceItem({
    required this.title,
    required this.description,
    required this.priority,
    required this.type,
    this.sensorValue,
  });

  /// Critical guidance (priority 1)
  bool get isCritical => priority == 1;
  
  /// Warning guidance (priority 2)
  bool get isWarning => priority == 2;
  
  /// Info guidance (priority 3)
  bool get isInfo => priority == 3;
}

/// Tipe rekomendasi untuk kategorisasi
enum GuidanceType {
  temperature,    // Suhu
  humidity,       // Kelembaban udara
  soilMoisture,   // Kelembaban tanah
  light,          // Cahaya
  watering,       // Penyiraman
  ventilation,    // Ventilasi
  general,        // Umum
}
