import 'package:flutter/material.dart';

import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/async_view.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/dialogs/confirm_dialog.dart';
import '../../widgets/dialogs/reason_dialog.dart';
import '../../widgets/theme/app_spacing.dart';
import '../../widgets/theme/app_theme.dart';

// Shows every shared component, for checking the design kit
class DesignGalleryScreen extends StatelessWidget {
  const DesignGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // A heading for each group
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
          child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Design kit')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const OfflineBanner(),

          heading('Buttons'),
          FilledButton(onPressed: () {}, child: const Text('Sign in')),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: () {}, child: const Text('Continue as guest')),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(style: AppTheme.dangerButton, onPressed: () {}, child: const Text('Reject')),
          TextButton(onPressed: () {}, child: const Text('Forgot password?')),

          heading('Badges'),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            for (final s in ['available', 'low_stock', 'unavailable', 'unconfirmed'])
              StatusBadge.availability(s),
            for (final s in ['pending', 'confirmed', 'ready_for_pickup', 'completed',
                             'rejected', 'cancelled', 'expired'])
              StatusBadge.reservation(s),
            const StatusBadge.rx(),
          ]),

          heading('Fields'),
          const AppTextField(label: 'Email address', hint: 'you@example.com'),
          const SizedBox(height: AppSpacing.md),
          const AppTextField(label: 'Mobile number', hint: '09XX XXX XXXX',
              errorText: 'Use 11 digits starting with 09.'),
          const SizedBox(height: AppSpacing.md),
          const AppPasswordField(label: 'Password'),

          heading('Card'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Biogesic · Paracetamol · 500 mg · Tablet'),
            ),
          ),

          heading('Dialogs'),
          OutlinedButton(
            child: const Text('Confirm dialog'),
            onPressed: () => showConfirmDialog(
              context,
              title: 'Confirm RM-103026-0005?',
              subject: 'Grace Villanueva · Amoxil × 21',
              whatWillHappen: const [
                'Holds Amoxil × 21 from your stock until pickup, cancellation, or expiry.',
                'Generates a pickup code and notifies Grace Villanueva.',
              ],
              actionLabel: 'Confirm reservation',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            child: const Text('Reason dialog'),
            onPressed: () => showReasonDialog(
              context,
              title: 'Reject reservation',
              description: 'The patient is notified and sees your reason.',
              actionLabel: 'Reject',
              hint: 'e.g. The prescription image is unclear.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            child: const Text('Snackbar'),
            onPressed: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Added to cart.'))),
          ),

          heading('States'),
          const SizedBox(height: 160, child: StateMessage(
              icon: Icons.inbox_outlined, message: 'No matching medicines found.')),
          SizedBox(height: 200, child: StateMessage(
              icon: Icons.error_outline, message: 'Something went wrong. Please try again.',
              onRetry: () {})),
        ],
      ),
    );
  }
}