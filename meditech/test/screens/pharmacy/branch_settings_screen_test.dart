import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meditech/models/branch_settings.dart';
import 'package:meditech/models/signed_in_account.dart';
import 'package:meditech/providers/branch_settings_providers.dart';
import 'package:meditech/providers/session_providers.dart';
import 'package:meditech/screens/pharmacy/branch_settings/branch_settings_screen.dart';
import 'package:meditech/services/branch_settings_service.dart';

class _FakeBranchSettingsService implements BranchSettingsService {
  @override
  Future<BranchSettings> loadSettings() async {
    return const BranchSettings(
      branchId: 'b-1',
      pharmacyName: 'Supreme Pharmacy',
      branchName: 'La Paz Branch',
      address: 'La Paz, Iloilo City',
      contactNumber: '09171234567',
      operatingHours: 'Mon-Sun, 8:00 AM – 9:00 PM',
      fdaLto: 'LTO-3000-000001',
    );
  }

  @override
  Future<void> updateSettings({
    required String branchId,
    required String address,
    required String contactNumber,
    required String operatingHours,
    double? latitude,
    double? longitude,
    bool updateBranchDetails = true,
  }) async {}
}

class _OwnerSession extends SessionNotifier {
  @override
  SignedInAccount? build() {
    return const SignedInAccount(
      accountType: 'pharmacy',
      state: 'active',
      role: 'owner',
      branchId: 'b-1',
    );
  }
}

class _StaffSession extends SessionNotifier {
  @override
  SignedInAccount? build() {
    return const SignedInAccount(
      accountType: 'pharmacy',
      state: 'active',
      role: 'staff',
      branchId: 'b-1',
    );
  }
}

void main() {
  testWidgets(
    'BranchSettingsScreen renders branch details and FDA LTO for owner',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            branchSettingsServiceProvider
                .overrideWithValue(_FakeBranchSettingsService()),
            sessionProvider.overrideWith(_OwnerSession.new),
          ],
          child: const MaterialApp(home: BranchSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Branch settings'), findsOneWidget);
      expect(find.text('Supreme Pharmacy'), findsOneWidget);
      expect(find.text('La Paz Branch'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.textContaining('FDA License to Operate'), findsOneWidget);
      expect(find.textContaining('PRC'), findsNothing);
      expect(find.text('Pharmacy picture'), findsOneWidget);
    },
  );

  testWidgets(
    'BranchSettingsScreen hides save for staff and has no PRC fields',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            branchSettingsServiceProvider
                .overrideWithValue(_FakeBranchSettingsService()),
            sessionProvider.overrideWith(_StaffSession.new),
          ],
          child: const MaterialApp(home: BranchSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Branch settings'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
      expect(find.textContaining('PRC'), findsNothing);
    },
  );
}