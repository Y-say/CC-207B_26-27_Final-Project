import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/widgets/common/browse_store_card.dart';

void main() {
  testWidgets('Get directions does not fire card onTap', (tester) async {
    var cardTapped = false;
    var directionsTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowseStoreCard(
            name: 'Unlisted Pharmacy',
            addressLine: 'Lapuz, Iloilo City',
            isRegistered: false,
            onTap: () => cardTapped = true,
            onGetDirections: () => directionsTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Get directions'));
    await tester.pump();
    expect(directionsTapped, isTrue);
    expect(cardTapped, isFalse);
  });

  testWidgets('Chevron row still opens card onTap', (tester) async {
    var cardTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrowseStoreCard(
            name: 'Unlisted Pharmacy',
            addressLine: 'Lapuz, Iloilo City',
            isRegistered: false,
            onTap: () => cardTapped = true,
            onGetDirections: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Unlisted Pharmacy'));
    await tester.pump();
    expect(cardTapped, isTrue);
  });
}