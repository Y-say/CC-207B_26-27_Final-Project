import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/pharmacy_application.dart';
import '../services/registration_service.dart';

// Gives screens the registration service
final registrationServiceProvider = Provider<RegistrationService>(
  (ref) => RegistrationService(http.Client()),
);

// What the registration screen needs to know right now
class RegistrationState {
  const RegistrationState({
    this.step = 0,
    this.submitting = false,
    this.error,
    this.fieldErrors = const {},
    this.applicationId,
  });

  final int step; // 0 to 3
  final bool submitting;
  final String? error;
  final Map<String, String> fieldErrors;
  final String? applicationId; // set once submitted

  RegistrationState copyWith({
    int? step,
    bool? submitting,
    String? error,
    Map<String, String>? fieldErrors,
    String? applicationId,
  }) {
    return RegistrationState(
      step: step ?? this.step,
      submitting: submitting ?? this.submitting,
      error: error,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      applicationId: applicationId ?? this.applicationId,
    );
  }
}

// Moves between steps and submits the application
class RegistrationController extends Notifier<RegistrationState> {
  @override
  RegistrationState build() => const RegistrationState();

  // Go to a step (Continue, Back, or an Edit link)
  void goTo(int step) => state = state.copyWith(step: step);

  // Send the application; on errors, jump back to the step with the problem
  Future<void> submit(PharmacyApplication application) async {
    state = state.copyWith(submitting: true, fieldErrors: {});
    try {
      final id = await ref.read(registrationServiceProvider).submit(application);
      state = state.copyWith(submitting: false, applicationId: id);
    } on RegistrationException catch (e) {
      state = state.copyWith(
        submitting: false,
        error: e.message,
        fieldErrors: e.fieldErrors,
        step: _stepFor(e.fieldErrors),
      );
    }
  }

  // Which step a field belongs to
  int _stepFor(Map<String, String> fields) {
    const license = {'lto_number', 'lto_expiry', 'lto_file', 'storefront_file'};
    const owner = {'first_name', 'middle_name', 'last_name', 'mobile', 'email', 'username', 'password'};
    if (fields.keys.any((k) => !license.contains(k) && !owner.contains(k))) return 0;
    if (fields.keys.any(license.contains)) return 1;
    if (fields.keys.any(owner.contains)) return 2;
    return state.step;
  }
}

final registrationControllerProvider =
    NotifierProvider<RegistrationController, RegistrationState>(RegistrationController.new);