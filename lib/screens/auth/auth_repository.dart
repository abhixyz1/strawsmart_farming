import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth;

  AuthRepository(this._auth);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// Kirim link reset password ke email
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Update password hanya bisa dilakukan ketika user saat ini sudah login.
  Future<void> updatePasswordWithVerification({
    required String email,
    required String newPassword,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null || currentUser.email != email) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message:
            'User harus login terlebih dahulu sebelum memperbarui kata sandi.',
      );
    }

    await currentUser.updatePassword(newPassword);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.read(authRepositoryProvider).authStateChanges;
});
