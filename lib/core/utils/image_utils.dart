import 'dart:convert';
import 'dart:typed_data';

class ImageUtils {
  const ImageUtils._();

  static Uint8List? decodeBase64(String? data) {
    if (data == null || data.isEmpty) return null;
    final trimmed = data.trim();
    final normalized = trimmed.contains('base64,')
        ? trimmed.substring(trimmed.indexOf('base64,') + 7)
        : trimmed;
    try {
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  static bool isRemoteSource(String? data) {
    if (data == null || data.isEmpty) return false;
    final lower = data.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('gs://');
  }
}
