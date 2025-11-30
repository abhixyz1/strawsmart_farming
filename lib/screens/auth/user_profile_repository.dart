import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_role.dart';
import 'auth_repository.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.photoUrl,
    this.photoBase64,
    this.role = UserRole.petani,
    this.currentGreenhouseId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? photoUrl;
  final String? photoBase64;
  
  /// Role global user (admin/owner/petani)
  final UserRole role;
  
  /// ID greenhouse yang sedang aktif/dipilih
  final String? currentGreenhouseId;
  
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Cek apakah user adalah admin global
  bool get isAdmin => role == UserRole.admin;

  /// Cek apakah user bisa memilih greenhouse (admin/owner)
  bool get canSelectGreenhouse => role.canSelectGreenhouse;

  factory UserProfile.fromMap(String id, Map<String, dynamic> data) {
    return UserProfile(
      id: id,
      name: data['name'] as String? ?? 'Grower',
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      photoUrl: data['photoUrl'] as String?,
  photoBase64: data['photoBase64'] as String?,
      role: UserRole.fromString(data['role'] as String?),
      currentGreenhouseId: data['currentGreenhouseId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
  'photoBase64': photoBase64,
      'role': role.name,
      'currentGreenhouseId': currentGreenhouseId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    String? photoBase64,
    UserRole? role,
    String? currentGreenhouseId,
    bool clearCurrentGreenhouse = false,
    bool clearPhoto = false,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
      role: role ?? this.role,
      currentGreenhouseId: clearCurrentGreenhouse ? null : (currentGreenhouseId ?? this.currentGreenhouseId),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class UserProfileRepository {
  UserProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<UserProfile?> watchProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      if (data == null) return null;
      return UserProfile.fromMap(snapshot.id, data);
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return UserProfile.fromMap(snapshot.id, data);
  }

  Future<void> updateProfile(String uid, UserProfile profile) async {
    final data = profile.toMap();
    final docRef = _firestore.collection('users').doc(uid);
    
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      // Create document with createdAt if it doesn't exist
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    
    await docRef.set(data, SetOptions(merge: true));
  }

  /// Update greenhouse yang sedang aktif/dipilih user
  Future<void> updateCurrentGreenhouse(String uid, String? greenhouseId) async {
    await _firestore.collection('users').doc(uid).update({
      'currentGreenhouseId': greenhouseId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update role user (hanya untuk admin)
  Future<void> updateUserRole(String uid, String role) async {
    await _firestore.collection('users').doc(uid).update({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final userProfileRepositoryProvider =
    Provider<UserProfileRepository>((ref) => UserProfileRepository(FirebaseFirestore.instance));

final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  if (user == null) {
    return Stream<UserProfile?>.value(null);
  }
  final repo = ref.watch(userProfileRepositoryProvider);
  return repo.watchProfile(user.uid);
});
