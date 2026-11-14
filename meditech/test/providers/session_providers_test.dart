import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/services/auth_service.dart';
import 'package:meditech/utils/app_failure.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  // A locked account stays signed out and keeps the 15-minute message
  test('a lockout does not sign anyone in', () async {
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

    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(
      () => container.read(sessionProvider.notifier).signIn(
            identifier: 'demo_pharma',
            password: 'wrong',
            app: 'pharmacy',
          ),
      throwsA(
        isA<AppFailure>().having(
          (error) => error.message,
          'message',
          'Too many wrong passwords. Try again in 15 minutes.',
        ),
      ),
    );
    expect(container.read(sessionProvider), isNull);
  });
}
