import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';

/// Model untuk relasi membership antara User dan Greenhouse
/// 
/// Menyimpan data akses user ke greenhouse tertentu.
/// Data disimpan di Firestore: `users/{uid}/memberships/{ghId}`
/// Mirror opsional: `greenhouses/{ghId}/members/{uid}`
class GreenhouseMembership {
  const GreenhouseMembership({
    required this.greenhouseId,
    required this.userId,
    required this.role,
    this.greenhouseName,
    this.greenhouseLocation,
    this.deviceId,
    this.joinedAt,
    this.updatedAt,
  });

  /// ID greenhouse yang diakses
  final String greenhouseId;

  /// ID user yang punya akses
  final String userId;

  /// Role user di greenhouse ini (owner/petani)
  final UserRole role;

  /// Cache nama greenhouse untuk display tanpa query tambahan
  final String? greenhouseName;

  /// Cache lokasi greenhouse
  final String? greenhouseLocation;

  /// Cache device ID untuk quick access ke RTDB
  final String? deviceId;

  final DateTime? joinedAt;
  final DateTime? updatedAt;

  factory GreenhouseMembership.fromFirestore(
    String greenhouseId,
    String userId,
    Map<String, dynamic> data,
  ) {
    return GreenhouseMembership(
      greenhouseId: greenhouseId,
      userId: userId,
      role: UserRole.fromString(data['role'] as String?),
      greenhouseName: data['greenhouseName'] as String?,
      greenhouseLocation: data['greenhouseLocation'] as String?,
      deviceId: data['deviceId'] as String?,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'role': role.name,
      'greenhouseName': greenhouseName,
      'greenhouseLocation': greenhouseLocation,
      'deviceId': deviceId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'joinedAt': FieldValue.serverTimestamp(),
    };
  }

  GreenhouseMembership copyWith({
    String? greenhouseId,
    String? userId,
    UserRole? role,
    String? greenhouseName,
    String? greenhouseLocation,
    String? deviceId,
  }) {
    return GreenhouseMembership(
      greenhouseId: greenhouseId ?? this.greenhouseId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      greenhouseName: greenhouseName ?? this.greenhouseName,
      greenhouseLocation: greenhouseLocation ?? this.greenhouseLocation,
      deviceId: deviceId ?? this.deviceId,
      joinedAt: joinedAt,
      updatedAt: updatedAt,
    );
  }

  /// Label untuk dropdown display
  String get displayName {
    final name = greenhouseName ?? 'Greenhouse';
    if (greenhouseLocation != null && greenhouseLocation!.isNotEmpty) {
      return '$name - $greenhouseLocation';
    }
    return name;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GreenhouseMembership &&
          runtimeType == other.runtimeType &&
          greenhouseId == other.greenhouseId &&
          userId == other.userId;

  @override
  int get hashCode => greenhouseId.hashCode ^ userId.hashCode;
}
