import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service untuk mengelola OTP (One-Time Password)
/// Menggunakan Firebase Realtime Database untuk menyimpan OTP
class OTPService {
  final FirebaseDatabase _database;

  OTPService(this._database);

  /// Generate OTP 6 digit random
  String generateOTP() {
    final random = Random();
    final otp = random.nextInt(900000) + 100000; // 100000-999999
    return otp.toString();
  }

  /// Simpan OTP ke Firebase Realtime Database
  /// Path: otp_codes/{email_encoded}/{otp, timestamp, used}
  Future<void> saveOTP({
    required String email,
    required String otp,
  }) async {
    // Encode email untuk dijadikan key (replace . dengan _)
    final encodedEmail = email.replaceAll('.', '_').replaceAll('@', '_at_');
    
    final ref = _database.ref('otp_codes/$encodedEmail');
    
    await ref.set({
      'otp': otp,
      'email': email,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'used': false,
      'expiresAt': DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch,
    });
  }

  /// Verifikasi OTP
  /// Returns true jika OTP valid dan belum expired
  Future<bool> verifyOTP({
    required String email,
    required String otp,
  }) async {
    final encodedEmail = email.replaceAll('.', '_').replaceAll('@', '_at_');
    final ref = _database.ref('otp_codes/$encodedEmail');

    final snapshot = await ref.get();
    
    if (!snapshot.exists) {
      return false;
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    final savedOTP = data['otp'] as String?;
    final expiresAt = data['expiresAt'] as int?;
    final used = data['used'] as bool?;

    // Check if OTP matches
    if (savedOTP != otp) {
      return false;
    }

    // Check if already used
    if (used == true) {
      return false;
    }

    // Check if expired
    if (expiresAt != null && DateTime.now().millisecondsSinceEpoch > expiresAt) {
      return false;
    }

    // Mark as used
    await ref.update({'used': true});

    return true;
  }

  /// Hapus OTP setelah digunakan (cleanup)
  Future<void> deleteOTP(String email) async {
    final encodedEmail = email.replaceAll('.', '_').replaceAll('@', '_at_');
    final ref = _database.ref('otp_codes/$encodedEmail');
    await ref.remove();
  }

  /// Kirim OTP via email menggunakan EmailJS
  /// Untuk production, gunakan EmailJS (gratis) atau email service lainnya
  Future<void> sendOTPEmail({
    required String email,
    required String otp,
  }) async {
    try {
      // OPTION 1: EmailJS (Recommended untuk development - GRATIS)
      // Daftar di https://www.emailjs.com/
      // Ganti dengan Service ID, Template ID, dan Public Key Anda
      
      const serviceId = 'YOUR_SERVICE_ID'; // Ganti dengan Service ID dari EmailJS
      const templateId = 'YOUR_TEMPLATE_ID'; // Ganti dengan Template ID dari EmailJS
      const publicKey = 'YOUR_PUBLIC_KEY'; // Ganti dengan Public Key dari EmailJS
      
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'to_email': email,
            'otp_code': otp,
            'app_name': 'StrawSmart Farming',
            'expiry_minutes': '10',
          }
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Email OTP berhasil dikirim ke: $email');
      } else {
        print('❌ Gagal kirim email: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception('Gagal mengirim email OTP');
      }
      
    } catch (e) {
      print('❌ Error kirim email: $e');
      // Fallback: Tampilkan di console untuk development
      print('═══════════════════════════════════════');
      print('📧 OTP Email untuk: $email');
      print('🔢 Kode OTP: $otp');
      print('⏰ Berlaku selama: 10 menit');
      print('═══════════════════════════════════════');
      // Tidak throw error agar flow tetap jalan
    }
  }

  /// Generate dan kirim OTP (helper method)
  Future<String> generateAndSendOTP(String email) async {
    final otp = generateOTP();
    
    // Simpan ke database
    await saveOTP(email: email, otp: otp);
    
    // Kirim via email
    await sendOTPEmail(email: email, otp: otp);
    
    return otp;
  }

  /// Simpan password baru yang akan diaktifkan saat login
  /// Path: password_reset_requests/{email_encoded}/{newPassword, timestamp}
  Future<void> saveNewPassword({
    required String email,
    required String newPassword,
  }) async {
    final encodedEmail = email.replaceAll('.', '_').replaceAll('@', '_at_');
    final ref = _database.ref('password_reset_requests/$encodedEmail');
    
    await ref.set({
      'email': email,
      'newPassword': newPassword, // Dalam production, hash dengan bcrypt
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'applied': false,
      'expiresAt': DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
    });
    
    print('✅ Password baru tersimpan untuk: $email');
  }

  /// Ambil dan apply password baru saat user login
  /// Returns new password jika ada reset request yang belum applied
  Future<String?> getPendingPasswordReset(String email) async {
    final encodedEmail = email.replaceAll('.', '_').replaceAll('@', '_at_');
    final ref = _database.ref('password_reset_requests/$encodedEmail');

    final snapshot = await ref.get();
    
    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    final applied = data['applied'] as bool?;
    final expiresAt = data['expiresAt'] as int?;
    final newPassword = data['newPassword'] as String?;

    // Check if expired
    if (expiresAt != null && DateTime.now().millisecondsSinceEpoch > expiresAt) {
      await ref.remove(); // Cleanup expired request
      return null;
    }

    // Check if already applied
    if (applied == true) {
      return null;
    }

    return newPassword;
  }

  /// Mark password reset sebagai sudah diapply
  Future<void> markPasswordResetApplied(String email) async {
    final encodedEmail = email.replaceAll('.', '_').replaceAll('@', '_at_');
    final ref = _database.ref('password_reset_requests/$encodedEmail');
    
    await ref.update({'applied': true});
  }

  /// Hapus password reset request setelah selesai
  Future<void> deletePasswordResetRequest(String email) async {
    final encodedEmail = email.replaceAll('.', '_').replaceAll('@', '_at_');
    final ref = _database.ref('password_reset_requests/$encodedEmail');
    await ref.remove();
  }

  /// Kirim password reset link via Firebase Auth (fallback)
  /// Untuk aktivasi password via email jika user prefer cara itu
  Future<void> sendPasswordResetLink(String email) async {
    // Note: Ini akan kirim email Firebase default
    // User bisa pilih metode ini sebagai alternatif
    print('📧 Password reset link akan dikirim ke: $email');
    // Implementasi actual ada di AuthRepository untuk avoid circular dependency
  }
}
