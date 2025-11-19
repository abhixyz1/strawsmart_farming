import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  // Explicitly specify the bucket to avoid mismatch issues
  final storage = FirebaseStorage.instanceFor(
    bucket: 'gs://strawsmart-farming-af721.firebasestorage.app',
  );
  return StorageService(storage);
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
      // Validate file exists and has content
      if (!await imageFile.exists()) {
        throw Exception('File tidak ditemukan. Pastikan file foto valid.');
      }

      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        throw Exception('File kosong. Pilih foto yang valid.');
      }

      // Log upload attempt
      print('[StorageService] Uploading profile photo for UID: $uid');
      print('[StorageService] File size: ${fileSize ~/ 1024} KB');
      print('[StorageService] Bucket: ${_storage.bucket}');

      final ref = _storage.ref().child('profile_photos/$uid.jpg');
      print('[StorageService] Storage path: ${ref.fullPath}');
      
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

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('[StorageService] Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      print('[StorageService] Upload completed. State: ${snapshot.state}');

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('[StorageService] Download URL obtained: $downloadUrl');
      
      return downloadUrl;
    } on FirebaseException catch (e) {
      print('[StorageService] Firebase error: ${e.code} - ${e.message}');
      
      // Provide user-friendly error messages
      String errorMessage;
      switch (e.code) {
        case 'object-not-found':
          errorMessage = 'File tidak ditemukan di server. Coba upload ulang.';
          break;
        case 'bucket-not-found':
          errorMessage = 'Konfigurasi storage bucket salah. Hubungi administrator.';
          break;
        case 'unauthorized':
          errorMessage = 'Anda tidak memiliki izin untuk upload foto. Periksa aturan Firebase Storage.';
          break;
        case 'unauthenticated':
          errorMessage = 'Silakan login kembali untuk upload foto.';
          break;
        case 'retry-limit-exceeded':
          errorMessage = 'Koneksi terputus. Periksa internet Anda dan coba lagi.';
          break;
        case 'invalid-checksum':
          errorMessage = 'File rusak saat upload. Coba pilih foto lain.';
          break;
        default:
          errorMessage = 'Gagal upload foto: ${e.message ?? e.code}';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      print('[StorageService] Unexpected error: $e');
      throw Exception('Gagal upload foto: $e');
    }
  }

  /// Deletes the profile photo for the given user ID.
  Future<void> deleteProfilePhoto(String uid) async {
    try {
      print('[StorageService] Deleting profile photo for UID: $uid');
      
      final ref = _storage.ref().child('profile_photos/$uid.jpg');
      print('[StorageService] Delete path: ${ref.fullPath}');
      
      await ref.delete();
      print('[StorageService] Photo deleted successfully');
    } on FirebaseException catch (e) {
      print('[StorageService] Delete error: ${e.code} - ${e.message}');
      
      // Ignore error if file doesn't exist (already deleted)
      if (e.code != 'object-not-found') {
        String errorMessage;
        switch (e.code) {
          case 'unauthorized':
            errorMessage = 'Tidak memiliki izin untuk hapus foto.';
            break;
          case 'unauthenticated':
            errorMessage = 'Silakan login kembali.';
            break;
          default:
            errorMessage = 'Gagal hapus foto: ${e.message ?? e.code}';
        }
        throw Exception(errorMessage);
      } else {
        print('[StorageService] Photo already deleted or does not exist');
      }
    } catch (e) {
      print('[StorageService] Unexpected delete error: $e');
      throw Exception('Gagal hapus foto: $e');
    }
  }
}
