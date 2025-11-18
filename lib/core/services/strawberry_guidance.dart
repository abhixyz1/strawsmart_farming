import '../../models/guidance_item.dart';
import '../../screens/dashboard/dashboard_repository.dart';

/// Service untuk memberikan rekomendasi budidaya stroberi
/// berdasarkan data sensor yang diterima
class StrawberryGuidanceService {
  // Singleton pattern
  StrawberryGuidanceService._();
  static final instance = StrawberryGuidanceService._();

  // ==================== PARAMETER IDEAL ====================
  // Standar budidaya stroberi yang optimal
  
  /// Suhu ideal: 24-28°C
  static const double _tempMin = 24.0;
  static const double _tempMax = 28.0;
  static const double _tempCriticalMin = 18.0; // Terlalu dingin
  static const double _tempCriticalMax = 32.0; // Terlalu panas
  
  /// Kelembaban udara ideal: 55-70%
  static const double _humidityMin = 55.0;
  static const double _humidityMax = 70.0;
  static const double _humidityCriticalMin = 40.0;
  static const double _humidityCriticalMax = 85.0;
  
  /// Kelembaban tanah ideal: 35-45%
  static const double _soilMoistureMin = 35.0;
  static const double _soilMoistureMax = 45.0;
  static const double _soilMoistureCriticalMin = 25.0;
  static const double _soilMoistureCriticalMax = 60.0;
  
  /// Intensitas cahaya ideal: 15-20k lux
  /// Asumsi ADC max ~4095 = full sun (~50k lux)
  /// 15k lux ≈ 1200 ADC, 20k lux ≈ 1600 ADC
  static const double _lightAdcMin = 1200.0;
  static const double _lightAdcMax = 1600.0;
  static const double _lightAdcCriticalMin = 800.0;

  /// Generate rekomendasi berdasarkan snapshot sensor terbaru
  /// Returns list of guidance items sorted by priority
  List<GuidanceItem> getRecommendations(SensorSnapshot? snapshot) {
    if (snapshot == null) {
      return [];
    }

    final recommendations = <GuidanceItem>[];
    
    // Hanya analisis jika data tersedia
    final temp = snapshot.temperature;
    final humidity = snapshot.humidity;
    final soilMoisture = snapshot.soilMoisturePercent;
    final light = snapshot.lightIntensity;

    // Analisis suhu
    if (temp != null) {
      _analyzeTemperature(temp, recommendations);
    }
    
    // Analisis kelembaban udara
    if (humidity != null) {
      _analyzeHumidity(humidity, recommendations);
    }
    
    // Analisis kelembaban tanah
    if (soilMoisture != null) {
      _analyzeSoilMoisture(soilMoisture, recommendations);
    }
    
    // Analisis cahaya
    if (light != null) {
      _analyzeLight(light, recommendations);
    }
    
    // Analisis kombinasi (combo conditions)
    if (temp != null && humidity != null && soilMoisture != null) {
      _analyzeComboConditions(temp, humidity, soilMoisture, recommendations);
    }
    
    // Sort by priority (critical first)
    recommendations.sort((a, b) => a.priority.compareTo(b.priority));
    
    return recommendations;
  }

  /// Analisis suhu dan tambahkan rekomendasi jika perlu
  void _analyzeTemperature(double temp, List<GuidanceItem> recommendations) {
    if (temp < _tempCriticalMin) {
      // Terlalu dingin - Critical
      recommendations.add(GuidanceItem(
        title: 'Suhu Terlalu Rendah',
        description: 'Suhu ${temp.toStringAsFixed(1)}°C terlalu dingin. Tutup ventilasi atau gunakan heater untuk mencapai 24-28°C.',
        priority: 1,
        type: GuidanceType.temperature,
        sensorValue: '${temp.toStringAsFixed(1)}°C',
      ));
    } else if (temp > _tempCriticalMax) {
      // Terlalu panas - Critical
      recommendations.add(GuidanceItem(
        title: 'Suhu Terlalu Tinggi',
        description: 'Suhu ${temp.toStringAsFixed(1)}°C dapat menyebabkan stress tanaman. Segera aktifkan ventilasi atau kipas.',
        priority: 1,
        type: GuidanceType.temperature,
        sensorValue: '${temp.toStringAsFixed(1)}°C',
      ));
    } else if (temp < _tempMin) {
      // Agak dingin - Warning
      recommendations.add(GuidanceItem(
        title: 'Suhu Sedikit Rendah',
        description: 'Suhu ${temp.toStringAsFixed(1)}°C kurang optimal. Kurangi ventilasi untuk mencapai 24-28°C.',
        priority: 2,
        type: GuidanceType.temperature,
        sensorValue: '${temp.toStringAsFixed(1)}°C',
      ));
    } else if (temp > _tempMax) {
      // Agak panas - Warning
      recommendations.add(GuidanceItem(
        title: 'Suhu Sedikit Tinggi',
        description: 'Suhu ${temp.toStringAsFixed(1)}°C lebih tinggi dari ideal. Tingkatkan sirkulasi udara.',
        priority: 2,
        type: GuidanceType.temperature,
        sensorValue: '${temp.toStringAsFixed(1)}°C',
      ));
    } else {
      // Optimal - Info
      recommendations.add(GuidanceItem(
        title: 'Suhu Optimal',
        description: 'Suhu ${temp.toStringAsFixed(1)}°C sangat baik untuk pertumbuhan stroberi.',
        priority: 3,
        type: GuidanceType.temperature,
        sensorValue: '${temp.toStringAsFixed(1)}°C',
      ));
    }
  }

