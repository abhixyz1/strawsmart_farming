/// Enum untuk role user dalam sistem StrawSmart Farming
/// 
/// Permission Matrix:
/// | Fitur                  | Admin | Owner | Petani |
/// |------------------------|-------|-------|--------|
/// | Development Tools      |   ✅  |   ❌  |   ❌   |
/// | Dropdown Greenhouse    |   ✅  |   ✅  |   ❌   |
/// | Kontrol Pompa (ON/OFF) |   ✅  |   ❌  |   ✅   |
/// | Lihat Status Pompa     |   ✅  |   ✅  |   ✅   |
/// | Watering Schedule      |   ✅  |   ❌  |   ✅   |
/// | Monitoring & Sensor    |   ✅  |   ✅  |   ✅   |
/// 
/// - [admin]: Admin global, full akses semua greenhouse & fitur
/// - [owner]: Pemilik greenhouse, monitoring only, tidak bisa kontrol
/// - [petani]: Petani, 1 greenhouse saja, full kontrol operasional
enum UserRole {
  admin,
  owner,
  petani;

  /// Parse string ke UserRole, default ke petani jika tidak valid
  /// Normalize: petani1, petani2, dll → petani
  static UserRole fromString(String? value) {
    if (value == null) return UserRole.petani;
    
    final normalized = value.toLowerCase().trim();
    
    // Normalize petani variants (petani1, petani2, etc.) → petani
    if (normalized.startsWith('petani')) {
      return UserRole.petani;
    }
    
    return UserRole.values.firstWhere(
      (role) => role.name == normalized,
      orElse: () => UserRole.petani,
    );
  }

  /// Label untuk ditampilkan di UI
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.owner:
        return 'Pemilik';
      case UserRole.petani:
        return 'Petani';
    }
  }

  // ==================== PERMISSION CHECKS ====================

  /// Cek apakah role bisa memilih greenhouse (dropdown visible)
  /// Admin & Owner: bisa pilih, Petani: 1 GH saja (auto-select)
  bool get canSelectGreenhouse => this == UserRole.admin || this == UserRole.owner;

  /// Cek apakah role bisa kontrol pompa (ON/OFF manual)
  /// Admin & Petani: bisa kontrol, Owner: hanya lihat status
  bool get canControlPump => this == UserRole.admin || this == UserRole.petani;

  /// Cek apakah role bisa manage watering schedule
  /// Admin & Petani: bisa CRUD jadwal, Owner: tidak bisa
  bool get canManageSchedule => this == UserRole.admin || this == UserRole.petani;

  /// Cek apakah role bisa akses Development Tools
  /// Hanya Admin
  bool get canAccessDevTools => this == UserRole.admin;

  /// Cek apakah role bisa manage multiple greenhouses
  bool get canManageMultipleGreenhouses => this == UserRole.admin || this == UserRole.owner;

  /// Cek apakah role bisa assign user ke greenhouse
  /// Hanya Admin
  bool get canAssignUsers => this == UserRole.admin;

  /// Deskripsi singkat role
  String get description {
    switch (this) {
      case UserRole.admin:
        return 'Akses penuh ke semua fitur dan greenhouse';
      case UserRole.owner:
        return 'Monitoring greenhouse';
      case UserRole.petani:
        return 'Kontrol penuh 1 greenhouse yang ditugaskan';
    }
  }
}
