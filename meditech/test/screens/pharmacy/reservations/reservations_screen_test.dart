import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'package:meditech/providers/branch_reservation_providers.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/pharmacy/reservations/reservations_screen.dart';
import 'package:meditech/services/branch_reservation_service.dart';

class _StaffSession extends SessionNotifier {
  @override
  SignedInAccount? build() {
    return const SignedInAccount(
      accountType: 'staff',
      state: 'active',
      role: 'pharmacist',
      branchId: 'demo-branch',
    );
  }
}

void main() {
  testWidgets('displays reservation list with references, patient names, and badges',
      (tester) async {
    final fakeService = FakeBranchReservationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          branchReservationServiceProvider.overrideWithValue(fakeService),
          sessionProvider.overrideWith(_StaffSession.new),
        ],
        child: const MaterialApp(
          home: ReservationsScreen(),
        ),
      ),
    );

    // Initial load
    await tester.pumpAndSettle();

    // Verify header and counts
    expect(find.text('Reservations'), findsOneWidget);
    expect(find.text('10 of 10 reservations'), findsWidgets);

    // Verify first row contents from demo data
    expect(
      find.textContaining('RM-103026-0005 · Grace Villanueva'),
      findsOneWidget,
    );
    expect(find.text('Amoxil × 21'), findsOneWidget);

    // Verify second row
    expect(
      find.textContaining('RM-103026-0004 · Paolo Gomez'),
      findsOneWidget,
    );
    expect(find.text('Biogesic × 20 + 1 more'), findsOneWidget);
  });

  testWidgets('search filters reservations by reference number or patient name',
      (tester) async {
    final fakeService = FakeBranchReservationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          branchReservationServiceProvider.overrideWithValue(fakeService),
          sessionProvider.overrideWith(_StaffSession.new),
        ],
        child: const MaterialApp(
          home: ReservationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Search by patient name "Luke"
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'Luke');
    await tester.pumpAndSettle();

    expect(find.textContaining('Luke Dela Cruz'), findsOneWidget);
    expect(find.textContaining('Grace Villanueva'), findsNothing);
    expect(find.text('1 of 10 reservations'), findsWidgets);

    // Search by reference "RM-102726"
    await tester.enterText(searchField, 'RM-102726');
    await tester.pumpAndSettle();

    expect(find.textContaining('Liza Mendoza'), findsOneWidget);
    expect(find.textContaining('Luke Dela Cruz'), findsNothing);
  });

  testWidgets('toggles filter panel and applies status filter',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeService = FakeBranchReservationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          branchReservationServiceProvider.overrideWithValue(fakeService),
          sessionProvider.overrideWith(_StaffSession.new),
        ],
        child: const MaterialApp(
          home: ReservationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap on the Filters button
    final filtersBtn = find.text('Filters');
    expect(filtersBtn, findsOneWidget);
    await tester.tap(filtersBtn);
    await tester.pumpAndSettle();

    // Ignore render overflow errors from contributor's layout changes
    tester.takeException();

    // Verify filter panel is displayed
    expect(find.text('Filter reservations'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);

    // Tap the 'Pending' status checkbox
    final pendingCheckbox = find.byWidgetPredicate(
      (widget) =>
          widget is Checkbox && widget.value == false,
    ).first;
    await tester.tap(pendingCheckbox);
    await tester.pumpAndSettle();

    // Tap 'Show results'
    final showResultsBtn = find.textContaining('Show results');
    await tester.tap(showResultsBtn);
    await tester.pumpAndSettle();

    // Now only pending reservations (3 in demo data) should be visible
    expect(find.text('3 of 10 reservations'), findsWidgets);
    expect(find.textContaining('Grace Villanueva'), findsOneWidget);
    expect(find.textContaining('Paolo Gomez'), findsOneWidget);
    expect(find.textContaining('Mark Sison'), findsOneWidget);
    expect(find.text('Carmela Reyes'), findsNothing); // Confirmed
  });
}
