import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/catalogue_medicine.dart';
import 'package:meditech/providers/catalogue_providers.dart';
import 'package:meditech/screens/admin/catalogue/catalogue_screen.dart';

// A catalogue entry with sensible defaults
CatalogueMedicine med(
  String id, {
  String brand = 'Keflex',
  String generic = 'Cefalexin',
  String strength = '500 mg',
  String form = 'Capsule',
  bool isRx = true,
  String status = 'draft',
  String? reg = 'DR-TEST-0001',
  bool fda = false,
}) =>
    CatalogueMedicine(
      id: id,
      displayId: 'MED-$id',
      brandName: brand,
      genericName: generic,
      strength: strength,
      dosageForm: form,
      unitSold: 'tablet',
      isRx: isRx,
      status: status,
      registrationNumber: reg,
      fdaMatched: fda,
      pharmaciesStocking: 0,
    );

Future<void> pumpCatalogue(WidgetTester tester, List<CatalogueMedicine> rows, {Size size = const Size(1400, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [catalogueListProvider.overrideWith((ref) async => rows)],
    child: const MaterialApp(home: CatalogueScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('standalone catalogue screen returns to the previous dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogueListProvider.overrideWith((ref) async => [])],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CatalogueScreen(),
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

  // Registration, generic, brand, strength and form, and classification each get their own column
  testWidgets('shows catalogue rows in separate columns', (tester) async {
    await pumpCatalogue(tester, [med('1')]);

    expect(find.text('DR-TEST-0001'), findsOneWidget);
    expect(find.text('Cefalexin'), findsOneWidget);
    expect(find.text('Keflex'), findsOneWidget);
    expect(find.text('500 mg Capsule'), findsOneWidget);
    expect(find.text('Prescription Drug (Rx)'), findsOneWidget);
    expect(find.text('Open details'), findsNothing); // in hidden popup menu only
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Showing 1–1 of 1 medicine'), findsOneWidget);
  });

  // Draft entries read as "Pending review" on the status tab and row badge
  testWidgets('draft entries show as Pending review', (tester) async {
    await pumpCatalogue(tester, [
      med('1'),
      med('2', brand: 'Biogesic', generic: 'Paracetamol', isRx: false, status: 'active'),
    ]);

    expect(find.text('Draft'), findsNothing);
    expect(find.text('Pending review (1)'), findsOneWidget); // status tab chip
    expect(find.text('Pending review'), findsOneWidget);     // row badge only
    expect(find.text('All (2)'), findsOneWidget);
  });

  // Search filters as the admin types and updates the tab counts
  testWidgets('search narrows the table', (tester) async {
    await pumpCatalogue(tester, [
      med('1'),
      med('2', brand: 'Biogesic', generic: 'Paracetamol', isRx: false, status: 'active', reg: 'DR-XY27550'),
    ]);

    await tester.enterText(find.byType(TextField), 'xy275');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Biogesic'), findsOneWidget);
    expect(find.text('Keflex'), findsNothing);
    expect(find.text('All (1)'), findsOneWidget);
  });

  // Tapping a status tab shows only that status
  testWidgets('status tab filters the table', (tester) async {
    await pumpCatalogue(tester, [
      med('1'),
      med('2', brand: 'Biogesic', generic: 'Paracetamol', status: 'active'),
    ]);

    await tester.tap(find.text('Active (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Biogesic'), findsOneWidget);
    expect(find.text('Keflex'), findsNothing);
  });

  // Ten rows a page, with Next moving to page 2
  testWidgets('pages through long lists', (tester) async {
    await pumpCatalogue(tester, [
      for (var i = 0; i < 12; i++) med('$i', brand: 'Brand ${i.toString().padLeft(2, '0')}', generic: 'Generic $i'),
    ]);

    expect(find.text('Showing 1–10 of 12 medicines'), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 11–12 of 12 medicines'), findsOneWidget);
  });

  // Narrow screens keep every must-have column, scrolling sideways instead of overflowing
  testWidgets('narrow screen keeps must-have columns without overflow', (tester) async {
    await pumpCatalogue(
      tester,
      [
        med('1',
            brand: 'Kremil-S',
            generic: 'Aluminum Hydroxide + Magnesium Hydroxide + Simeticone',
            strength: '178 mg / 233 mg / 30 mg',
            form: 'Tablet',
            isRx: false,
            status: 'active',
            fda: true),
      ],
      size: const Size(800, 900),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Over-the-Counter (OTC) Drug'), findsOneWidget);
    expect(find.text('Kremil-S'), findsOneWidget);
  });

  // Sorting and paging on their own
  group('CatalogueView', () {
    final rows = [
      med('a', brand: 'Zeta', generic: 'Beta', reg: null),
      med('b', brand: 'Alpha', generic: 'Gamma', reg: 'DR-2'),
      med('c', brand: 'Mid', generic: 'Alpha', reg: 'DR-1'),
    ];

    test('sorts by brand both ways', () {
      final up = CatalogueView.of(rows, const CatalogueFilter(sort: CatalogueSort.brand));
      expect(up.rows.map((m) => m.brandName), ['Alpha', 'Mid', 'Zeta']);
      final down = CatalogueView.of(rows, const CatalogueFilter(sort: CatalogueSort.brand, ascending: false));
      expect(down.rows.map((m) => m.brandName), ['Zeta', 'Mid', 'Alpha']);
    });

    test('entries without a registration sort last', () {
      for (final ascending in [true, false]) {
        final v = CatalogueView.of(rows, CatalogueFilter(sort: CatalogueSort.registration, ascending: ascending));
        expect(v.rows.last.registrationNumber, isNull);
      }
    });

    test('keeps the page within range', () {
      final v = CatalogueView.of(rows, const CatalogueFilter(perPage: 2, page: 9));
      expect(v.page, 1);
      expect(v.firstShown, 3);
      expect(v.lastShown, 3);
    });
  });
}
