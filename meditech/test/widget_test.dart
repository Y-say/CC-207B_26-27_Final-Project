import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/main.dart';

void main() {
  testWidgets('patient login screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MediTechApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
