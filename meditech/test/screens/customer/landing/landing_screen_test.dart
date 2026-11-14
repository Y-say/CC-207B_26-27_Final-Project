import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/screens/customer/landing/landing_screen.dart';

void main() {
  // Sign in on the landing page opens the login form
  testWidgets('sign in opens the login screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LandingScreen()));

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or mobile'), findsOneWidget);
  });
}