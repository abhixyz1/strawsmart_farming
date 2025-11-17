import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_repository.dart';
import '../auth/user_profile_repository.dart';
import '../../services/storage_service.dart';

class ProfileController extends StateNotifier<AsyncValue<void>> {
  ProfileController(this._repository, this._storageService, this._ref)
      : super(const AsyncValue.data(null));

  final UserProfileRepository _repository;
  final StorageService _storageService;
  final Ref _ref;

  Future<void> updateProfile(UserProfile profile, {File? newPhoto}) async {
    state = const AsyncValue.loading();
    try {
      final authState = _ref.read(authStateProvider);
      final user = authState.valueOrNull;
      
      if (user == null) {
        throw Exception('Pengguna tidak terautentikasi');
      }

      String? photoUrl = profile.photoUrl;

      // Upload new photo if provided
      if (newPhoto != null) {
        photoUrl = await _storageService.uploadProfilePhoto(
          uid: user.uid,
          imageFile: newPhoto,
        );
      }

      // Update profile with new photo URL
      final updatedProfile = profile.copyWith(photoUrl: photoUrl);

      await _repository.updateProfile(user.uid, updatedProfile);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteProfilePhoto(UserProfile profile) async {
    state = const AsyncValue.loading();
    try {
      final authState = _ref.read(authStateProvider);
      final user = authState.valueOrNull;
      
      if (user == null) {
        throw Exception('Pengguna tidak terautentikasi');
      }

      // Delete from storage
      await _storageService.deleteProfilePhoto(user.uid);

      // Update Firestore to remove photoUrl
      final updatedProfile = profile.copyWith(photoUrl: null);
      await _repository.updateProfile(user.uid, updatedProfile);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<void>>((ref) {
  final repository = ref.watch(userProfileRepositoryProvider);
  final storageService = ref.watch(storageServiceProvider);
  return ProfileController(repository, storageService, ref);
});

