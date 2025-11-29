import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/auth_repository.dart';
import '../auth/user_profile_repository.dart';
import '../../services/photo_upload_service.dart';

class ProfileController extends StateNotifier<AsyncValue<void>> {
  ProfileController(this._repository, this._photoUploadService, this._ref)
      : super(const AsyncValue.data(null));

  final UserProfileRepository _repository;
  final PhotoUploadService _photoUploadService;
  final Ref _ref;

  Future<void> updateProfilePhoto(XFile image) async {
    state = const AsyncValue.loading();
    try {
      final authState = _ref.read(authStateProvider);
      final user = authState.valueOrNull;
      
      if (user == null) {
        throw Exception('Pengguna tidak terautentikasi');
      }

      // 1. Upload photo
      final photoData = await _photoUploadService.uploadProfilePhoto(
        uid: user.uid,
        image: image,
      );

      // 2. Get current profile
      final currentProfile = await _repository.getUserProfile(user.uid);
      if (currentProfile == null) {
        throw Exception('Profil pengguna tidak ditemukan');
      }

      // 3. Update profile with new URL
      final updatedProfile = currentProfile.copyWith(
        photoBase64: photoData,
        photoUrl: null,
      );
      await _repository.updateProfile(user.uid, updatedProfile);
      
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateProfile(
    UserProfile profile, {
    File? newPhoto,
  }) async {
    state = const AsyncValue.loading();
    try {
      final authState = _ref.read(authStateProvider);
      final user = authState.valueOrNull;
      if (user == null) {
        throw Exception('Pengguna tidak terautentikasi');
      }

      var updatedProfile = profile;
      if (newPhoto != null) {
        final photoData = await _photoUploadService.uploadProfilePhoto(
          uid: user.uid,
          image: XFile(newPhoto.path),
        );
        updatedProfile = updatedProfile.copyWith(
          photoBase64: photoData,
          photoUrl: null,
        );
      }

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

      await _repository.updateProfile(
        user.uid,
        profile.copyWith(clearPhoto: true),
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<void>>((ref) {
  final repository = ref.watch(userProfileRepositoryProvider);
  final photoUploadService = ref.watch(photoUploadServiceProvider);
  return ProfileController(repository, photoUploadService, ref);
});

