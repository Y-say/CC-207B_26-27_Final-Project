import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/shared/change_password_screen.dart';
import 'package:meditech/services/auth_service.dart';

void main() {
  // The two new passwords must match before anything is saved
  testWidgets('mismatched passwords are shown', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChangePasswordScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Demo1234');
    await tester.enterText(find.byType(TextFormField).at(1), 'Newpass1');
    await tester.enterText(find.byType(TextFormField).at(2), 'Newpass2');
    await tester.tap(find.widgetWithText(FilledButton, 'Save password'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('shows confirmation modal, resets inputs, and confirms password change', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fakeAuth = _FakeAuthService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(fakeAuth),
          sessionProvider.overrideWith(() => _FakeSessionNotifier()),
        ],
        child: const MaterialApp(home: ChangePasswordScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'OldPass123');
    await tester.enterText(find.byType(TextFormField).at(1), 'NewPass123');
    await tester.enterText(find.byType(TextFormField).at(2), 'NewPass123');
    await tester.tap(find.widgetWithText(FilledButton, 'Save password'));
    await tester.pumpAndSettle();

    expect(find.text('Change password?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(fakeAuth.changePasswordCalls, 0);

    // Cancelling leaves the inputs untouched and skips saving
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Change password?'), findsNothing);
    expect(fakeAuth.changePasswordCalls, 0);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).at(0)).controller?.text,
      'OldPass123',
    );

    // Confirming calls changePassword, resets all fields, and shows confirmation
    await tester.tap(find.widgetWithText(FilledButton, 'Save password'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(fakeAuth.changePasswordCalls, 1);
    expect(find.text('Your password has been changed.'), findsWidgets);
    for (var i = 0; i < 3; i++) {
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).at(i)).controller?.text,
        '',
      );
    }
  });
}

class _FakeAuthService extends Fake implements AuthService {
  int changePasswordCalls = 0;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCalls++;
  }
}

class _FakeSessionNotifier extends SessionNotifier {
  @override
  SignedInAccount? build() => const SignedInAccount(
        accountType: 'customer',
        state: 'active',
        mustChangePassword: false,
      );
}