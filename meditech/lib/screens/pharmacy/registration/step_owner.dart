import 'package:flutter/material.dart';

import '../../../utils/validators.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'registration_draft.dart';

// Step 3: the Owner account (wireframe Ph-06)
class StepOwner extends StatelessWidget {
  const StepOwner({super.key, required this.draft, required this.errors});

  final RegistrationDraft draft;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    final d = draft;
    final e = errors;
    const gap = SizedBox(height: AppSpacing.md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Create the Owner account',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        const Text('The Owner manages the branch, staff accounts, and inventory.',
            style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.lg),

        AppTextField(label: 'First name', controller: d.firstName,
            errorText: e['first_name'], validator: Validators.name),
        gap,
        AppTextField(label: 'Middle name (optional)', controller: d.middleName,
            errorText: e['middle_name'], validator: (v) => Validators.name(v, optional: true)),
        gap,
        AppTextField(label: 'Last name', controller: d.lastName,
            errorText: e['last_name'], validator: Validators.name),
        gap,
        AppTextField(label: 'Mobile number', hint: '09XX XXX XXXX', controller: d.mobile,
            errorText: e['mobile'], keyboardType: TextInputType.phone, validator: Validators.mobile),
        gap,
        AppTextField(label: 'Email', controller: d.email, errorText: e['email'],
            keyboardType: TextInputType.emailAddress, validator: Validators.email),
        gap,
        AppTextField(label: 'Username', hint: '4–20 letters, numbers, or _',
            controller: d.username, errorText: e['username'], validator: Validators.username),
        gap,
        AppPasswordField(label: 'Password', controller: d.password,
            errorText: e['password'], validator: Validators.password),
        gap,
        AppPasswordField(label: 'Confirm password', controller: d.confirmPassword,
            validator: (v) => Validators.confirmPassword(v, d.password.text)),
        gap,
        const Text('This becomes the Owner account. It stays locked until your pharmacy is approved.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ],
    );
  }
}