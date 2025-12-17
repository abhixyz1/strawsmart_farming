import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/greenhouse.dart';
import '../../models/greenhouse_membership.dart';
import '../../models/user_role.dart';
import '../auth/auth_repository.dart';
import '../auth/user_profile_repository.dart';

/// Repository untuk mengelola data Greenhouse dan Membership
///
/// Struktur Firestore:
/// - devices/{deviceId} → metadata greenhouse (name, description, deviceId)
/// - users/{uid}/memberships/{deviceId} → relasi user ke greenhouse
class GreenhouseRepository {
  GreenhouseRepository(this._firestore, this._database);

  final FirebaseFirestore _firestore;
  final FirebaseDatabase _database;

  // ==================== GREENHOUSE CRUD ====================
  // Menggunakan collection 'devices' sesuai struktur Firestore

  /// Watch semua greenhouse/devices (untuk admin)
  Stream<List<Greenhouse>> watchAllGreenhouses() {
    return _firestore.collection('devices').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Greenhouse(
          id: doc.id,
          name: data['name'] as String? ?? 'Greenhouse',
          location: data['location'] as String?,
          description: data['description'] as String?,
          deviceId: data['deviceId'] as String? ?? doc.id,
          imageUrl: data['imageUrl'] as String?,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        );
      }).toList();
    });
  }

  /// Get greenhouse by ID
  Future<Greenhouse?> getGreenhouse(String greenhouseId) async {
    final doc = await _firestore.collection('devices').doc(greenhouseId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    return Greenhouse(
      id: doc.id,
      name: data['name'] as String? ?? 'Greenhouse',
      location: data['location'] as String?,
      description: data['description'] as String?,
      deviceId: data['deviceId'] as String? ?? doc.id,
      imageUrl: data['imageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Watch single greenhouse
  Stream<Greenhouse?> watchGreenhouse(String greenhouseId) {
    return _firestore.collection('devices').doc(greenhouseId).snapshots().map((
      doc,
    ) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      return Greenhouse(
        id: doc.id,
        name: data['name'] as String? ?? 'Greenhouse',
        location: data['location'] as String?,
        description: data['description'] as String?,
        deviceId: data['deviceId'] as String? ?? doc.id,
        imageUrl: data['imageUrl'] as String?,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
    });
  }

  /// Create greenhouse baru
  Future<String> createGreenhouse(Greenhouse greenhouse) async {
    final docRef = await _firestore
        .collection('devices')
        .add(greenhouse.toFirestoreCreate());
    return docRef.id;
  }

  /// Update greenhouse
  Future<void> updateGreenhouse(Greenhouse greenhouse) async {
    await _firestore
        .collection('devices')
        .doc(greenhouse.id)
        .update(greenhouse.toFirestore());
  }

  /// Delete greenhouse
  Future<void> deleteGreenhouse(String greenhouseId) async {
    await _firestore.collection('devices').doc(greenhouseId).delete();
  }

  // ==================== MEMBERSHIP CRUD ====================

  /// Watch membership list untuk user tertentu
  Stream<List<GreenhouseMembership>> watchUserMemberships(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('memberships')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => GreenhouseMembership.fromFirestore(
                  doc.id,
                  userId,
                  doc.data(),
                ),
              )
              .toList();
        });
  }

  /// Get membership list untuk user tertentu (one-time)
  Future<List<GreenhouseMembership>> getUserMemberships(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('memberships')
        .get();
    return snapshot.docs
        .map(
          (doc) =>
              GreenhouseMembership.fromFirestore(doc.id, userId, doc.data()),
        )
        .toList();
  }

  /// Add membership (assign user ke greenhouse/device)
  Future<void> addMembership({
    required String userId,
    required String greenhouseId,
    required UserRole role,
    required Greenhouse greenhouse,
  }) async {
    final membership = GreenhouseMembership(
      greenhouseId: greenhouseId,
      userId: userId,
      role: role,
      greenhouseName: greenhouse.name,
      greenhouseLocation: greenhouse.location,
      deviceId: greenhouse.deviceId,
    );

    // Add to user's memberships subcollection
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('memberships')
        .doc(greenhouseId)
        .set(membership.toFirestoreCreate());

    // Mirror to device's members (for security rules - optional)
    await _firestore
        .collection('devices')
        .doc(greenhouseId)
        .collection('members')
        .doc(userId)
        .set({'role': role.name, 'joinedAt': FieldValue.serverTimestamp()});

    debugPrint(
      '[GreenhouseRepo] Added membership: $userId -> $greenhouseId ($role)',
    );
  }

  /// Remove membership
  Future<void> removeMembership({
    required String userId,
    required String greenhouseId,
  }) async {
    // Remove from user's memberships
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('memberships')
        .doc(greenhouseId)
        .delete();

    // Remove from device's members
    await _firestore
        .collection('devices')
        .doc(greenhouseId)
        .collection('members')
        .doc(userId)
        .delete();

    debugPrint('[GreenhouseRepo] Removed membership: $userId -> $greenhouseId');
  }

  /// Update membership role
  Future<void> updateMembershipRole({
    required String userId,
    required String greenhouseId,
    required UserRole newRole,
  }) async {
    // Update user's membership
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('memberships')
        .doc(greenhouseId)
        .update({
          'role': newRole.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    // Update device's member record
    await _firestore
        .collection('devices')
        .doc(greenhouseId)
        .collection('members')
        .doc(userId)
        .update({'role': newRole.name});
  }

  // ==================== DEVICE INFO FROM RTDB ====================

  /// Get device info dari RTDB berdasarkan deviceId
  Future<Map<String, dynamic>?> getDeviceInfo(String deviceId) async {
    final snapshot = await _database.ref('devices/$deviceId/info').get();
    if (!snapshot.exists) return null;
    final value = snapshot.value;
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  /// Watch device online status
  Stream<bool> watchDeviceOnlineStatus(String deviceId) {
    return _database
        .ref('devices/$deviceId/info/isOnline')
        .onValue
        .map((event) => event.snapshot.value == true);
  }

  // ==================== SYNC GREENHOUSE FROM RTDB ====================

  /// Sync greenhouse data dari RTDB ke Firestore (devices collection)
  /// Berguna untuk migrasi atau initial setup
  Future<void> syncGreenhousesFromRTDB() async {
    try {
      final snapshot = await _database.ref('devices').get();
      if (!snapshot.exists) return;

      final devices = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in devices.entries) {
        final deviceId = entry.key.toString();
        final deviceData = entry.value as Map<dynamic, dynamic>;
        final info = deviceData['info'] as Map<dynamic, dynamic>?;

        if (info != null) {
          final locationName = info['locationName']?.toString() ?? deviceId;

          // Check if device doc exists in Firestore
          final existingDoc = await _firestore
              .collection('devices')
              .doc(deviceId)
              .get();

          if (!existingDoc.exists) {
            // Create new device doc
            await _firestore.collection('devices').doc(deviceId).set({
              'name': locationName.split(' - ').first,
              'location': locationName.contains(' - ')
                  ? locationName.split(' - ').last
                  : null,
              'deviceId': deviceId,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            debugPrint('[GreenhouseRepo] Created device doc: $deviceId');
          }
        }
      }
    } catch (e) {
      debugPrint('[GreenhouseRepo] Error syncing greenhouses: $e');
    }
  }
}

// ==================== PROVIDERS ====================

final greenhouseRepositoryProvider = Provider<GreenhouseRepository>((ref) {
  return GreenhouseRepository(
    FirebaseFirestore.instance,
    FirebaseDatabase.instance,
  );
});

/// Provider untuk daftar semua greenhouse (untuk admin)
final allGreenhousesProvider = StreamProvider.autoDispose<List<Greenhouse>>((
  ref,
) {
  final repo = ref.watch(greenhouseRepositoryProvider);
  return repo.watchAllGreenhouses();
});

/// Provider untuk daftar membership user yang sedang login
final userMembershipsProvider =
    StreamProvider.autoDispose<List<GreenhouseMembership>>((ref) {
      final authState = ref.watch(authStateProvider);
      final user = authState.valueOrNull;
      if (user == null) return Stream.value([]);

      final repo = ref.watch(greenhouseRepositoryProvider);
      return repo.watchUserMemberships(user.uid);
    });

/// Provider untuk greenhouse yang tersedia untuk user (berdasarkan role & membership)
/// SEMUA role (Admin, Owner, Petani) sekarang menggunakan membership system
/// Admin tidak lagi otomatis dapat akses ke semua greenhouse - harus di-assign juga
final availableGreenhousesProvider =
    Provider.autoDispose<AsyncValue<List<GreenhouseMembership>>>((ref) {
      final profile = ref.watch(currentUserProfileProvider);
      final memberships = ref.watch(userMembershipsProvider);

      // Jika profile belum load, return loading
      if (profile.isLoading) return const AsyncValue.loading();
      if (profile.hasError)
        return AsyncValue.error(profile.error!, profile.stackTrace!);

      final userProfile = profile.valueOrNull;
      if (userProfile == null) return const AsyncValue.data([]);

      debugPrint(
        '[AvailableGreenhouses] User: ${userProfile.id}, Role: ${userProfile.role}',
      );

      // Semua role (Admin/Owner/Petani): gunakan membership system
      // Admin tidak lagi otomatis akses semua greenhouse
      if (memberships.isLoading) return const AsyncValue.loading();
      if (memberships.hasError) {
        return AsyncValue.error(memberships.error!, memberships.stackTrace!);
      }

      final userMemberships = memberships.valueOrNull ?? [];
      debugPrint(
        '[AvailableGreenhouses] ${userProfile.role.label} - ${userMemberships.length} assigned greenhouses',
      );

      return AsyncValue.data(userMemberships);
    });

/// Provider untuk selected greenhouse ID (dengan auto-select logic)
final selectedGreenhouseIdProvider =
    StateNotifierProvider.autoDispose<SelectedGreenhouseNotifier, String?>((
      ref,
    ) {
      return SelectedGreenhouseNotifier(ref);
    });

class SelectedGreenhouseNotifier extends StateNotifier<String?> {
  SelectedGreenhouseNotifier(this._ref) : super(null) {
    _initialize();
  }

  final Ref _ref;
  bool _initialized = false;

  void _initialize() {
    // Listen to profile changes for initial value
    _ref.listen<AsyncValue<UserProfile?>>(currentUserProfileProvider, (
      prev,
      next,
    ) {
      final profile = next.valueOrNull;
      if (profile != null && !_initialized) {
        // Set initial value from profile's currentGreenhouseId
        if (profile.currentGreenhouseId != null) {
          state = profile.currentGreenhouseId;
          _initialized = true;
          debugPrint('[SelectedGreenhouse] Init from profile: $state');
        }
      }
    });

    // Listen to available greenhouses for auto-select
    _ref.listen<
      AsyncValue<List<GreenhouseMembership>>
    >(availableGreenhousesProvider, (prev, next) {
      final memberships = next.valueOrNull;
      if (memberships != null && memberships.isNotEmpty && state == null) {
        // Auto-select first greenhouse if none selected
        debugPrint(
          '[SelectedGreenhouse] Auto-selecting first: ${memberships.first.greenhouseId}',
        );
        _selectGreenhouse(memberships.first.greenhouseId);
      } else if (memberships != null && memberships.length == 1) {
        // Force select if only one greenhouse (for petani)
        if (state != memberships.first.greenhouseId) {
          debugPrint(
            '[SelectedGreenhouse] Force selecting single: ${memberships.first.greenhouseId}',
          );
          _selectGreenhouse(memberships.first.greenhouseId);
        }
      }
    });
  }

  /// Select greenhouse dan persist ke Firestore
  Future<void> selectGreenhouse(String greenhouseId) async {
    await _selectGreenhouse(greenhouseId);
  }

  Future<void> _selectGreenhouse(String greenhouseId) async {
    state = greenhouseId;
    _initialized = true;

    // Persist to Firestore
    final authState = _ref.read(authStateProvider);
    final user = authState.valueOrNull;
    if (user != null) {
      try {
        final repo = _ref.read(userProfileRepositoryProvider);
        await repo.updateCurrentGreenhouse(user.uid, greenhouseId);
      } catch (e) {
        debugPrint('[SelectedGreenhouse] Failed to persist: $e');
      }
    }
  }

  /// Clear selection (e.g., on logout)
  void clear() {
    state = null;
    _initialized = false;
  }
}

/// Provider untuk selected greenhouse detail (dengan deviceId)
final selectedGreenhouseProvider = Provider.autoDispose<GreenhouseMembership?>((
  ref,
) {
  final selectedId = ref.watch(selectedGreenhouseIdProvider);
  final available = ref.watch(availableGreenhousesProvider);

  if (selectedId == null) return null;

  final memberships = available.valueOrNull ?? [];
  try {
    return memberships.firstWhere((m) => m.greenhouseId == selectedId);
  } catch (_) {
    return memberships.isNotEmpty ? memberships.first : null;
  }
});

/// Provider untuk deviceId dari greenhouse yang dipilih
/// Ini yang akan digunakan oleh repository lain (dashboard, monitoring, dll)
final activeDeviceIdProvider = Provider.autoDispose<String?>((ref) {
  final selected = ref.watch(selectedGreenhouseProvider);
  return selected?.deviceId;
});

/// Provider untuk cek apakah user perlu memilih greenhouse (dropdown visible)
/// Dropdown hanya muncul jika:
/// - User memiliki permission untuk pilih greenhouse (Admin/Owner)
/// - DAN ada lebih dari 1 pilihan (available.length > 1)
/// Petani tidak pernah lihat dropdown (1 GH auto-select)
final shouldShowGreenhouseSelectorProvider = Provider.autoDispose<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  final available = ref.watch(availableGreenhousesProvider).valueOrNull ?? [];

  if (profile == null) return false;
  if (available.isEmpty) return false;

  // Gunakan permission dari UserRole
  if (!profile.role.canSelectGreenhouse) {
    // Petani: tidak boleh pilih, 1 GH auto-select
    return false;
  }

  // Admin & Owner: tampilkan dropdown HANYA jika ada >1 pilihan
  // Jika cuma 1, tidak perlu dropdown (tidak ada yang bisa dipilih)
  return available.length > 1;
});

/// Provider untuk status greenhouse (apakah user punya akses)
final greenhouseAccessStateProvider = Provider<GreenhouseAccessState>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  final available = ref.watch(availableGreenhousesProvider);

  if (profile.isLoading || available.isLoading) {
    return GreenhouseAccessState.loading;
  }

  if (profile.hasError || available.hasError) {
    return GreenhouseAccessState.error;
  }

  final memberships = available.valueOrNull ?? [];
  if (memberships.isEmpty) {
    return GreenhouseAccessState.noAccess;
  }

  return GreenhouseAccessState.hasAccess;
});

enum GreenhouseAccessState { loading, hasAccess, noAccess, error }
