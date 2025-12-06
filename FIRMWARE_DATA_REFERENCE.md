# 📡 StrawSmart Farming - Firmware Data Reference

Dokumen ini berisi rangkuman lengkap struktur data Firebase Realtime Database untuk komunikasi antara **ESP32 Firmware (Wokwi)** dan **Flutter App**.

---

## 🏗️ Struktur Database Firebase Realtime Database

```
devices/
└── {device_id}/                    # e.g., "greenhouse_node_001"
    ├── info/                       # Status & metadata perangkat
    ├── latest/                     # Data sensor terbaru
    ├── readings/                   # History pembacaan sensor
    ├── control/                    # Kontrol dari Flutter App
    └── schedule/                   # Jadwal penyiraman otomatis
```

---

## 📊 Detail Struktur Data

### 1. **Device Info** (`devices/{device_id}/info/`)

| Field              | Type    | Deskripsi                           | Contoh          |
|--------------------|---------|-------------------------------------|-----------------|
| `isOnline`         | boolean | Status koneksi perangkat            | `true`          |
| `lastSeenAt`       | int     | Unix timestamp detik terakhir aktif | `1764935218`    |
| `locationName`     | string  | Nama lokasi greenhouse              | `"Greenhouse Bedengan"` |
| `pumpActive`       | boolean | Status pompa sedang ON/OFF          | `false`         |
| `autoModeEnabled`  | boolean | Mode auto logic aktif               | `true`          |
| `uptimeSeconds`    | int     | Uptime ESP32 dalam detik            | `64854`         |
| `wifiSignalDbm`    | int     | Kekuatan sinyal WiFi                | `-81`           |
| `freeMemoryBytes`  | int     | Free heap memory ESP32              | `207152`        |

**Contoh JSON:**
```json
{
  "autoModeEnabled": true,
  "freeMemoryBytes": 207152,
  "isOnline": true,
  "lastSeenAt": 1764935218,
  "locationName": "Greenhouse Bedengan",
  "pumpActive": false,
  "uptimeSeconds": 64854,
  "wifiSignalDbm": -81
}
```

---

### 2. **Latest Telemetry** (`devices/{device_id}/latest/`)

Data sensor terbaru yang dibaca oleh ESP32.

| Field                | Type  | Deskripsi                              | Range/Unit      | Contoh |
|----------------------|-------|----------------------------------------|-----------------|--------|
| `temperatureCelsius` | float | Suhu udara dari DHT22                  | 0-50 °C         | `28`   |
| `humidityPercent`    | float | Kelembaban udara dari DHT22            | 0-100 %         | `60`   |
| `soilMoisturePercent`| int   | Kelembaban tanah (sudah dikonversi)    | 0-100 %         | `74`   |
| `soilMoistureRaw`    | int   | Nilai ADC raw sensor kelembaban tanah  | 0-4095 ADC      | `1381` |
| `lightIntensityRaw`  | int   | Nilai ADC raw sensor cahaya (LDR)      | 0-4095 ADC      | `1001` |
| `timestamp`          | int   | Unix timestamp detik pembacaan         | Unix seconds    | `1764935214` |

**Contoh JSON:**
```json
{
  "humidityPercent": 60,
  "lightIntensityRaw": 1001,
  "soilMoisturePercent": 74,
  "soilMoistureRaw": 1381,
  "temperatureCelsius": 28,
  "timestamp": 1764935214
}
```

**Konversi Soil Moisture:**
```cpp
// Di firmware ESP32:
// ADC range: 0 (basah) - 4095 (kering)
// Kalibrasi default: WET=0, DRY=4095
int soilMoisturePercent = map(rawADC, DRY_VALUE, WET_VALUE, 0, 100);
soilMoisturePercent = constrain(soilMoisturePercent, 0, 100);
```

---

### 3. **Readings History** (`devices/{device_id}/readings/`)

History pembacaan sensor dengan timestamp sebagai key.

