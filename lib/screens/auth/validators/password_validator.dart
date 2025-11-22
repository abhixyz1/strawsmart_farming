/// Validator untuk password dengan aturan keamanan yang ketat
class PasswordValidator {
  /// Regex untuk validasi password:
  /// - Minimal 6 karakter
  /// - Minimal 1 digit (0-9)
  /// - Minimal 1 simbol (!@#$%^&*(),.?":{}|<>)
  static final RegExp _passwordRegex = RegExp(
    r'^(?=.*[0-9])(?=.*[!@#\$%^&*(),.?":{}|<>]).{6,}$',
  );

  /// Validasi password dengan aturan ketat
  /// Returns null jika valid, String error message jika tidak valid
  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Kata sandi wajib diisi.';
    }

    if (value.length < 6) {
      return 'Kata sandi minimal 6 karakter.';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Kata sandi harus berisi minimal 1 angka.';
    }

    if (!value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
      return r'Kata sandi harus berisi minimal 1 simbol (!@#$%^&*).';
    }

    if (!_passwordRegex.hasMatch(value)) {
      return 'Kata sandi tidak memenuhi syarat keamanan.';
    }

    return null; // Valid
  }

  /// Helper text untuk ditampilkan di bawah field password
  static const String helperText = 
      'Minimal 6 karakter, berisi angka & simbol';

  /// Deskripsi lengkap untuk user
  static const String description =
      'Kata sandi harus minimal 6 karakter dan mengandung setidaknya 1 angka serta 1 simbol (!@#\$%^&*).';
}
