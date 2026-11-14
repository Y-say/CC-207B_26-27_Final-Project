import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/screens/shared/change_password_screen.dart';

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
}