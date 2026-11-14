import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/pharmacy/sign_in/pharmacy_sign_in_screen.dart';
import 'package:meditech/services/auth_service.dart';
import 'package:meditech/utils/app_failure.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  // A locked pharmacy account shows the 15-minute message
  testWidgets('lockout message is shown', (tester) async {
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
        child: const MaterialApp(home: PharmacySignInScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'demo_pharma');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Too many wrong passwords. Try again in 15 minutes.'),
      findsOneWidget,
    );
  });
}