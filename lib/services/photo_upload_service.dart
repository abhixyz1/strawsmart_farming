
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Provider untuk PhotoUploadService
final photoUploadServiceProvider = Provider<PhotoUploadService>((ref) {
  return PhotoUploadService(FirebaseStorage.instance);
});

/// Service untuk upload foto ke Firebase Storage
class PhotoUploadService {
  PhotoUploadService(this._storage);

  final FirebaseStorage _storage;
  final _picker = ImagePicker();
  final _uuid = const Uuid();
  static const _maxUploadBytes = 5 * 1024 * 1024; // 5 MB

  /// Pilih foto dari galeri atau kamera
  Future<XFile?> pickImage({required ImageSource source}) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      return null;
    }
  }

  /// Pilih multiple foto dari galeri
  Future<List<XFile>> pickMultipleImages({int maxImages = 5}) async {
    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      // Limit jumlah foto
      return images.take(maxImages).toList();
    } catch (e) {
      return [];
    }
  }

  /// Upload foto jurnal ke Firebase Storage
  /// Returns download URL
  Future<String?> uploadJournalPhoto({
    required String batchId,
    required String journalId,
    required XFile imageFile,
  }) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref()
          .child('batches')
          .child(batchId)
          .child('journal')
          .child(journalId)
          .child(fileName);
      final preparedBytes = await _prepareBytes(imageFile);

      final snapshot = await ref.putData(
        preparedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e, st) {
      debugPrint('Error uploading photo: $e\n$st');
      return null;
    }
  }

  /// Upload multiple foto sekaligus
  Future<List<String>> uploadMultiplePhotos({
    required String batchId,
    required String journalId,
    required List<XFile> imageFiles,
    void Function(int uploaded, int total)? onProgress,
  }) async {
    final urls = <String>[];
    
    for (var i = 0; i < imageFiles.length; i++) {
      final url = await uploadJournalPhoto(
        batchId: batchId,
        journalId: journalId,
        imageFile: imageFiles[i],
      );
      
      if (url != null) {
        urls.add(url);
      }
      
      onProgress?.call(i + 1, imageFiles.length);
    }
    
    return urls;
  }

  /// Delete foto dari storage
  Future<void> deletePhoto(String photoUrl) async {
    try {
      final ref = _storage.refFromURL(photoUrl);
      await ref.delete();
    } catch (e, st) {
      debugPrint('Error deleting photo: $e\n$st');
    }
  }

  /// Delete semua foto jurnal
  Future<void> deleteJournalPhotos({
    required String batchId,
    required String journalId,
  }) async {
    try {
      final ref = _storage.ref()
          .child('batches')
          .child(batchId)
          .child('journal')
          .child(journalId);
      
      final items = await ref.listAll();
      for (final item in items.items) {
        await item.delete();
      }
    } catch (e, st) {
      debugPrint('Error deleting journal photos: $e\n$st');
    }
  }

  Future<Uint8List> _prepareBytes(XFile file) async {
    final rawBytes = await file.readAsBytes();
    if (rawBytes.lengthInBytes <= _maxUploadBytes) {
      return rawBytes;
    }

    final payload = _CompressionPayload(rawBytes, _maxUploadBytes);
    final compressed = kIsWeb
        ? _compressImageBytes(payload)
        : await compute(_compressImageBytes, payload);

    if (compressed == null) {
      debugPrint('Image compression failed, using original bytes');
      return rawBytes;
    }

    return compressed.lengthInBytes <= _maxUploadBytes ? compressed : rawBytes;
  }
}

class _CompressionPayload {
  const _CompressionPayload(this.bytes, this.maxBytes);

  final Uint8List bytes;
  final int maxBytes;
}

Uint8List? _compressImageBytes(_CompressionPayload payload) {
  final decoded = img.decodeImage(payload.bytes);
  if (decoded == null) return null;

  var currentImage = decoded;
  var quality = 85;
  Uint8List encoded = Uint8List.fromList(
    img.encodeJpg(currentImage, quality: quality),
  );

  while (encoded.lengthInBytes > payload.maxBytes) {
    if (quality > 45) {
      quality -= 10;
    } else if (currentImage.width > 800) {
      final newWidth = (currentImage.width * 0.85).round();
      currentImage = img.copyResize(currentImage, width: newWidth);
    } else {
      break;
    }

    encoded = Uint8List.fromList(
      img.encodeJpg(currentImage, quality: quality),
    );
  }

  return encoded;
}
