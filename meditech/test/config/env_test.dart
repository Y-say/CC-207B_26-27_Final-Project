import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/config/env.dart';

void main() {
  // Without a settings file, the app should stop with a clear message
  test('missing settings are reported', () {
    expect(Env.check, throwsStateError);
  });
}