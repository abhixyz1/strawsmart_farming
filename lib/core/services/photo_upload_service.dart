import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Provider untuk PhotoUploadService
final photoUploadServiceProvider = Provider<PhotoUploadService>((ref) {
  return PhotoUploadService();
});

/// Service utilitas untuk memproses foto menjadi Base64
class PhotoUploadService {
  PhotoUploadService();
  final _picker = ImagePicker();
  static const _maxUploadBytes = 600 * 1024; // ~600 KB agar aman di Firestore

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

  /// Konversi foto profil menjadi string Base64 siap simpan di Firestore
  Future<String> uploadProfilePhoto({
    required String uid,
    required XFile image,
  }) async {
    try {
      final preparedBytes = await _prepareBytes(image);
      return base64Encode(preparedBytes);
    } catch (e) {
      throw Exception('Gagal memproses foto profil: $e');
    }
  }

  /// Konversi foto jurnal batch menjadi string Base64
  Future<String> uploadJournalPhoto({
    required String batchId,
    required String entryId,
    required XFile image,
  }) async {
    try {
      final preparedBytes = await _prepareBytes(image);
      return base64Encode(preparedBytes);
    } catch (e) {
      throw Exception('Gagal memproses foto jurnal: $e');
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
