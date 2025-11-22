import 'package:flutter_test/flutter_test.dart';
import 'package:strawsmart_farming/screens/auth/validators/password_validator.dart';

void main() {
  group('PasswordValidator', () {
    test('should reject null password', () {
      expect(PasswordValidator.validate(null), isNotNull);
      expect(PasswordValidator.validate(null), contains('wajib diisi'));
    });

    test('should reject empty password', () {
      expect(PasswordValidator.validate(''), isNotNull);
      expect(PasswordValidator.validate(''), contains('wajib diisi'));
    });

    test('should reject password less than 6 characters', () {
      expect(PasswordValidator.validate('12@ab'), isNotNull);
      expect(PasswordValidator.validate('12@ab'), contains('minimal 6 karakter'));
    });

    test('should reject password without digit', () {
      expect(PasswordValidator.validate('abcdef!'), isNotNull);
      expect(PasswordValidator.validate('abcdef!'), contains('minimal 1 angka'));
    });

    test('should reject password without symbol', () {
      expect(PasswordValidator.validate('abcdef123'), isNotNull);
      expect(PasswordValidator.validate('abcdef123'), contains('minimal 1 simbol'));
    });

    test('should accept valid password with 6 chars, digit and symbol', () {
      expect(PasswordValidator.validate('Test1!'), isNull);
    });

    test('should accept valid password with mix of requirements', () {
      expect(PasswordValidator.validate('Pass123!'), isNull);
      expect(PasswordValidator.validate('MyP@ss1'), isNull);
      expect(PasswordValidator.validate('Str0ng#Pass'), isNull);
    });

    test('should accept password with various symbols', () {
      expect(PasswordValidator.validate('test1@'), isNull);
      expect(PasswordValidator.validate('test1#'), isNull);
      expect(PasswordValidator.validate(r'test1$'), isNull);
      expect(PasswordValidator.validate('test1%'), isNull);
      expect(PasswordValidator.validate('test1^'), isNull);
      expect(PasswordValidator.validate('test1&'), isNull);
      expect(PasswordValidator.validate('test1*'), isNull);
    });

    test('should accept long password meeting requirements', () {
      expect(
        PasswordValidator.validate('VeryLongPassword123!WithManyCharacters'),
        isNull,
      );
    });
  });
}
