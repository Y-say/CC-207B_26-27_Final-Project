import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/widgets/common/status_badge.dart';

void main() {
  // Database values turn into friendly words
  testWidgets('shows friendly labels', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Row(children: [
      StatusBadge.availability('low_stock'),
      StatusBadge.reservation('ready_for_pickup'),
    ])));
    expect(find.text('Low Stock'), findsOneWidget);
    expect(find.text('Ready for Pickup'), findsOneWidget);
  });
}