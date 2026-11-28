import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/customer_notification_preferences.dart';
import 'package:meditech/models/customer_profile.dart';
import 'package:meditech/models/customer_profile_overview.dart';
import 'package:meditech/models/customer_saved_address.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'dart:typed_data';
import 'package:meditech/providers/profile_providers.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/routes/customer_routes.dart';
import 'package:meditech/screens/customer/profile/privacy_notice_screen.dart';
import 'package:meditech/screens/customer/profile/profile_screen.dart';
import 'package:meditech/screens/shared/change_password_screen.dart';
import 'package:meditech/services/profile_service.dart';

void main() {
  testWidgets('profile shows the saved details', (tester) async {
    const account = SignedInAccount(
      accountType: 'customer',
      state: 'active',
      mustChangePassword: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => _FakeSessionNotifier(account)),
          profileServiceProvider.overrideWithValue(_FakeProfileService()),
          customerProfileOverviewProvider.overrideWith((ref) async {
            return _FakeProfileService.overview;
          }),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('juan@demo.meditech.dev'), findsOneWidget);
    expect(find.textContaining('+63 917'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Saved Addresses'), findsOneWidget);
    expect(find.text('Log out', skipOffstage: false), findsOneWidget);
  });

  testWidgets('privacy notice is shown', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyNoticeScreen()));

    expect(find.text('MediTech Privacy Notice'), findsOneWidget);
  });

  testWidgets('tapping Change Password opens ChangePasswordScreen for signed-in customer', (tester) async {
    const account = SignedInAccount(
      accountType: 'customer',
      state: 'active',
      mustChangePassword: false,
    );

    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(() => _FakeSessionNotifier(account)),
        profileServiceProvider.overrideWithValue(_FakeProfileService()),
        customerProfileOverviewProvider.overrideWith((ref) async {
          return _FakeProfileService.overview;
        }),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(customerRouterProvider)..go('/profile');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final changePasswordTile = find.text('Change Password');
    await tester.scrollUntilVisible(
      changePasswordTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(changePasswordTile);
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
  });
}

class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._account);

  final SignedInAccount _account;

  @override
  SignedInAccount? build() => _account;
}

class _FakeProfileService implements ProfileService {
  static const overview = CustomerProfileOverview(
    profile: _profile,
    savedAddressCount: 0,
    notificationPreferences: CustomerNotificationPreferences(),
  );

  static const _profile = CustomerProfile(
    firstName: 'Juan',
    lastName: 'Dela Cruz',
    mobile: '09170000001',
    email: 'juan@demo.meditech.dev',
    birthdate: '1995-06-15',
    consentVersion: 'v1',
  );

  @override
  Future<CustomerProfile?> loadMine() async => _profile;

  @override
  Future<CustomerProfileOverview?> loadOverview() async => overview;

  @override
  Future<void> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    required String mobile,
    required DateTime birthdate,
  }) async {}

  @override
  Future<String?> uploadAvatar({
    required String fileName,
    required Uint8List bytes,
  }) async =>
      null;

  @override
  Future<List<CustomerSavedAddress>> loadSavedAddresses() async => [];

  @override
  Future<void> saveAddress(CustomerSavedAddress address, {required bool isNew}) async {}

  @override
  Future<void> deleteAddress(String id) async {}

  @override
  Future<CustomerNotificationPreferences> loadNotificationPreferences() async {
    return const CustomerNotificationPreferences();
  }

  @override
  Future<void> saveNotificationPreferences(
    CustomerNotificationPreferences prefs,
  ) async {}
}