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
    expect(
      redirectForPasswordChange(done, '/change-password', homePath: '/dashboard'),
      '/dashboard',
    );
  });

  // Waiting owners only see the application status page
  test('waiting owner goes to application status', () {
    const waiting = SignedInAccount(
      accountType: 'staff',
      state: 'pending_approval',
      role: 'owner',
    );
    expect(redirectForPharmacySession(waiting, '/'), '/application-status');
    expect(redirectForPharmacySession(waiting, '/activity-log'), '/application-status');
    expect(redirectForPharmacySession(waiting, '/application-status'), null);
    expect(redirectForPharmacySession(waiting, '/register'), null);
  });

  // Rejected owners can open status or resubmit registration
  test('rejected owner stays on status or register', () {
    const rejected = SignedInAccount(
      accountType: 'staff',
      state: 'rejected',
      role: 'owner',
    );
    expect(redirectForPharmacySession(rejected, '/notifications'), '/application-status');
    expect(redirectForPharmacySession(rejected, '/register'), null);
  });

  // Suspended owners only see the suspended page
  test('suspended owner goes to the suspended page', () {
    const suspended = SignedInAccount(
      accountType: 'staff',
      state: 'suspended',
      role: 'owner',
    );
    expect(redirectForPharmacySession(suspended, '/'), '/suspended');
    expect(redirectForPharmacySession(suspended, '/suspended'), null);
  });

  // Guests cannot open status pages or the tablet shell directly
  test('signed-out users leave status and shell pages', () {
    expect(redirectForPharmacySession(null, '/application-status'), '/');
    expect(redirectForPharmacySession(null, '/suspended'), '/');
    expect(redirectForPharmacySession(null, '/dashboard'), '/');
    expect(redirectForPharmacySession(null, '/profile'), '/');
    expect(redirectForPharmacySession(null, '/profile/edit'), '/');
    expect(redirectForPharmacySession(null, '/employees'), '/');
    expect(redirectForPharmacySession(null, '/settings'), '/');
    expect(redirectForPharmacySession(null, '/notifications'), '/');
    expect(redirectForPharmacySession(null, '/register'), null);
    expect(redirectForPharmacySession(null, '/'), null);
  });

  test('only owners open Employees', () {
    const pharmacist = SignedInAccount(
      accountType: 'staff',
      state: 'active',
      role: 'pharmacist',
    );
    expect(redirectForPharmacySession(pharmacist, '/employees'), '/dashboard');
  });

  // Approved pharmacy staff open the dashboard shell
  test('active pharmacy staff open the dashboard', () {
    const active = SignedInAccount(
      accountType: 'staff',
      state: 'active',
      role: 'owner',
    );
    expect(redirectForPharmacySession(active, '/'), '/dashboard');
    expect(redirectForPharmacySession(active, '/dashboard'), null);
    expect(redirectForPharmacySession(active, '/profile'), null);
    expect(redirectForPharmacySession(active, '/profile/edit'), null);
    expect(redirectForPharmacySession(active, '/employees'), null);
    expect(redirectForPharmacySession(active, '/settings'), null);
    expect(redirectForPharmacySession(active, '/reservations'), null);
    expect(redirectForPharmacySession(active, '/notifications'), null);
    expect(redirectForPharmacySession(active, '/application-status'), '/dashboard');
  });

  // Approved admins open overview; guests cannot open admin shell routes
  test('active admins open overview shell', () {
    const admin = SignedInAccount(
      accountType: 'admin',
      state: 'active',
    );
    expect(redirectForAdminSession(admin, '/'), '/overview');
    expect(redirectForAdminSession(admin, '/overview'), null);
    expect(redirectForAdminSession(admin, '/pharmacies'), null);
    expect(redirectForAdminSession(admin, '/notifications'), null);
    expect(redirectForAdminSession(null, '/overview'), '/');
    expect(redirectForAdminSession(null, '/listings'), '/');
    expect(redirectForAdminSession(null, '/pharmacies'), '/');
    expect(redirectForAdminSession(null, '/notifications'), '/');
    expect(redirectForAdminSession(null, '/'), null);
  });
}
