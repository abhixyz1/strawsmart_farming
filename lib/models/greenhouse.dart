import 'package:cloud_firestore/cloud_firestore.dart';

/// Model untuk data Greenhouse
/// 
/// Menyimpan metadata greenhouse yang terhubung ke sistem.
/// Data disimpan di Firestore: `greenhouses/{ghId}`
class Greenhouse {
  const Greenhouse({
    required this.id,
    required this.name,
    this.location,
    this.description,
    this.deviceId,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// ID unik greenhouse (document ID di Firestore)
  final String id;

  /// Nama greenhouse untuk display
  final String name;

  /// Lokasi greenhouse (opsional)
  final String? location;

  /// Deskripsi greenhouse (opsional)
  final String? description;

  /// Device ID yang terhubung di RTDB (mis: greenhouse_node_001)
  final String? deviceId;

  /// URL gambar greenhouse (opsional)
  final String? imageUrl;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Greenhouse.fromFirestore(String id, Map<String, dynamic> data) {
    return Greenhouse(
      id: id,
      name: data['name'] as String? ?? 'Greenhouse',
      location: data['location'] as String?,
      description: data['description'] as String?,
      deviceId: data['deviceId'] as String?,
      imageUrl: data['imageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'location': location,
      'description': description,
      'deviceId': deviceId,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Greenhouse copyWith({
    String? id,
    String? name,
    String? location,
    String? description,
    String? deviceId,
    String? imageUrl,
  }) {
    return Greenhouse(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      description: description ?? this.description,
      deviceId: deviceId ?? this.deviceId,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Label untuk dropdown display
  String get displayName {
    if (location != null && location!.isNotEmpty) {
      return '$name - $location';
    }
    return name;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Greenhouse && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
