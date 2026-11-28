import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/pharmacy_summary.dart';
import 'package:meditech/providers/admin_pharmacy_providers.dart';
import 'package:meditech/screens/admin/pharmacies/pharmacies_screen.dart';

void main() {
  testWidgets('standalone pharmacy screen returns to the previous dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pharmacyListProvider.overrideWith((ref) async => [])],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PharmaciesScreen(),
                  ),
                ),
                child: const Text('Dashboard'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Back to dashboard'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
  });

  // The table shows pharmacies with their status
  testWidgets('shows pharmacies and statuses', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pharmacyListProvider.overrideWith(
            (ref) async => [
              PharmacySummary(
                id: 'a',
                displayId: 'PHM-000003',
                pharmacyName: 'Demo Waiting Pharmacy',
                branchName: 'Molo Branch',
                address: 'Molo, Iloilo City',
                ownerName: 'Rosa Villareal',
                ltoNumber: 'DEMO-LTO-0003',
                ltoExpiry: DateTime(2028, 12, 31),
                status: 'pending_approval',
                submittedAt: DateTime(2026, 11, 14),
                possibleDuplicate: false,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: PharmaciesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo Waiting Pharmacy'), findsOneWidget);
    expect(find.text('Rosa Villareal'), findsOneWidget);
    expect(find.text('Pending Approval'), findsWidgets);
  });

  // Long names, every status, and several pages on narrow windows: no overflow
  for (final width in [600.0, 720.0, 900.0, 1200.0]) {
    testWidgets('no overflow at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const statuses = ['active', 'pending_approval', 'rejected', 'inactive'];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pharmacyListProvider.overrideWith(
              (ref) async => [
                for (var i = 0; i < 45; i++)
                  PharmacySummary(
                    id: '$i',
                    displayId: 'PHM-0000${i.toString().padLeft(2, '0')}',
                    pharmacyName: 'Demo Waiting Pharmacy With A Very Long Name',
                    branchName: 'La Paz Branch Across The Plaza',
                    address: 'La Paz, Iloilo City',
                    ownerName: 'Maria Santos',
                    ltoNumber: 'DEMO-LTO-$i',
                    ltoExpiry: DateTime(2028, 12, 31),
                    status: statuses[i % statuses.length],
                    submittedAt: DateTime(2026, 11, 21),
                    possibleDuplicate: i.isEven,
                  ),
              ],
            ),
          ],
          child: const MaterialApp(home: PharmaciesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  // The original two-row case from the screenshot
  testWidgets('narrow window has no overflow', (tester) async {
    tester.view.physicalSize = const Size(750, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pharmacyListProvider.overrideWith(
            (ref) async => [
              for (final (id, dup) in [('a', true), ('b', false)])
                PharmacySummary(
                  id: id,
                  displayId: 'PHM-00000$id',
                  pharmacyName: 'Demo Waiting Pharmacy With A Very Long Name',
                  branchName: 'La Paz Branch Across The Plaza',
                  address: 'La Paz, Iloilo City',
                  ownerName: 'Maria Santos',
                  ltoNumber: 'DEMO-LTO-$id',
                  ltoExpiry: DateTime(2028, 12, 31),
                  status: 'active',
                  submittedAt: DateTime(2026, 11, 21),
                  possibleDuplicate: dup,
                ),
            ],
          ),
        ],
        child: const MaterialApp(home: PharmaciesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // "LTO expiring soon" means active, with the license ending within 60 days
  test('isLtoExpiringSoon', () {
    final today = DateTime(2026, 11, 21);
    PharmacySummary branch(DateTime expiry, String status) => PharmacySummary(
      id: 'x',
      displayId: 'PHM-1',
      pharmacyName: 'P',
      branchName: 'B',
      address: 'A',
      ownerName: null,
      ltoNumber: 'L',
      ltoExpiry: expiry,
      status: status,
      submittedAt: today,
      possibleDuplicate: false,
    );

    expect(isLtoExpiringSoon(branch(DateTime(2027, 1, 20), 'active'), today), isTrue); // day 60
    expect(isLtoExpiringSoon(branch(DateTime(2027, 1, 21), 'active'), today), isFalse); // day 61
    expect(isLtoExpiringSoon(branch(DateTime(2026, 11, 1), 'active'), today), isTrue); // already expired
    expect(isLtoExpiringSoon(branch(DateTime(2026, 12, 1), 'pending_approval'), today), isFalse);
  });
}
