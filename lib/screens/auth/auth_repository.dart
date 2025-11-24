import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'services/otp_service.dart';

// Provider untuk OTP Service
final otpServiceProvider = Provider<OTPService>((ref) {
  return OTPService(FirebaseDatabase.instance);
});

class AuthRepository {
  final FirebaseAuth _auth;
  final OTPService _otpService;
  
  AuthRepository(this._auth, this._otpService);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    // Coba login dengan password lama dulu
    UserCredential credential;
    
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on FirebaseAuthException catch (e) {
      // Jika login gagal, cek apakah ada pending password reset
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        final newPassword = await _otpService.getPendingPasswordReset(email);
        
        if (newPassword != null) {
          // Ada password baru yang pending, coba login dengan password baru
          try {
            credential = await _auth.signInWithEmailAndPassword(
              email: email,
              password: newPassword,
            );
            
            // Login berhasil dengan password baru, mark as applied
            await _otpService.markPasswordResetApplied(email);
            return credential;
          } catch (_) {
            // Password baru juga gagal, user perlu update password via forgot password flow
            // tapi kita perlu update Firebase Auth password dulu
            rethrow;
          }
        }
      }
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Kirim link reset password ke email
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Update password untuk user yang sudah terverifikasi via OTP
  Future<void> updatePasswordWithVerification({
    required String email,
    required String newPassword,
  }) async {
    final User? currentUser = _auth.currentUser;
    
    if (currentUser != null && currentUser.email == email) {
      // User sudah login, update langsung
      await currentUser.updatePassword(newPassword);
    } else {
      // User belum login, simpan password baru untuk diapply saat login
      await _otpService.saveNewPassword(email: email, newPassword: newPassword);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final otpService = ref.read(otpServiceProvider);
  return AuthRepository(FirebaseAuth.instance, otpService);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(authRepositoryProvider).authStateChanges;
});
