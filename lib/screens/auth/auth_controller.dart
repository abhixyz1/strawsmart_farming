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
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun dinonaktifkan.';
      case 'user-not-found':
        return 'Email tidak terdaftar.';
      case 'wrong-password':
        return 'Kata sandi salah.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba beberapa menit lagi.';
      case 'network-request-failed':
        return 'Koneksi jaringan bermasalah.';
      default:
        return 'Gagal masuk: ${e.message ?? e.code}';
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<dynamic>>((ref) {
  final repo = ref.read(authRepositoryProvider);
  return AuthController(repo);
});
