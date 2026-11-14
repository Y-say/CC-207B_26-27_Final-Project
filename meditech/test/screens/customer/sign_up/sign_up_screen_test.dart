import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/screens/customer/sign_up/sign_up_screen.dart';

void main() {
  // Confirm password must match before anything is saved
  testWidgets('mismatched passwords are shown', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SignUpScreen())),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
    await tester.enterText(find.byType(TextFormField).at(2), 'Reyes');
    await tester.enterText(find.byType(TextFormField).at(3), '09178880009');
    await tester.enterText(find.byType(TextFormField).at(4), 'ana@test.com');
    await tester.tap(find.text('Choose birthdate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(5), 'Demo1234');
    await tester.enterText(find.byType(TextFormField).at(6), 'Demo1235');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });
}