import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/customer/sign_up/sign_up_screen.dart';
import 'package:meditech/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  // Confirm password must match before anything is saved
  testWidgets('mismatched passwords are shown', (tester) async {
    final fake = MockAuthService();
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: SignUpScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
    await tester.enterText(find.byType(TextFormField).at(2), 'Reyes');
    await tester.enterText(find.byType(TextFormField).at(3), '09178880009');
    await tester.enterText(find.byType(TextFormField).at(4), 'ana@test.com');
    await tester.tap(find.widgetWithText(OutlinedButton, 'mm/dd/yyyy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(5), 'Demo1234');
    await tester.enterText(find.byType(TextFormField).at(6), 'Demo1235');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  // Mobile field strips non-digits and stops at 11 digits
  testWidgets('mobile field only allows up to 11 digits', (tester) async {
    final fake = MockAuthService();
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: SignUpScreen()),
      ),
    );

    final mobileField = find.byType(TextFormField).at(3);
    await tester.enterText(mobileField, '0917-abc-888000999');
    await tester.pumpAndSettle();

    final controller = tester.widget<TextFormField>(mobileField).controller!;
    expect(controller.text, '09178880009');
  });

  // Non-09 mobile number shows live error and keeps submit disabled
  testWidgets('invalid Philippine prefix shows error and disables submit', (
    tester,
  ) async {
    final fake = MockAuthService();
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: SignUpScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
    await tester.enterText(find.byType(TextFormField).at(2), 'Reyes');
    await tester.enterText(find.byType(TextFormField).at(3), '08123456789');
    await tester.enterText(find.byType(TextFormField).at(4), 'ana@test.com');
    await tester.tap(find.widgetWithText(OutlinedButton, 'mm/dd/yyyy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(5), 'Demo1234');
    await tester.enterText(find.byType(TextFormField).at(6), 'Demo1234');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Use a Philippine mobile number starting with 09 (11 digits, e.g. 09171234567).',
      ),
      findsOneWidget,
    );
    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    expect(createButton.onPressed, isNull);
  });
}