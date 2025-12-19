# 🍓 StrawSmart Farming

**Solusi Cerdas Manajemen Greenhouse Stroberi**

> **Project Based Learning (PBL) Semester 5**
> SIB 3F - Politeknik Negeri Malang

---

## 👥 Anggota Kelompok

| NAMA | NIM |
| :--- | :--- |
| **M. Abhinaya Zurfa** | 2341760186 |
| **Erfin Jauhari Dwi Brian** | 2341760088 |
| **Fatima Sitta M.** | 2341760167 |
| **Jami'atul Afifah** | 2341760102 |
| **Syaqira Nazaretna** | 2341760123 |

---

## 📖 Tentang Proyek

**StrawSmart Farming** adalah aplikasi mobile berbasis Flutter yang dikembangkan untuk memodernisasi pengelolaan pertanian stroberi. Aplikasi ini terhubung dengan sistem IoT di *greenhouse* untuk memberikan kontrol presisi dan pemantauan *real-time* kepada petani.

Tujuan utama proyek ini adalah meningkatkan hasil panen dan efisiensi penggunaan sumber daya (air & nutrisi) melalui otomasi cerdas.

### ✨ Fitur Utama

*   **📊 Real-time Dashboard**: Visualisasi data sensor (Suhu, Kelembaban Udara, Kelembaban Tanah) secara langsung.
*   **🚿 Smart Irrigation Control**:
    *   **Mode Manual**: Kontrol pompa air jarak jauh.
    *   **Mode Otomatis**: Penyiraman berbasis *Fuzzy Logic* atau jadwal (Schedule).
*   **🌱 Batch Management**: Pencatatan siklus tanam dari fase vegetatif, generatif, hingga panen.
*   **📈 Reporting System**:
    *   Grafik pertumbuhan tanaman.
    *   Ekspor laporan harian/bulanan ke **PDF** dan **CSV**.
*   **🔔 Smart Notifications**: Pemberitahuan dini untuk anomali suhu atau jadwal penyiraman.

---

## 🛠️ Teknologi yang Digunakan

*   **Mobile Framework**: [Flutter](https://flutter.dev/) (Dart SDK 3.x)
*   **State Management**: [Riverpod 2.5](https://riverpod.dev/) (Generator)
*   **Backend & Database**:
    *   Firebase Authentication (Login/Register)
    *   Cloud Firestore (Data Batch & User)
    *   Realtime Database (Data Sensor IoT)
*   **Push Notifications**: Firebase Cloud Messaging (FCM)
*   **Architecture**: MVVM / Clean Architecture (Feature-first)

---

## 🚀 Panduan Instalasi

Ikuti langkah-langkah di bawah ini untuk menjalankan aplikasi di komputer lokal Anda.

### Prasyarat
Pastikan Anda telah menginstal:
1.  **Flutter SDK** (Versi stable terbaru)
2.  **Git**
3.  **Visual Studio Code** atau **Android Studio**
4.  Koneksi internet (untuk mengunduh dependencies)

### Langkah-langkah

1.  **Clone Repository**
    Buka terminal dan jalankan perintah berikut:
    ```bash
    git clone https://github.com/username/strawsmart_farming.git
    cd strawsmart_farming
    ```

2.  **Install Dependencies**
    Unduh paket-paket Dart yang diperlukan:
    ```bash
    flutter pub get
    ```

3.  **Konfigurasi Firebase**
    *   Pastikan file `google-services.json` (untuk Android) ada di folder `android/app/`.
    *   Pastikan file `firebase_options.dart` ada di folder `lib/`.
    *(Hubungi anggota tim untuk file kredensial)*.

4.  **Jalankan Aplikasi**
    Sambungkan perangkat Android atau gunakan Emulator, lalu jalankan:
    ```bash
    flutter run
    ```
