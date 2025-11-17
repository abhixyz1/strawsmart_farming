import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(FirebaseStorage.instance);
});

class StorageService {
  StorageService(this._storage);

  final FirebaseStorage _storage;

  /// Uploads a profile photo to Firebase Storage and returns the download URL.
  /// The file will be stored at `profile_photos/{uid}.jpg`.
  Future<String> uploadProfilePhoto({
    required String uid,
    required File imageFile,
  }) async {
    try {
      final ref = _storage.ref().child('profile_photos/$uid.jpg');
      
      // Upload the file
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } on FirebaseException catch (e) {
      throw Exception('Gagal upload foto: ${e.message}');
    } catch (e) {
      throw Exception('Gagal upload foto: $e');
    }
  }

  /// Deletes the profile photo for the given user ID.
  Future<void> deleteProfilePhoto(String uid) async {
    try {
      final ref = _storage.ref().child('profile_photos/$uid.jpg');
      await ref.delete();
    } on FirebaseException catch (e) {
      // Ignore error if file doesn't exist
      if (e.code != 'object-not-found') {
        throw Exception('Gagal hapus foto: ${e.message}');
      }
    } catch (e) {
      throw Exception('Gagal hapus foto: $e');
    }
  }
}