  /// Analisis kelembaban udara
  void _analyzeHumidity(double humidity, List<GuidanceItem> recommendations) {
    if (humidity < _humidityCriticalMin) {
      // Terlalu kering - Critical
      recommendations.add(GuidanceItem(
        title: 'Kelembaban Udara Sangat Rendah',
        description: 'Kelembaban ${humidity.toStringAsFixed(1)}% terlalu kering. Gunakan humidifier atau spray misting.',
        priority: 1,
        type: GuidanceType.humidity,
        sensorValue: '${humidity.toStringAsFixed(1)}%',
      ));
    } else if (humidity > _humidityCriticalMax) {
      // Terlalu lembab - Critical
      recommendations.add(GuidanceItem(
        title: 'Kelembaban Udara Terlalu Tinggi',
        description: 'Kelembaban ${humidity.toStringAsFixed(1)}% berisiko jamur. Aktifkan dehumidifier atau ventilasi.',
        priority: 1,
        type: GuidanceType.humidity,
        sensorValue: '${humidity.toStringAsFixed(1)}%',
      ));
    } else if (humidity < _humidityMin) {
      // Agak kering - Warning
      recommendations.add(GuidanceItem(
        title: 'Kelembaban Udara Rendah',
        description: 'Kelembaban ${humidity.toStringAsFixed(1)}% kurang optimal. Pertimbangkan misting ringan.',
        priority: 2,
        type: GuidanceType.humidity,
        sensorValue: '${humidity.toStringAsFixed(1)}%',
      ));
    } else if (humidity > _humidityMax) {
      // Agak lembab - Warning
      recommendations.add(GuidanceItem(
        title: 'Kelembaban Udara Tinggi',
        description: 'Kelembaban ${humidity.toStringAsFixed(1)}% sedikit tinggi. Pastikan sirkulasi udara baik.',
        priority: 2,
        type: GuidanceType.humidity,
        sensorValue: '${humidity.toStringAsFixed(1)}%',
      ));
    } else {
      // Optimal - Info
      recommendations.add(GuidanceItem(
        title: 'Kelembaban Udara Optimal',
        description: 'Kelembaban ${humidity.toStringAsFixed(1)}% ideal untuk mencegah penyakit.',
        priority: 3,
        type: GuidanceType.humidity,
        sensorValue: '${humidity.toStringAsFixed(1)}%',
      ));
    }
  }

  /// Analisis kelembaban tanah
  void _analyzeSoilMoisture(double soilMoisture, List<GuidanceItem> recommendations) {
    if (soilMoisture < _soilMoistureCriticalMin) {
      // Terlalu kering - Critical
      recommendations.add(GuidanceItem(
        title: 'Tanah Sangat Kering',
        description: 'Kelembaban tanah ${soilMoisture.toStringAsFixed(1)}% kritis. Segera aktifkan penyiraman otomatis.',
        priority: 1,
        type: GuidanceType.soilMoisture,
        sensorValue: '${soilMoisture.toStringAsFixed(1)}%',
      ));
    } else if (soilMoisture > _soilMoistureCriticalMax) {
      // Terlalu basah - Critical
      recommendations.add(GuidanceItem(
        title: 'Tanah Terlalu Basah',
        description: 'Kelembaban tanah ${soilMoisture.toStringAsFixed(1)}% berisiko akar busuk. Hentikan penyiraman.',
        priority: 1,
        type: GuidanceType.soilMoisture,
        sensorValue: '${soilMoisture.toStringAsFixed(1)}%',
      ));
    } else if (soilMoisture < _soilMoistureMin) {
      // Agak kering - Warning
      recommendations.add(GuidanceItem(
        title: 'Tanah Perlu Disiram',
        description: 'Kelembaban tanah ${soilMoisture.toStringAsFixed(1)}%. Jadwalkan penyiraman dalam 1-2 jam.',
        priority: 2,
        type: GuidanceType.soilMoisture,
        sensorValue: '${soilMoisture.toStringAsFixed(1)}%',
      ));
    } else if (soilMoisture > _soilMoistureMax) {
      // Agak basah - Warning
      recommendations.add(GuidanceItem(
        title: 'Tanah Cukup Basah',
        description: 'Kelembaban tanah ${soilMoisture.toStringAsFixed(1)}%. Tunda penyiraman berikutnya.',
        priority: 2,
        type: GuidanceType.soilMoisture,
        sensorValue: '${soilMoisture.toStringAsFixed(1)}%',
      ));
    } else {
      // Optimal - Info
      recommendations.add(GuidanceItem(
        title: 'Kelembaban Tanah Optimal',
        description: 'Kelembaban tanah ${soilMoisture.toStringAsFixed(1)}% sempurna untuk akar sehat.',
        priority: 3,
        type: GuidanceType.soilMoisture,
        sensorValue: '${soilMoisture.toStringAsFixed(1)}%',
      ));
    }
  }

