import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/registration_providers.dart';
import '../../../providers/session_providers.dart';
import '../../../widgets/common/async_view.dart';
import '../../../widgets/dialogs/confirm_dialog.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'registration_draft.dart';
import 'step_license.dart';
import 'step_owner.dart';
import 'step_pharmacy.dart';
import 'step_review.dart';

// The 4-step pharmacy form: new registration, or fixing a rejected one (Ph-02 to Ph-08)
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key, this.editing = false});

  final bool editing; // true when fixing a rejected application

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  static const _stepNames = ['Pharmacy', 'License', 'Owner account', 'Review'];

  // Friendly names for fields the server may reject
  static const _fieldNames = {
    'pharmacy_name': 'Pharmacy name',
    'branch_name': 'Branch name',
    'address': 'Address',
    'contact_number': 'Contact number',
    'pharmacy_email': 'Pharmacy email',
    'location': 'Store location',
    'hours': 'Opening hours',
    'lto_number': 'FDA LTO number',
    'lto_expiry': 'LTO expiry date',
    'lto_file': 'LTO document',
    'storefront_file': 'Storefront photo',
    'first_name': 'First name',
    'middle_name': 'Middle name',
    'last_name': 'Last name',
    'mobile': 'Mobile number',
    'email': 'Email',
    'username': 'Username',
    'password': 'Password',
  };

  final _draft = RegistrationDraft();
  final _forms = List.generate(4, (_) => GlobalKey<FormState>());

  bool _loading = false;
  String? _loadError;
  String _displayId = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(registrationControllerProvider.notifier).reset(),
    );
    _draft.editing = widget.editing;
    if (widget.editing) _load();
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  RegistrationController get _controller =>
      ref.read(registrationControllerProvider.notifier);

  // Fill the form from the rejected application
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final json = await ref.read(resubmitServiceProvider).load();
      if (json == null) {
        setState(() => _loadError = 'No application found for this account.');
        return;
      }
      _draft.fillFrom(json);
      _displayId = json['display_id'] as String;
    } catch (_) {
      setState(
        () => _loadError = 'Could not load your application. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Check this step's fields; true if everything is filled in correctly
  bool _valid(int step) {
    final valid = _forms[step].currentState?.validate() ?? false;
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fix the highlighted fields to continue.'),
        ),
      );
    }
    return valid;
  }

  // Ask first, then send (new application or resubmission)
  Future<void> _submit() async {
    if (!_valid(3)) return;
    final ok = await showConfirmDialog(
      context,
      title: widget.editing
          ? 'Resubmit your application?'
          : 'Submit your application?',
      message: widget.editing
          ? 'Are you sure you want to resubmit this pharmacy application?'
          : 'Are you sure you want to submit this pharmacy application?',
      cancelLabel: 'Cancel',
      actionLabel: widget.editing
          ? 'Resubmit'
          : 'Submit application',
    );
    if (!ok) return;

    if (widget.editing) {
      await _controller.resubmit(
        _draft.toResubmitJson(),
        ltoFile: _draft.ltoFile,
        storefrontFile: _draft.storefrontFile,
        displayId: _displayId,
      );
    } else {
      await _controller.submit(_draft.toApplication());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationControllerProvider);
    final step = state.step;

    // Edit mode: wait for the old application to load
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit and resubmit')),
        body: StateMessage(
          icon: Icons.error_outline,
          message: _loadError!,
          onRetry: _load,
        ),
      );
    }

    // Done: show the success view instead of the form
    if (state.applicationId != null) {
      return _SubmittedView(
        applicationId: state.applicationId!,
        email: _draft.email.text,
        resubmitted: widget.editing,
        onHome: () async {
          await ref.read(sessionProvider.notifier).signOut();
          if (context.mounted) context.go('/');
        },
      );
    }

    // The current step's fields
    final body = switch (step) {
      0 => StepPharmacy(draft: _draft, errors: state.fieldErrors),
      1 => StepLicense(draft: _draft, errors: state.fieldErrors),
      2 => StepOwner(draft: _draft, errors: state.fieldErrors),
      _ => StepReview(draft: _draft, onEdit: _controller.goTo),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editing ? 'Edit and resubmit' : 'Register your pharmacy',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: _StepHeader(current: step, names: _stepNames),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: _forms[step],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP ${step + 1} OF 4',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      body,

                      // A problem from the server, with each field listed
                      if (state.error != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.error!,
                                style: const TextStyle(color: AppColors.danger),
                              ),
                              for (final entry in state.fieldErrors.entries)
                                Text(
                                  '• ${_fieldNames[entry.key] ?? entry.key}: ${entry.value}',
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],

                      // Back, and Continue or Submit
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          if (step > 0)
                            OutlinedButton(
                              onPressed: state.submitting
                                  ? null
                                  : () => _controller.goTo(step - 1),
                              child: const Text('Back'),
                            ),
                          const Spacer(),
                          if (step < 3)
                            FilledButton(
                              onPressed: () {
                                if (_valid(step)) _controller.goTo(step + 1);
                              },
                              child: const Text('Continue'),
                            )
                          else
                            FilledButton(
                              onPressed: state.submitting ? null : _submit,
                              child: state.submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      widget.editing
                                          ? 'Resubmit application'
                                          : 'Submit application',
                                    ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Shown after a successful submit or resubmit
class _SubmittedView extends StatelessWidget {
  const _SubmittedView({
    required this.applicationId,
    required this.email,
    this.resubmitted = false,
    required this.onHome,
  });

  final String applicationId;
  final String email;
  final bool resubmitted;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(
                        Icons.check,
                        color: AppColors.primary,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      resubmitted
                          ? 'Application resubmitted'
                          : 'Application submitted',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      resubmitted
                          ? 'Application ID: $applicationId\n'
                                "We'll notify you once it's reviewed."
                          : 'Application ID: $applicationId\n'
                                "We'll email $email once your application is reviewed.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (resubmitted)
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Back to status'),
                      )
                    else
                      FilledButton(
                        onPressed: onHome,
                        child: const Text('Back to homepage'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Numbered steps across the top; on narrow screens, just "Step 2 of 4"
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.current, required this.names});

  final int current;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    if (narrow) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text('Step ${current + 1} of 4 · ${names[current]}'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < names.length; i++) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: i <= current
                  ? AppColors.primary
                  : AppColors.neutralLight,
              child: i < current
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: i <= current ? Colors.white : AppColors.neutral,
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              names[i],
              style: TextStyle(
                fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            if (i < names.length - 1) const SizedBox(width: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}
