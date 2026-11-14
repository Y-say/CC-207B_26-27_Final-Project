import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// A text field with its label above it
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.validator,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? Function(String?)? validator;
  final String? errorText; // an error from the server
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final bool enabled;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          maxLines: maxLines,
          enabled: enabled,
          obscureText: obscureText,
          decoration: InputDecoration(hintText: hint, errorText: errorText, suffixIcon: suffix),
        ),
      ],
    );
  }
}

// A password field with a show/hide button
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({super.key, required this.label, this.controller, this.validator, this.errorText});

  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final String? errorText;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      validator: widget.validator,
      errorText: widget.errorText,
      obscureText: _hidden,
      suffix: IconButton(
        tooltip: _hidden ? 'Show password' : 'Hide password',
        icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _hidden = !_hidden),
      ),
    );
  }
}