| Key (Timestamp) | Value                               |
|-----------------|-------------------------------------|
| `1764935183`    | `{temperatureCelsius, humidityPercent, ...}` |
| `1764935214`    | `{temperatureCelsius, humidityPercent, ...}` |

**Interval:** ~30 detik per pembacaan

---

### 4. **Control** (`devices/{device_id}/control/`)

Kontrol pompa dari Flutter App ke ESP32.

| Field            | Type    | Deskripsi                               | Contoh       |
|------------------|---------|----------------------------------------|--------------|
| `pumpRequested`  | boolean | Request pompa ON (`true`) / OFF (`false`) | `false`    |
| `durationSeconds`| int     | Durasi pompa ON dalam detik             | `60`         |
| `mode`           | string  | Mode kontrol: `"auto"` / `"manual"`     | `"auto"`     |
| `updatedAt`      | int     | Timestamp terakhir diupdate             | `1764935185` |

**Contoh JSON:**
```json
{
  "durationSeconds": 60,
  "mode": "auto",
  "pumpRequested": false,
  "updatedAt": 1764935185
}
```

**Cara Flutter mengirim command:**
```dart
// Nyalakan pompa selama 60 detik
await controlRef.update({
  'pumpRequested': true,
  'durationSeconds': 60,
  'updatedAt': ServerValue.timestamp,
});

// Matikan pompa
await controlRef.update({
  'pumpRequested': false,
  'durationSeconds': 0,
  'updatedAt': ServerValue.timestamp,
});
```

---

### 5. **Watering Schedule** (`devices/{device_id}/schedule/`)

Jadwal penyiraman otomatis yang dikelola oleh ScheduleManager di firmware.

| Field                 | Type    | Deskripsi                        |
|-----------------------|---------|----------------------------------|
| `enabled`             | boolean | Jadwal aktif atau tidak          |
| `daily`               | array   | List jadwal harian               |
| `moisture_threshold`  | object  | Penyiraman berdasarkan kelembaban|
| `last_scheduled_run`  | object  | Info penyiraman terakhir         |

**Contoh JSON Lengkap:**
```json
{
  "enabled": true,
  "daily": [
    {
      "time": "06:00",
      "duration": 60,
      "enabled": true
    },
    {
      "time": "17:00",
      "duration": 45,
      "enabled": true
    }
  ],
  "moisture_threshold": {
    "enabled": true,
    "trigger_below": 30,
    "duration": 30
  },
  "last_scheduled_run": {
    "time": "",
    "duration": 0,
    "completed": false
  }
}
```

#### 5.1 Daily Schedule Item

| Field     | Type    | Deskripsi                    | Contoh   |
|-----------|---------|------------------------------|----------|
| `time`    | string  | Waktu penyiraman (HH:mm)     | `"06:00"`|
| `duration`| int     | Durasi penyiraman dalam detik| `60`     |
| `enabled` | boolean | Jadwal ini aktif             | `true`   |

#### 5.2 Moisture Threshold

Penyiraman otomatis berdasarkan kelembaban tanah.

| Field          | Type    | Deskripsi                               | Contoh |
|----------------|---------|----------------------------------------|--------|
| `enabled`      | boolean | Fitur threshold aktif                   | `true` |
| `trigger_below`| int     | Siram jika soil moisture di bawah (%)   | `30`   |
| `duration`     | int     | Durasi penyiraman dalam detik           | `30`   |

#### 5.3 Last Scheduled Run

| Field      | Type    | Deskripsi                    | Contoh   |
|------------|---------|------------------------------|----------|
| `time`     | string  | Waktu penyiraman terakhir    | `"06:00"`|
| `duration` | int     | Durasi penyiraman            | `60`     |
| `completed`| boolean | Berhasil selesai             | `true`   |

---

## 🌱 Batch Cultivation Data (Firestore)

Data batch tanam disimpan di **Cloud Firestore** (bukan Realtime Database).

### Collection: `cultivationBatches`

