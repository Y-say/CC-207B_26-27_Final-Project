import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/registration_providers.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'registration_draft.dart';
import 'step_pharmacy.dart';

// The 4-step "Register your pharmacy" form (wireframes Ph-02 to Ph-08)
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  static const _stepNames = ['Pharmacy', 'License', 'Owner account', 'Review'];

  final _draft = RegistrationDraft();
  final _forms = List.generate(4, (_) => GlobalKey<FormState>());

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  // Check this step's fields, then move on
  void _continue(int step) {
    final valid = _forms[step].currentState?.validate() ?? false;
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fix the highlighted fields to continue.')));
      return;
    }
    ref.read(registrationControllerProvider.notifier).goTo(step + 1);
  }

  void _back(int step) => ref.read(registrationControllerProvider.notifier).goTo(step - 1);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationControllerProvider);
    final step = state.step;

    final body = switch (step) {
      0 => StepPharmacy(draft: _draft, errors: state.fieldErrors),
      _ => const Text('Coming next.'),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register your pharmacy'),
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
                      Text('STEP ${step + 1} OF 4',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                              color: AppColors.textMuted, letterSpacing: 0.5)),
                      const SizedBox(height: AppSpacing.sm),
                      body,

                      // A problem from the server, shown above the buttons
                      if (state.error != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(state.error!,
                              style: const TextStyle(color: AppColors.danger)),
                        ),
                      ],

                      // Back and Continue
                      const SizedBox(height: AppSpacing.xl),
                      Row(children: [
                        if (step > 0)
                          OutlinedButton(onPressed: () => _back(step), child: const Text('Back')),
                        const Spacer(),
                        if (step < 3)
                          FilledButton(onPressed: () => _continue(step), child: const Text('Continue')),
                      ]),
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
              backgroundColor: i <= current ? AppColors.primary : AppColors.neutralLight,
              child: i < current
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text('${i + 1}',
                      style: TextStyle(fontSize: 12,
                          color: i <= current ? Colors.white : AppColors.neutral)),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(names[i],
                style: TextStyle(fontWeight: i == current ? FontWeight.w700 : FontWeight.w400)),
            if (i < names.length - 1) const SizedBox(width: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}