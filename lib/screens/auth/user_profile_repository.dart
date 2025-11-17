import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserProfile.fromMap(String id, Map<String, dynamic> data) {
    return UserProfile(
      id: id,
      name: data['name'] as String? ?? 'Grower',
      email: data['email'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String?,
      photoUrl: data['photoUrl'] as String?,
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
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? photoUrl,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
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
