import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'package:meditech/providers/assistant_chat_provider.dart';
import 'package:meditech/providers/assistant_providers.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/customer/assistant/assistant_screen.dart';
import 'package:meditech/services/assistant_service.dart';
import 'package:meditech/utils/app_failure.dart';
import 'package:mocktail/mocktail.dart';

class MockAssistantService extends Mock implements AssistantService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const <Map<String, String>>[]);
    registerFallbackValue(<String, dynamic>{});
  });
  // The empty screen shows the greeting and suggested questions
  testWidgets('shows the empty assistant layout', (tester) async {
    final fake = MockAssistantService();

    await tester.pumpWidget(_app(fake));

    expect(find.text('Medipal'), findsWidgets);
    expect(find.text('How can I help you today?'), findsOneWidget);
    expect(find.text('What pharmacies are open near me right now?'), findsOneWidget);
    expect(find.text('Where can I find paracetamol 500mg?'), findsOneWidget);
    expect(find.text('Ask Medipal'), findsOneWidget);
  });

  // A reply from the function is shown under the question
  testWidgets('shows the assistant reply', (tester) async {
    final fake = MockAssistantService();
    when(
      () => fake.ask(
        any(),
        history: any(named: 'history'),
        location: any(named: 'location'),
      ),
    ).thenAnswer((_) async => 'Biogesic is listed in MediTech.');

    await tester.pumpWidget(_app(fake));
    await tester.enterText(find.byType(TextField), 'where can I find paracetamol');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.text('where can I find paracetamol'), findsOneWidget);
    expect(find.text('Biogesic is listed in MediTech.'), findsOneWidget);
  });

  // An unavailable assistant shows that message instead of a blank page
  testWidgets('shows the unavailable message', (tester) async {
    final fake = MockAssistantService();
    when(
      () => fake.ask(
        any(),
        history: any(named: 'history'),
        location: any(named: 'location'),
      ),
    ).thenThrow(const AppFailure('The assistant is unavailable.'));

    await tester.pumpWidget(_app(fake));
    await tester.enterText(find.byType(TextField), 'where can I find paracetamol');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.text('The assistant is unavailable.'), findsOneWidget);
  });

  // A guest is asked to sign in without leaving the assistant
  testWidgets('opens sign-in for a guest', (tester) async {
    final fake = MockAssistantService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantServiceProvider.overrideWithValue(fake),
          assistantChatProvider.overrideWith(AssistantChatNotifier.new),
          sessionProvider.overrideWith(_Guest.new),
        ],
        child: const MaterialApp(home: AssistantScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'where can I find paracetamol');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    verifyNever(
      () => fake.ask(
        any(),
        history: any(named: 'history'),
        location: any(named: 'location'),
      ),
    );
  });
}

class _Guest extends SessionNotifier {
  @override
  SignedInAccount? build() => null;
}

Widget _app(AssistantService fake) {
  return ProviderScope(
    overrides: [
      assistantServiceProvider.overrideWithValue(fake),
      assistantChatProvider.overrideWith(AssistantChatNotifier.new),
      sessionProvider.overrideWith(_SignedIn.new),
    ],
    child: const MaterialApp(home: AssistantScreen()),
  );
}

class _SignedIn extends SessionNotifier {
  @override
  SignedInAccount? build() {
    return const SignedInAccount(accountType: 'customer', state: 'active');
  }
}