| Field                | Type      | Deskripsi                          | Contoh                    |
|----------------------|-----------|------------------------------------|---------------------------|
| `id`                 | string    | ID dokumen                         | `"OAnt7BZsGPPhdj2UKgvh"`  |
| `greenhouseId`       | string    | Device ID yang terkait             | `"greenhouse_node_001"`   |
| `name`               | string    | Nama batch                         | `"Batch Desember 2025"`   |
| `variety`            | string    | Varietas stroberi                  | `"california"`, `"festival"`, `"albion"` |
| `customVarietyName`  | string?   | Nama varietas custom (jika other)  | `null`                    |
| `plantCount`         | int       | Jumlah tanaman                     | `500`                     |
| `plantingDate`       | timestamp | Tanggal tanam                      | Firestore Timestamp       |
| `isActive`           | boolean   | Batch masih aktif                  | `true`                    |
| `harvestDate`        | timestamp?| Tanggal panen (jika sudah)         | `null`                    |
| `totalHarvestKg`     | double?   | Total hasil panen (kg)             | `null`                    |
| `notes`              | string?   | Catatan tambahan                   | `"Ini keren"`             |
| `photoUrls`          | array     | URL foto batch                     | `[]`                      |
| `phaseSettings`      | map       | Pengaturan per fase                | `{...}`                   |
| `phaseTransitions`   | map       | Tanggal transisi fase manual       | `{}`                      |
| `currentPhaseOverride`| string?  | Override fase manual               | `null`                    |
| `createdAt`          | timestamp | Tanggal dibuat                     | Firestore Timestamp       |
| `updatedAt`          | timestamp | Tanggal terakhir diupdate          | Firestore Timestamp       |

---

## 🌿 Fase Pertumbuhan Stroberi

### Enum: `GrowthPhase`

| Fase        | Label       | Emoji | Durasi Default | Deskripsi                          |
|-------------|-------------|-------|----------------|-------------------------------------|
| `seedling`  | Pembibitan  | 🌱    | 14 hari        | Fase awal, fokus penguatan akar     |
| `vegetative`| Vegetatif   | 🌿    | 28 hari        | Pertumbuhan daun dan batang aktif   |
| `flowering` | Berbunga    | 🌸    | 21 hari        | Tanaman mulai berbunga              |
| `fruiting`  | Berbuah     | 🍓    | 21 hari        | Buah terbentuk dan membesar         |
| `harvesting`| Panen       | 🎉    | 30 hari        | Buah matang siap dipanen            |

**Total siklus: ~114 hari (±4 bulan)**

---

## 💧 Kebutuhan Penyiraman Per Fase

| Fase        | Frekuensi/Hari | Durasi (detik) | Kelembaban Tanah Ideal |
|-------------|----------------|----------------|------------------------|
| Seedling    | 3x             | 20             | 70-85%                 |
| Vegetative  | 2x             | 45             | 60-75%                 |
| Flowering   | 2x             | 40             | 55-70%                 |
| Fruiting    | 2x             | 35             | 50-65%                 |
| Harvesting  | 1x             | 30             | 45-60%                 |

---

## 🌡️ Parameter Ideal Lingkungan

### Default Guidance Service Parameters

| Parameter           | Min    | Ideal    | Max    | Critical Min | Critical Max |
|---------------------|--------|----------|--------|--------------|--------------|
| Suhu (°C)           | 24     | 24-28    | 28     | 18           | 32           |
| Kelembaban Udara (%)| 55     | 55-70    | 70     | 40           | 85           |
| Kelembaban Tanah (%)| 35     | 35-45    | 45     | 25           | 60           |
| Cahaya (ADC)        | 1200   | 1200-1600| 1600   | 800          | -            |

### Kebutuhan Per Fase

