import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'package:meditech/routes/password_redirect.dart';

void main() {
  const staff = SignedInAccount(
    accountType: 'staff',
    state: 'active',
    mustChangePassword: true,
  );

  // A temporary password opens the change-password page
  test('temporary password leaves the sign-in page', () {
    expect(redirectForPasswordChange(staff, '/'), '/change-password');
  });

  // After the password is saved, the change page is left
  test('a finished password change leaves that page', () {
    const done = SignedInAccount(
      accountType: 'staff',
      state: 'active',
      mustChangePassword: false,
    );
    expect(redirectForPasswordChange(done, '/change-password'), '/');
  });
}