  /// Analisis intensitas cahaya
  void _analyzeLight(int lightAdc, List<GuidanceItem> recommendations) {
    final lightAdcDouble = lightAdc.toDouble();
    
    if (lightAdcDouble < _lightAdcCriticalMin) {
      // Cahaya kurang - Critical
      final lightPercent = (lightAdcDouble / 4095 * 100).toStringAsFixed(0);
      recommendations.add(GuidanceItem(
        title: 'Cahaya Tidak Cukup',
        description: 'Intensitas cahaya $lightPercent% terlalu rendah. Tambahkan grow light atau pindahkan ke area terang.',
        priority: 1,
        type: GuidanceType.light,
        sensorValue: '$lightPercent%',
      ));
    } else if (lightAdcDouble < _lightAdcMin) {
      // Cahaya agak kurang - Warning
      final lightPercent = (lightAdcDouble / 4095 * 100).toStringAsFixed(0);
      recommendations.add(GuidanceItem(
        title: 'Cahaya Kurang Optimal',
        description: 'Intensitas cahaya $lightPercent%. Pertimbangkan pencahayaan tambahan.',
        priority: 2,
        type: GuidanceType.light,
        sensorValue: '$lightPercent%',
      ));
    } else if (lightAdcDouble > _lightAdcMax) {
      // Cahaya berlebih - Warning
      final lightPercent = (lightAdcDouble / 4095 * 100).toStringAsFixed(0);
      recommendations.add(GuidanceItem(
        title: 'Cahaya Sangat Terang',
        description: 'Intensitas cahaya $lightPercent%. Gunakan shade net jika tanaman terlihat layu.',
        priority: 2,
        type: GuidanceType.light,
        sensorValue: '$lightPercent%',
      ));
    } else {
      // Optimal - Info
      final lightPercent = (lightAdcDouble / 4095 * 100).toStringAsFixed(0);
      recommendations.add(GuidanceItem(
        title: 'Cahaya Optimal',
        description: 'Intensitas cahaya $lightPercent% ideal untuk fotosintesis maksimal.',
        priority: 3,
        type: GuidanceType.light,
        sensorValue: '$lightPercent%',
      ));
    }
  }

  /// Analisis kondisi kombinasi (multi-sensor)
  void _analyzeComboConditions(
    double temperature,
    double humidity,
    double soilMoisture,
    List<GuidanceItem> recommendations,
  ) {
    // Combo 1: Suhu tinggi + kelembaban rendah = Heat stress
    if (temperature > _tempMax && humidity < _humidityMin) {
      recommendations.add(GuidanceItem(
        title: 'Risiko Heat Stress',
        description: 'Kombinasi suhu tinggi (${temperature.toStringAsFixed(1)}°C) dan kelembaban rendah (${humidity.toStringAsFixed(1)}%) berisiko heat stress. Aktifkan misting sambil meningkatkan ventilasi.',
        priority: 1,
        type: GuidanceType.ventilation,
      ));
    }
    
    // Combo 2: Suhu tinggi + kelembaban tinggi = Jamur
    if (temperature > _tempMax && humidity > _humidityMax) {
      recommendations.add(GuidanceItem(
        title: 'Risiko Penyakit Jamur',
        description: 'Kombinasi suhu tinggi (${temperature.toStringAsFixed(1)}°C) dan kelembaban tinggi (${humidity.toStringAsFixed(1)}%) ideal untuk pertumbuhan jamur. Tingkatkan sirkulasi udara segera.',
        priority: 1,
        type: GuidanceType.ventilation,
      ));
    }
    
    // Combo 3: Tanah kering + kelembaban rendah = Dehidrasi
    if (soilMoisture < _soilMoistureMin && humidity < _humidityMin) {
      recommendations.add(GuidanceItem(
        title: 'Risiko Dehidrasi Tanaman',
        description: 'Tanah kering (${soilMoisture.toStringAsFixed(1)}%) dan udara kering (${humidity.toStringAsFixed(1)}%) dapat menyebabkan tanaman layu. Segera siram dan aktifkan misting.',
        priority: 1,
        type: GuidanceType.watering,
      ));
    }
  }
}
