import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/widgets/dialogs/confirm_dialog.dart';

void main() {
  // Pressing the action button returns true
  testWidgets('confirm returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => result = await showConfirmDialog(context,
            title: 'Confirm?', whatWillHappen: const ['Something happens.'],
            actionLabel: 'Confirm reservation'),
        child: const Text('Open'),
      ),
    )));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm reservation'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('simple confirmation shows only its message and custom buttons', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showConfirmDialog(
              context,
              title: 'Accept LTO renewal?',
              message: 'Are you sure you want to accept this renewed LTO?',
              actionLabel: 'Accept',
              cancelLabel: 'Cancel',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.text('Are you sure you want to accept this renewed LTO?'),
      findsOneWidget,
    );
    expect(find.text('WHAT WILL HAPPEN'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
