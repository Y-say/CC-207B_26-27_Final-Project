import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

// Asks for a reason (5 to 200 characters); returns it, or null if cancelled
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String description,
  required String actionLabel,
  String hint = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ReasonDialog(
      title: title, description: description, actionLabel: actionLabel, hint: hint),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title, required this.description, required this.actionLabel, required this.hint});

  final String title;
  final String description;
  final String actionLabel;
  final String hint;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                Text(widget.description),
                const SizedBox(height: AppSpacing.md),
                // The reason, with a character counter
                TextFormField(
                  controller: _reason,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: InputDecoration(hintText: widget.hint),
                  validator: (v) => (v == null || v.trim().length < 5)
                      ? 'Write at least 5 characters.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      style: AppTheme.dangerButton,
                      onPressed: () {
                        if (_form.currentState!.validate()) {
                          Navigator.pop(context, _reason.text.trim());
                        }
                      },
                      child: Text(widget.actionLabel),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}