| Fase        | Suhu (°C)  | Kelembaban Udara (%) | Kelembaban Tanah (%) | Cahaya (jam/hari) |
|-------------|------------|----------------------|----------------------|-------------------|
| Seedling    | 18-24      | 85-95                | 70-85                | 8                 |
| Vegetative  | 17-25      | 75-85                | 60-75                | 12                |
| Flowering   | 18-25      | 70-80                | 55-70                | 14                |
| Fruiting    | 18-26      | 65-75                | 50-65                | 14                |
| Harvesting  | 18-26      | 60-70                | 45-60                | 12                |

---

## 🍓 Varietas Stroberi

| Enum Value     | Label         | Hari Hingga Panen | Deskripsi                         |
|----------------|---------------|-------------------|-----------------------------------|
| `california`   | California    | 90                | Paling populer, buah besar, manis |
| `sweetCharlie` | Sweet Charlie | 85                | Sangat manis, cocok dataran tinggi|
| `festival`     | Festival      | 95                | Tahan penyakit, produksi tinggi   |
| `chandler`     | Chandler      | 100               | Buah besar, cocok komersial       |
| `albion`       | Albion        | 80                | Berbuah sepanjang tahun           |
| `other`        | Lainnya       | 90                | Varietas custom                   |

---

## 📡 Deteksi Online/Offline

Flutter menggunakan kombinasi beberapa metode untuk deteksi status online:

1. **Primary:** `lastReceivedTime` - Waktu lokal Flutter menerima data dari Firebase
2. **Fallback:** `lastSeenAt` dari device info
3. **Fallback:** `timestamp` dari latest telemetry
4. **Additional:** Perubahan status pump (`pumpActive`)

**Threshold:** Device dianggap **offline** jika tidak ada data baru dalam **90 detik**

```dart
bool get isDeviceOnline {
  if (lastReceivedTime != null) {
    final diffSeconds = DateTime.now().difference(lastReceivedTime!).inSeconds;
    return diffSeconds <= 90;
  }
  // ... fallback logic
}
```

---

## 🔄 Flow Komunikasi

### 1. Sensor Data Flow (ESP32 → Firebase → Flutter)

```
ESP32 reads sensors
    ↓
ESP32 writes to Firebase RTDB
    • devices/{id}/latest/
    • devices/{id}/readings/{timestamp}/
    • devices/{id}/info/ (update lastSeenAt, pumpActive, etc.)
    ↓
Flutter StreamProvider subscribes
    ↓
UI updates automatically
```

### 2. Pump Control Flow (Flutter → Firebase → ESP32)

```
User taps pump button in Flutter
    ↓
Flutter writes to Firebase RTDB
    • devices/{id}/control/pumpRequested = true
    • devices/{id}/control/durationSeconds = 60
    ↓
ESP32 listens to control/ changes
    ↓
ESP32 activates pump relay
    ↓
ESP32 updates info/pumpActive = true
    ↓
Flutter receives pumpActive change
    ↓
UI shows pump status ON
```

### 3. Schedule Flow (ScheduleManager di ESP32)

```
ScheduleManager checks time every loop
    ↓
If current time matches daily[].time AND enabled
    ↓
Activate pump for daily[].duration seconds
    ↓
Update last_scheduled_run/
    ↓
(If moisture_threshold.enabled)
    Check soilMoisturePercent < trigger_below
    If true → activate pump for moisture_threshold.duration
```

---

## 📱 Device IDs Terdaftar

| Device ID            | Nama                   | Deskripsi     |
|----------------------|------------------------|---------------|
| `greenhouse_node_001`| Greenhouse Bedengan    | Kebun Utama   |
| `greenhouse_node_002`| Greenhouse Pakisaji    | Kebun Kedua   |
| `greenhouse_node_003`| Greenhouse Batu        | Kebun Ketiga  |

---

## 🔧 Contoh Implementasi Firmware (ESP32)

### Menulis Data Sensor

