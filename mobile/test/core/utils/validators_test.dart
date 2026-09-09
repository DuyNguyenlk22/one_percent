import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts a well-formed address', () {
      expect(Validators.email('alex.bloom@example.com'), isNull);
      expect(Validators.email('  alex@example.co.uk  '), isNull);
    });

    test('rejects a missing or malformed address', () {
      expect(Validators.email(null), 'Email is required');
      expect(Validators.email('   '), 'Email is required');
      expect(Validators.email('alex'), 'Enter a valid email address');
      expect(Validators.email('alex@'), 'Enter a valid email address');
      expect(Validators.email('alex@example'), 'Enter a valid email address');
    });
  });

  group('Validators.password', () {
    test('accepts six characters or more, matching the backend DTO', () {
      expect(Validators.password('secret'), isNull);
      expect(Validators.password('a-much-longer-password'), isNull);
    });

    test('rejects a short or empty password', () {
      expect(Validators.password(''), 'Password is required');
      expect(Validators.password('short'), 'Password must be at least 6 characters');
    });
  });

  group('Validators.confirmPassword', () {
    test('accepts a matching value', () {
      expect(Validators.confirmPassword('secret', 'secret'), isNull);
    });

    test('rejects a mismatch or a blank value', () {
      expect(Validators.confirmPassword('other', 'secret'), 'Passwords do not match');
      expect(Validators.confirmPassword('', 'secret'), 'Please confirm your password');
    });
  });

  group('Validators.habitName', () {
    test('accepts a name within the length limit', () {
      expect(Validators.habitName('Morning run'), isNull);
    });

    test('rejects a blank or over-long name', () {
      expect(Validators.habitName('  '), 'Habit name is required');
      expect(Validators.habitName('x' * 61), 'Keep it under 60 characters');
    });
  });
}
