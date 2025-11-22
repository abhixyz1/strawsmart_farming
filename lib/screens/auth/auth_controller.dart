import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthController extends StateNotifier<AsyncValue<User?>> {
  AuthController(this._repo) : super(const AsyncValue.data(null));

  final AuthRepository _repo;

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final cred = await _repo.signInWithEmail(email, password);
      state = AsyncValue.data(cred.user);
    } on FirebaseAuthException catch (e) {
      state = AsyncValue.error(_mapFirebaseError(e), StackTrace.current);
    } catch (e) {
      state = AsyncValue.error('Terjadi kesalahan. Coba lagi.', StackTrace.current);
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Format email tidak valid. Periksa kembali alamat email Anda.';
      case 'user-disabled':
        return 'Akun dinonaktifkan. Hubungi admin untuk mengaktifkan kembali.';
      case 'user-not-found':
        return 'Email tidak terdaftar. Periksa email atau hubungi admin untuk registrasi.';
      case 'wrong-password':
        return 'Kata sandi salah. Periksa kembali atau gunakan "Lupa kata sandi".';
      case 'invalid-credential':
        return 'Email atau kata sandi salah. Periksa kembali kredensial Anda.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan login. Tunggu beberapa menit atau reset kata sandi.';
      case 'network-request-failed':
        return 'Koneksi jaringan bermasalah. Periksa koneksi internet Anda.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Gunakan email lain atau login.';
      case 'weak-password':
        return 'Kata sandi terlalu lemah. Gunakan minimal 6 karakter dengan angka & simbol.';
      default:
        return 'Gagal masuk. Periksa email/kata sandi atau hubungi admin.';
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<dynamic>>((ref) {
  final repo = ref.read(authRepositoryProvider);
  return AuthController(repo);
});