```cpp
void publishSensorData() {
    String path = "devices/" + deviceId + "/latest";
    
    FirebaseJson json;
    json.set("temperatureCelsius", temperature);
    json.set("humidityPercent", humidity);
    json.set("soilMoisturePercent", soilMoisturePercent);
    json.set("soilMoistureRaw", soilMoistureRaw);
    json.set("lightIntensityRaw", lightRaw);
    json.set("timestamp", getUnixTimestamp());
    
    Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json);
}
```

### Update Device Info

```cpp
void updateDeviceInfo() {
    String path = "devices/" + deviceId + "/info";
    
    FirebaseJson json;
    json.set("isOnline", true);
    json.set("lastSeenAt", getUnixTimestamp());
    json.set("pumpActive", isPumpOn);
    json.set("autoModeEnabled", autoModeEnabled);
    json.set("uptimeSeconds", millis() / 1000);
    json.set("wifiSignalDbm", WiFi.RSSI());
    json.set("freeMemoryBytes", ESP.getFreeHeap());
    json.set("locationName", locationName);
    
    Firebase.RTDB.setJSON(&fbdo, path.c_str(), &json);
}
```

### Listen Control Commands

```cpp
void listenControlChanges() {
    String path = "devices/" + deviceId + "/control";
    
    if (Firebase.RTDB.readStream(&fbdo)) {
        if (fbdo.dataType() == "json") {
            FirebaseJson json = fbdo.jsonObject();
            
            bool pumpRequested;
            int duration;
            String mode;
            
            json.get(pumpRequested, "pumpRequested");
            json.get(duration, "durationSeconds");
            json.get(mode, "mode");
            
            if (pumpRequested && mode == "manual") {
                activatePump(duration);
            } else if (!pumpRequested) {
                deactivatePump();
            }
        }
    }
}
```

### Schedule Manager Check

```cpp
void checkSchedule() {
    if (!scheduleEnabled) return;
    
    String currentTime = getCurrentTimeHHMM(); // e.g., "06:00"
    
    for (int i = 0; i < dailyScheduleCount; i++) {
        if (dailySchedule[i].enabled && 
            dailySchedule[i].time == currentTime &&
            !hasRunToday(i)) {
            
            activatePump(dailySchedule[i].duration);
            updateLastScheduledRun(currentTime, dailySchedule[i].duration);
        }
    }
    
    // Check moisture threshold
    if (moistureThreshold.enabled && 
        soilMoisturePercent < moistureThreshold.triggerBelow) {
        activatePump(moistureThreshold.duration);
    }
}
```

---

## 📝 Catatan Penting

1. **Timestamp:** Semua timestamp menggunakan **Unix seconds** (bukan milliseconds)
2. **Interval Update:** Sensor data diupdate setiap **~30 detik**
3. **Offline Threshold:** Device dianggap offline jika tidak update dalam **90 detik**
4. **Mode Auto:** Jika `control/mode = "auto"`, ESP32 menggunakan logika otomatis berdasarkan sensor
5. **Mode Manual:** Jika `control/mode = "manual"`, ESP32 hanya merespons `pumpRequested`
6. **Schedule:** Dikelola sepenuhnya oleh firmware, Flutter hanya membaca/display

---

## 🔗 Quick Reference

### Firebase RTDB Paths

```
devices/{device_id}/info                    → Device status
devices/{device_id}/latest                  → Current sensor data
devices/{device_id}/readings/{timestamp}    → Sensor history
devices/{device_id}/control                 → Pump control commands
devices/{device_id}/schedule                → Watering schedule
devices/{device_id}/schedule/daily          → Daily schedule list
devices/{device_id}/schedule/moisture_threshold → Moisture-based watering
devices/{device_id}/schedule/last_scheduled_run → Last scheduled watering info
```

### Firestore Collections

```
cultivationBatches/{batch_id}   → Batch cultivation data
devices/{device_id}             → Device metadata (name, description)
users/{user_id}                 → User profiles
notifications/{notification_id} → Push notifications
```

---

*Dokumen ini diupdate terakhir: 6 Desember 2025*
