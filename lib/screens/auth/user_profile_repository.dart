import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.photoUrl,
  });

  final String id;
  final String name;
  final String email;
  final String photoUrl;

  factory UserProfile.fromMap(String id, Map<String, dynamic> data) {
    return UserProfile(
      id: id,
      name: data['name'] as String? ?? 'Grower',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
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
