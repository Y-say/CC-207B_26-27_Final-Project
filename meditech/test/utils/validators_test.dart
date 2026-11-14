import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/utils/validators.dart';

void main() {
  // Mobile numbers
  test('mobile number rules', () {
    expect(Validators.mobile('09171234567'), isNull);
    expect(Validators.mobile('9171234567'), isNotNull);
    expect(Validators.mobile(''), 'Required.');
  });

  // Names allow ñ, hyphens, and apostrophes
  test('name rules', () {
    expect(Validators.name('Dela Cruz'), isNull);
    expect(Validators.name("Peña-O'Neil"), isNull);
    expect(Validators.name('J'), isNotNull);
    expect(Validators.name('', optional: true), isNull);
  });

  // Passwords need a letter and a number
  test('password rules', () {
    expect(Validators.password('Test1234'), isNull);
    expect(Validators.password('testtest'), isNotNull);
    expect(Validators.confirmPassword('Test1234', 'Test1234'), isNull);
    expect(Validators.confirmPassword('Test123', 'Test1234'), 'Passwords do not match.');
  });
}