# 🍓 StrawSmart Firmware ESP32

Firmware untuk sistem monitoring dan kontrol irigasi otomatis tanaman stroberi berbasis ESP32.

[![PlatformIO](https://img.shields.io/badge/PlatformIO-ESP32-orange)](https://platformio.org/)
[![Firebase](https://img.shields.io/badge/Firebase-RTDB-yellow)](https://firebase.google.com/)
[![Version](https://img.shields.io/badge/Version-1.2.0-blue)]()

---

## 📋 Daftar Isi

- [Fitur](#-fitur)
- [Hardware Requirements](#-hardware-requirements)
- [Pin Configuration](#-pin-configuration)
- [Instalasi](#-instalasi)
- [Konfigurasi](#-konfigurasi)
- [Struktur Firebase RTDB](#-struktur-firebase-rtdb)
- [Mode Operasi](#-mode-operasi)
- [Jadwal Penyiraman](#-jadwal-penyiraman)
- [Parameter Lingkungan Ideal](#-parameter-lingkungan-ideal)
- [Fase Pertumbuhan Stroberi](#-fase-pertumbuhan-stroberi)
- [Timing Configuration](#-timing-configuration)
- [Troubleshooting](#-troubleshooting)

---

## ✨ Fitur

| Fitur | Deskripsi |
|-------|-----------|
| 🌡️ **Multi-Sensor Monitoring** | DHT22 (suhu & kelembaban), Soil Moisture, LDR |
| 🧠 **Fuzzy Logic Engine** | Analisis adaptive untuk keputusan penyiraman optimal |
| ⏰ **Scheduled Watering** | Jadwal penyiraman harian yang dapat dikonfigurasi |
| 💧 **Moisture Threshold** | Penyiraman darurat saat kelembaban tanah kritis |
| 📱 **Manual Control** | Kontrol langsung dari aplikasi Flutter |
| 🔄 **Auto/Manual Mode** | Switching mode tanpa restart |
| 📡 **Real-time Sync** | Sinkronisasi data dengan Firebase setiap 30 detik |
| 💓 **Heartbeat** | Update status online setiap 30 detik |
| 🛡️ **Safety Features** | Auto-stop, max duration limit, interval protection |

---

## 🔧 Hardware Requirements

| Komponen | Spesifikasi | Quantity |
|----------|-------------|----------|
| ESP32 DevKit C V4 | 240MHz, 320KB RAM, 4MB Flash | 1 |
| DHT22 | Sensor suhu & kelembaban | 1 |
| Soil Moisture Sensor | Capacitive (ADC) | 1 |
| LDR Module | Light Dependent Resistor | 1 |
| Relay Module | 5V, 1 Channel | 1 |
| Water Pump | 5V DC / 12V DC | 1 |
| LED Indicator | 3mm/5mm | 1 |

---

## 📌 Pin Configuration

| Komponen | GPIO | Tipe |
|----------|------|------|
| DHT22 (Data) | 15 | Digital Input |
| Soil Moisture | 34 | ADC Input |
| LDR | 35 | ADC Input |
| Relay (Pump) | 2 | Digital Output |
| LED Indicator | 4 | Digital Output |

---

## 🚀 Instalasi

### Prerequisites

- [PlatformIO](https://platformio.org/) (VS Code Extension)
- [Wokwi Simulator](https://wokwi.com/) (untuk simulasi)

### Steps

1. **Clone repository**
   ```bash
   git clone https://github.com/eerfinn/strawsmart-firmware-esp32.git
   cd strawsmart-firmware-esp32
   ```

2. **Konfigurasi WiFi & Firebase**
   ```bash
   cp include/config/Secrets.h.example include/config/Secrets.h
   ```
   Edit `Secrets.h` dengan kredensial Anda.

3. **Build & Upload**
   ```bash
   pio run --target upload
   ```

4. **Monitor Serial**
   ```bash
   pio device monitor
   ```

---

## ⚙️ Konfigurasi

### Secrets.h

```cpp
#define WIFI_SSID "your_wifi_ssid"
#define WIFI_PASSWORD "your_wifi_password"
#define FIREBASE_HOST "your-project.firebaseio.com"
#define FIREBASE_AUTH "your_database_secret"
#define FIREBASE_PROJECT_ID "your-project-id"
```

### HardwareConfig.h

```cpp
#define FIRMWARE_VERSION "1.2.0"
#define DEVICE_ID "greenhouse_node_001"
```

---

## 📊 Struktur Firebase RTDB

```
devices/
└── greenhouse_node_001/
    ├── info/                     # Status & metadata perangkat
    │   ├── locationName          # "Greenhouse Bedengan"
    │   ├── firmwareVersion       # "1.2.0"
    │   ├── pumpActive            # boolean
    │   ├── isOnline              # boolean
    │   ├── lastSeenAt            # Unix timestamp
    │   ├── wifiSignalDbm         # int (dBm)
    │   ├── uptimeSeconds         # int
    │   ├── autoModeEnabled       # boolean
    │   ├── freeMemoryBytes       # int
    │   └── provisionedAt         # Unix timestamp
    │
    ├── latest/                   # Data sensor real-time
    │   ├── temperatureCelsius    # float (°C)
    │   ├── humidityPercent       # float (%)
    │   ├── soilMoistureRaw       # int (0-4095 ADC)
    │   ├── soilMoisturePercent   # float (0-100%)
    │   ├── lightIntensityRaw     # int (0-4095 ADC)
    │   └── timestamp             # Unix timestamp
    │
    ├── readings/                 # Historical data
    │   └── {timestamp}/          # Per-reading data
    │
    ├── control/                  # Kontrol dari App
    │   ├── mode                  # "auto" | "manual"
    │   ├── pumpRequested         # boolean
    │   ├── durationSeconds       # int
    │   └── updatedAt             # Unix timestamp
    │
    └── schedule/                 # Jadwal penyiraman
        ├── enabled               # boolean
        ├── daily/                # Array jadwal harian
        │   ├── 0/ { time, duration, enabled }
        │   └── 1/ { time, duration, enabled }
        ├── moisture_threshold/
        │   ├── enabled           # boolean
        │   ├── trigger_below     # int (%)
        │   └── duration          # int (seconds)
        └── last_scheduled_run/
            ├── time              # ISO timestamp
            ├── duration          # int
            └── completed         # boolean
```

---

## 🎮 Mode Operasi

### 1. Auto Mode (Default)

Sistem menggunakan kombinasi metode untuk keputusan penyiraman:

| Prioritas | Sumber | Trigger | Deskripsi |
|-----------|--------|---------|-----------|
| 1 | **Moisture Threshold** | `soil% < trigger_below` | Penyiraman darurat |
| 2 | **Fuzzy Logic** | Analisis multi-sensor | Keputusan adaptive |
| 3 | **Daily Schedule** | Waktu cocok | Jadwal terjadwal |

### 2. Manual Mode

- User mengontrol pompa langsung dari aplikasi
- Semua auto-logic dinonaktifkan
- Saat switch ke manual, pompa auto dihentikan

### Watering Sources

| Source | Enum | Keterangan |
|--------|------|------------|
| Manual | `SOURCE_MANUAL` | User trigger via app |
| Fuzzy Logic | `SOURCE_FUZZY` | Auto adaptive analysis |
| Scheduled | `SOURCE_SCHEDULED` | Time-based schedule |
| Moisture | `SOURCE_MOISTURE` | Emergency low moisture |

---

## 💧 Jadwal Penyiraman

### Pembagian Tanggung Jawab

| Komponen | Tanggung Jawab |
|----------|----------------|
| **Firmware ESP32** | Membaca & mengeksekusi jadwal dari `/schedule/` |
| **Flutter App** | Menghitung fase, mengupdate jadwal ke RTDB sesuai fase |
| **Firebase RTDB** | Menyimpan jadwal aktif di `/devices/{id}/schedule/` |
| **Firestore** | Menyimpan data batch & fase di `cultivationBatches` |

### Default Schedule (Firmware)

Firmware membuat jadwal default **hanya jika node `/schedule/` belum ada**:

| Waktu | Durasi | Status | Keterangan |
|-------|--------|--------|------------|
| **06:00** | 60 detik | ✅ Enabled | Penyiraman pagi |
| **17:00** | 45 detik | ✅ Enabled | Penyiraman sore |

> **Catatan:** Setelah aplikasi Flutter mengupdate jadwal sesuai fase, jadwal default ini akan digantikan.

### Moisture Threshold Default (Firmware)

| Parameter | Nilai Default | Keterangan |
|-----------|---------------|------------|
| **Enabled** | `true` | Fitur aktif |
| **Trigger Below** | `30%` | Siram jika soil < 30% |
| **Duration** | `30 detik` | Durasi penyiraman darurat |

### Safety Limits

| Parameter | Nilai | Keterangan |
|-----------|-------|------------|
| **Max Duration** | 120 detik (2 menit) | Batas maksimal per sesi |
| **Min Interval** | 120 detik (2 menit) | Jeda minimum antar penyiraman auto |

---

## 🌱 Fase Pertumbuhan Stroberi

> ⚠️ **PENTING:** Fase pertumbuhan dikelola oleh **aplikasi Flutter** (disimpan di Firestore `cultivationBatches`). Firmware **TIDAK** mengetahui fase saat ini. Aplikasi Flutter bertanggung jawab untuk **mengupdate jadwal penyiraman di RTDB** (`/schedule/`) sesuai fase pertumbuhan yang aktif.

### Alur Integrasi Fase → Jadwal

```
[Flutter App]                              [Firebase]                         [ESP32 Firmware]
     │                                          │                                    │
     │ 1. Hitung fase dari plantingDate         │                                    │
     │    (cultivationBatches di Firestore)     │                                    │
     │                                          │                                    │
     │ 2. Update schedule di RTDB ─────────────▶│ /devices/{id}/schedule/            │
     │    sesuai kebutuhan fase                 │                                    │
     │                                          │                                    │
     │                                          │◀───────── 3. Sync setiap 60 detik ─│
     │                                          │                                    │
     │                                          │             4. Eksekusi jadwal ────│
```

### Overview Fase

| Fase | Emoji | Durasi | Total Hari |
|------|-------|--------|------------|
| **Seedling** (Pembibitan) | 🌱 | 14 hari | Hari 1-14 |
| **Vegetative** (Vegetatif) | 🌿 | 28 hari | Hari 15-42 |
| **Flowering** (Berbunga) | 🌸 | 21 hari | Hari 43-63 |
| **Fruiting** (Berbuah) | 🍓 | 21 hari | Hari 64-84 |
| **Harvesting** (Panen) | 🎉 | 30 hari | Hari 85-114 |

**Total Siklus: ~114 hari (±4 bulan)**

---

### 📅 Rekomendasi Jadwal Penyiraman Per Fase

> **Catatan:** Tabel ini adalah **rekomendasi** yang harus diimplementasikan di sisi **aplikasi Flutter**. Flutter harus mengupdate node `/devices/{id}/schedule/` di RTDB sesuai fase aktif.

| Fase | Frekuensi/Hari | Durasi (detik) | Jadwal Waktu | Kelembaban Ideal |
|------|----------------|----------------|--------------|------------------|
| 🌱 **Seedling** | 3x | 20 | 06:00, 12:00, 18:00 | 70-85% |
| 🌿 **Vegetative** | 2x | 45 | 06:00, 17:00 | 60-75% |
| 🌸 **Flowering** | 2x | 40 | 06:00, 17:00 | 55-70% |
| 🍓 **Fruiting** | 2x | 35 | 06:00, 17:00 | 50-65% |
| 🎉 **Harvesting** | 1x | 30 | 06:00 | 45-60% |

### Rekomendasi Moisture Threshold Per Fase

| Fase | Trigger Below | Durasi Emergency |
|------|---------------|------------------|
| 🌱 Seedling | 70% | 15 detik |
| 🌿 Vegetative | 60% | 30 detik |
| 🌸 Flowering | 55% | 25 detik |
| 🍓 Fruiting | 50% | 25 detik |
| 🎉 Harvesting | 45% | 20 detik |

### Contoh Implementasi Flutter (Update Schedule per Fase)

```dart
// Di Flutter App - saat fase berubah atau setiap hari
Future<void> updateScheduleForPhase(String deviceId, GrowthPhase phase) async {
  final scheduleRef = FirebaseDatabase.instance
      .ref('devices/$deviceId/schedule');
  
  Map<String, dynamic> scheduleConfig;
  
  switch (phase) {
    case GrowthPhase.seedling:
      scheduleConfig = {
        'enabled': true,
        'daily': {
          '0': {'time': '06:00', 'duration': 20, 'enabled': true},
          '1': {'time': '12:00', 'duration': 20, 'enabled': true},
          '2': {'time': '18:00', 'duration': 20, 'enabled': true},
        },
        'moisture_threshold': {
          'enabled': true,
          'trigger_below': 70,
          'duration': 15,
        },
      };
      break;
    case GrowthPhase.vegetative:
      scheduleConfig = {
        'enabled': true,
        'daily': {
          '0': {'time': '06:00', 'duration': 45, 'enabled': true},
          '1': {'time': '17:00', 'duration': 45, 'enabled': true},
        },
        'moisture_threshold': {
          'enabled': true,
          'trigger_below': 60,
          'duration': 30,
        },
      };
      break;
    // ... dst untuk fase lainnya
  }
  
  await scheduleRef.update(scheduleConfig);
}
```

---

## 🌡️ Parameter Lingkungan Ideal

### Kalibrasi Sensor Soil Moisture

| Parameter | Nilai ADC | Keterangan |
|-----------|-----------|------------|
| **DRY** | 3000 | Tanah kering |
| **WET** | 800 | Tanah basah |

**Formula Konversi:**
```cpp
float percent = map(adc, WET_ADC, DRY_ADC, 100, 0);
// map(adc, 800, 3000, 100, 0)
```

### Parameter Optimal Per Fase

| Fase | Suhu (°C) | Kelembaban Udara (%) | Kelembaban Tanah (%) | Cahaya (jam) |
|------|-----------|----------------------|----------------------|--------------|
| 🌱 Seedling | 18-24 | 85-95 | 70-85 | 8 |
| 🌿 Vegetative | 17-25 | 75-85 | 60-75 | 12 |
| 🌸 Flowering | 18-25 | 70-80 | 55-70 | 14 |
| 🍓 Fruiting | 18-26 | 65-75 | 50-65 | 14 |
| 🎉 Harvesting | 18-26 | 60-70 | 45-60 | 12 |

### Threshold Kritis (Alert)

| Parameter | Critical Low | Critical High |
|-----------|--------------|---------------|
| Suhu | 5°C | 35°C |
| Kelembaban Tanah | 30% | 90% |

---

## ⏱️ Timing Configuration

| Parameter | Nilai | Keterangan |
|-----------|-------|------------|
| `TELEMETRY_INTERVAL` | 30 detik | Interval baca sensor |
| `COMMAND_CHECK_INTERVAL` | 1 detik | Interval cek perintah app |
| `CONTROL_SYNC_INTERVAL` | 1 detik | Interval sync mode |
| `HEARTBEAT_INTERVAL` | 30 detik | Interval update lastSeenAt |
| `SCHEDULE_SYNC_INTERVAL` | 60 detik | Interval sync jadwal |
| `SCHEDULE_CHECK_INTERVAL` | 10 detik | Interval cek jadwal |

---

## 🔄 Flow Komunikasi

### Sensor → Firebase → App
```
ESP32 baca sensor (setiap 30 detik)
    ↓
Write ke Firebase RTDB
    • /latest/
    • /readings/{timestamp}/
    • /info/
    ↓
Flutter StreamProvider subscribe
    ↓
UI update otomatis
```

### App → Firebase → ESP32
```
User tap tombol di Flutter
    ↓
Write ke Firebase RTDB
    • /control/pumpRequested = true
    • /control/durationSeconds = 60
    ↓
ESP32 listen control/ (setiap 1 detik)
    ↓
ESP32 aktifkan relay
    ↓
Update /info/pumpActive = true
```

---

## 🐛 Troubleshooting

### Device Offline

1. Cek koneksi WiFi
2. Cek kredensial Firebase di `Secrets.h`
3. Pastikan `lastSeenAt` update (threshold: 90 detik)

### Pompa Tidak Menyala

1. Cek mode: harus `manual` untuk kontrol langsung
2. Cek `pumpRequested` di Firebase
3. Cek safety interval (min 2 menit)
4. Cek `durationSeconds` > 0

### Sensor Reading Invalid

1. Cek wiring sensor
2. Cek nilai ADC (0-4095)
3. Lihat serial monitor untuk error

---

## 📁 Struktur Project

```
firmware-esp32-node001/
├── include/
│   ├── config.h                 # Master config
│   ├── config/
│   │   ├── HardwareConfig.h     # Pin & device settings
│   │   ├── TimingConfig.h       # Interval settings
│   │   ├── LogicConfig.h        # Fuzzy logic parameters
│   │   ├── Secrets.h            # WiFi & Firebase credentials
│   │   └── Secrets.h.example    # Template credentials
│   └── managers/
│       ├── FirebaseManager.h
│       ├── LogicEngine.h
│       ├── PumpController.h
│       ├── ScheduleManager.h
│       ├── SensorManager.h
│       ├── TimeManager.h
│       └── WiFiManager.h
├── src/
│   ├── main.cpp
│   ├── FirebaseManager.cpp
│   ├── LogicEngine.cpp
│   ├── PumpController.cpp
│   ├── ScheduleManager.cpp
│   ├── SensorManager.cpp
│   ├── TimeManager.cpp
│   └── WiFiManager.cpp
├── diagram.json                 # Wokwi simulator config
├── wokwi.toml                   # Wokwi settings
├── platformio.ini               # PlatformIO config
├── FIRMWARE_DATA_REFERENCE.md   # Data structure reference
└── README.md
```

---

## 📝 Changelog

### v1.2.0 (2025-12-06)
- ✅ Added ScheduleManager for daily scheduled watering
- ✅ Added Moisture Threshold emergency watering
- ✅ Added Watering Source tracking (Manual/Fuzzy/Scheduled/Moisture)
- ✅ Added firmware version to device info
- ✅ Added last_scheduled_run tracking with completion status
- ✅ Improved mode switching (auto-stop pump when switching to manual)
- ✅ Added 30-second heartbeat for lastSeenAt

### v1.1.0
- ✅ Fuzzy Logic Engine for adaptive watering
- ✅ Firebase RTDB integration
- ✅ Manual/Auto mode control

### v1.0.0
- 🎉 Initial release
- ✅ Basic sensor reading
- ✅ Pump control via Firebase

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 👨‍💻 Author

**StrawSmart Team**

- GitHub: [@eerfinn](https://github.com/eerfinn)

---

*Last updated: 6 Desember 2025*
