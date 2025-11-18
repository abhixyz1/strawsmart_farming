# Fitur Rekomendasi Budidaya Stroberi

## Overview
Fitur ini memberikan rekomendasi otomatis berbasis rule-based system untuk budidaya stroberi berdasarkan data sensor real-time.

## Komponen

### 1. Model (`lib/models/guidance_item.dart`)
- **GuidanceItem**: Model untuk item rekomendasi
- **GuidanceType**: Enum untuk kategori rekomendasi (temperature, humidity, soil, light, watering, ventilation, general)
- **Priority**: 1 = critical, 2 = warning, 3 = info

### 2. Service (`lib/core/services/strawberry_guidance.dart`)
- **StrawberryGuidanceService**: Singleton service dengan logika rule-based
- **Parameter Ideal Stroberi**:
  - Suhu: 24-28°C (critical: <18°C atau >32°C)
  - Kelembaban udara: 55-70% (critical: <40% atau >85%)
  - Kelembaban tanah: 35-45% (critical: <25% atau >60%)
  - Cahaya: 1200-1600 ADC (critical: <800 ADC)

- **Combo Conditions**:
  - Heat stress: Suhu tinggi + kelembaban rendah
  - Risiko jamur: Suhu tinggi + kelembaban tinggi
  - Dehidrasi: Tanah kering + udara kering

### 3. Provider (`lib/screens/dashboard/dashboard_repository.dart`)
- **strawberryGuidanceProvider**: Provider yang mengambil data dari latestTelemetryProvider dan menghasilkan rekomendasi

### 4. UI Widget (`lib/screens/dashboard/widgets/strawberry_guidance_section.dart`)
- **StrawberryGuidanceSection**: Widget utama untuk menampilkan rekomendasi
- **_GuidanceCard**: Card individual dengan color-coding berdasarkan priority
- **Placeholder**: Ditampilkan saat data sensor belum tersedia

## Integrasi

Widget `StrawberryGuidanceSection` ditambahkan di `DashboardScreen` setelah sensor cards:

```dart
_buildSensorSection(latestAsync),
const SizedBox(height: 32),
const StrawberryGuidanceSection(), // <-- NEW
const SizedBox(height: 32),
const ScheduleStatusCard(),
```

## Testing

14 unit tests di `test/strawberry_guidance_test.dart`:
- ✅ Null safety handling
- ✅ Optimal conditions
- ✅ Critical temperature (high/low)
- ✅ Warning humidity
- ✅ Critical soil moisture (dry/wet)
- ✅ Low light detection
- ✅ Heat stress combo
- ✅ Fungal risk combo
- ✅ Dehydration risk combo
- ✅ Priority sorting
- ✅ Sensor value inclusion
- ✅ Partial data handling

## Keunggulan

1. **Reusable**: Logika terpisah dari UI, mudah di-update
2. **Tested**: 100% test coverage untuk business logic
3. **Clean Architecture**: Separation of concerns (Model-Service-Provider-Widget)
4. **No Breaking Changes**: Tidak merusak fitur existing
5. **Responsive**: Color-coded cards dengan priority indicators
6. **Actionable**: Rekomendasi dalam Bahasa Indonesia yang jelas

## Future Improvements

- [ ] Machine learning untuk prediksi kondisi
- [ ] Push notifications untuk critical warnings
- [ ] Historical trend analysis
- [ ] Custom threshold settings per user
- [ ] Export rekomendasi ke PDF
