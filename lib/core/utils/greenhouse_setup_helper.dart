import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../models/user_role.dart';

/// Utility class untuk setup dan migrasi data greenhouse
/// 
/// Struktur Firestore:
/// - devices/{deviceId} → metadata greenhouse (name, description, deviceId)
/// - users/{uid}/memberships/{deviceId} → relasi user ke greenhouse
class GreenhouseSetupHelper {
  GreenhouseSetupHelper({
    FirebaseFirestore? firestore,
    FirebaseDatabase? database,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _database = database ?? FirebaseDatabase.instance;

  final FirebaseFirestore _firestore;
  final FirebaseDatabase _database;

  /// Sync greenhouse dari RTDB ke Firestore (devices collection)
  /// Membuat document di devices collection untuk setiap device di RTDB
  Future<List<String>> syncGreenhousesFromRTDB() async {
    final createdIds = <String>[];

    try {
      final snapshot = await _database.ref('devices').get();
      if (!snapshot.exists) {
        debugPrint('[SetupHelper] No devices found in RTDB');
        return createdIds;
      }

      final devices = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in devices.entries) {
        final deviceId = entry.key.toString();
        final deviceData = entry.value as Map<dynamic, dynamic>;
        final info = deviceData['info'] as Map<dynamic, dynamic>?;

        if (info != null) {
          final locationName = info['locationName']?.toString() ?? deviceId;

          // Parse name dan location dari locationName
          // Format: "Greenhouse 1 - Pakisaji"
          String name;
          String? location;

          if (locationName.contains(' - ')) {
            final parts = locationName.split(' - ');
            name = parts.first.trim();
            location = parts.length > 1 ? parts.last.trim() : null;
          } else {
            name = locationName;
            location = null;
          }

          // Cek apakah device doc sudah ada di Firestore
          final existingDoc = await _firestore
              .collection('devices')
              .doc(deviceId)
              .get();

          if (!existingDoc.exists) {
            // Create device doc dengan ID = deviceId
            await _firestore.collection('devices').doc(deviceId).set({
              'name': name,
              'location': location,
              'deviceId': deviceId,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            createdIds.add(deviceId);
            debugPrint('[SetupHelper] Created device doc: $name ($deviceId)');
          } else {
            debugPrint('[SetupHelper] Device doc already exists: $deviceId');
          }
        }
      }
    } catch (e) {
      debugPrint('[SetupHelper] Error syncing greenhouses: $e');
    }

    return createdIds;
  }

  /// Setup user sebagai admin
  Future<void> setUserAsAdmin(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'role': UserRole.admin.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[SetupHelper] User $userId set as admin');
  }

  /// Setup user sebagai owner
  Future<void> setUserAsOwner(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'role': UserRole.owner.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[SetupHelper] User $userId set as owner');
  }

  /// Setup user sebagai petani
  Future<void> setUserAsPetani(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'role': UserRole.petani.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[SetupHelper] User $userId set as petani');
  }

  /// Assign user ke greenhouse/device
  Future<void> assignUserToGreenhouse({
    required String userId,
    required String greenhouseId,
    required UserRole role,
  }) async {
    // Get device data dari devices collection
    final deviceDoc = await _firestore.collection('devices').doc(greenhouseId).get();
    if (!deviceDoc.exists) {
      throw Exception('Device $greenhouseId not found');
    }

    final deviceData = deviceDoc.data()!;

    // Add to user's memberships subcollection
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('memberships')
        .doc(greenhouseId)
        .set({
      'role': role.name,
      'greenhouseName': deviceData['name'],
      'greenhouseLocation': deviceData['location'],
      'deviceId': deviceData['deviceId'] ?? greenhouseId,
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Mirror to device's members subcollection (optional, for security rules)
    await _firestore
        .collection('devices')
        .doc(greenhouseId)
        .collection('members')
        .doc(userId)
        .set({
      'role': role.name,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[SetupHelper] Assigned user $userId to device $greenhouseId as ${role.name}');
  }

  /// Remove user dari greenhouse/device
  Future<void> removeUserFromGreenhouse({
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

    debugPrint('[SetupHelper] Removed user $userId from device $greenhouseId');
  }

  /// Setup lengkap untuk development/testing
  /// Assign user ke semua greenhouse/device yang ada
  Future<void> setupDevelopmentData(String userId) async {
    debugPrint('[SetupHelper] Starting development setup for user: $userId');

    // 1. Sync greenhouses dari RTDB
    final createdDeviceIds = await syncGreenhousesFromRTDB();
    debugPrint('[SetupHelper] Synced ${createdDeviceIds.length} devices');

    // 2. Get semua devices
    final devices = await _firestore.collection('devices').get();

    // 3. Set user sebagai owner
    await setUserAsOwner(userId);

    // 4. Assign user ke semua devices sebagai owner
    for (final device in devices.docs) {
      try {
        await assignUserToGreenhouse(
          userId: userId,
          greenhouseId: device.id,
          role: UserRole.owner,
        );
      } catch (e) {
        debugPrint('[SetupHelper] Error assigning to ${device.id}: $e');
      }
    }

    // 5. Set device pertama sebagai current
    if (devices.docs.isNotEmpty) {
      await _firestore.collection('users').doc(userId).update({
        'currentGreenhouseId': devices.docs.first.id,
        'currentDeviceId': devices.docs.first.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    debugPrint('[SetupHelper] Development setup complete!');
  }

  /// Get list semua greenhouse/device IDs
  Future<List<String>> getAllGreenhouseIds() async {
    final snapshot = await _firestore.collection('devices').get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  /// Get list semua devices dengan info
  Future<List<Map<String, dynamic>>> getAllDevices() async {
    final snapshot = await _firestore.collection('devices').get();
    return snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  /// Get list user memberships
  /// Coba baca dari users/{userId}/memberships dulu,
  /// jika gagal (permission denied), fallback ke devices/{deviceId}/members
  Future<List<Map<String, dynamic>>> getUserMemberships(String userId) async {
    try {
      // Primary: baca dari users/{userId}/memberships
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('memberships')
          .get();

      debugPrint('[GreenhouseSetupHelper] getUserMemberships from users/$userId/memberships: ${snapshot.docs.length} items');

      return snapshot.docs.map((doc) => {
        'greenhouseId': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      debugPrint('[GreenhouseSetupHelper] Failed to read users/$userId/memberships: $e');
      debugPrint('[GreenhouseSetupHelper] Falling back to devices/*/members/$userId');

      // Fallback: scan semua devices dan cek members
      try {
        final devicesSnapshot = await _firestore.collection('devices').get();
        final memberships = <Map<String, dynamic>>[];

        for (final device in devicesSnapshot.docs) {
          final memberDoc = await _firestore
              .collection('devices')
              .doc(device.id)
              .collection('members')
              .doc(userId)
              .get();

          if (memberDoc.exists) {
            memberships.add({
              'greenhouseId': device.id,
              ...?memberDoc.data(),
            });
          }
        }

        debugPrint('[GreenhouseSetupHelper] Fallback found ${memberships.length} memberships');
        return memberships;
      } catch (fallbackError) {
        debugPrint('[GreenhouseSetupHelper] Fallback also failed: $fallbackError');
        return [];
      }
    }
  }
}
