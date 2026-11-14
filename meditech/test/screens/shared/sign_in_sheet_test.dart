import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/shared/sign_in_sheet.dart';
import 'package:meditech/services/auth_service.dart';
import 'package:meditech/utils/app_failure.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  // A failed sign-in stays on the sheet, over the same page
  testWidgets('lockout stays on the sheet', (tester) async {
    final fake = MockAuthService();
    when(
      () => fake.signIn(
        identifier: any(named: 'identifier'),
        password: any(named: 'password'),
        app: any(named: 'app'),
      ),
    ).thenThrow(
      const AppFailure('Too many wrong passwords. Try again in 15 minutes.'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: _GuestPage()),
      ),
    );

    await tester.tap(find.text('Reserve'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'juan@demo.meditech.dev');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Too many wrong passwords. Try again in 15 minutes.'), findsOneWidget);
    expect(find.text('Guest page'), findsOneWidget);
  });

  // A good sign-in closes the sheet and leaves the page underneath open
  testWidgets('success returns to the same page', (tester) async {
    final fake = MockAuthService();
    when(
      () => fake.signIn(
        identifier: any(named: 'identifier'),
        password: any(named: 'password'),
        app: any(named: 'app'),
      ),
    ).thenAnswer(
      (_) async => const SignedInAccount(accountType: 'customer', state: 'active'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: _GuestPage()),
      ),
    );

    await tester.tap(find.text('Reserve'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'juan@demo.meditech.dev');
    await tester.enterText(find.byType(TextFormField).at(1), 'Demo1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
    expect(find.text('Guest page'), findsOneWidget);
  });
}

class _GuestPage extends StatelessWidget {
  const _GuestPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Guest page'),
            FilledButton(
              onPressed: () => showCustomerSignInSheet(context),
              child: const Text('Reserve'),
            ),
          ],
        ),
      ),
    );
  }
}