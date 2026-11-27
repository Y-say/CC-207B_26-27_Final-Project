import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/employee.dart';
import '../../../services/employee_service.dart';
import '../../../utils/app_failure.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/tablet/tablet_dialogs.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';

// Shared field patterns matching the database constraints
final _namePattern = RegExp(r"^[A-Za-zÑñ .'-]{2,50}$");
final _usernamePattern = RegExp(r'^[A-Za-z0-9_]{4,20}$');
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _prcPattern = RegExp(r'^[0-9]{7}$');

String formatEmployeeDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

// Shows the one-time password once after creating an employee or resetting a password
Future<void> showTemporaryPasswordDialog(
  BuildContext context, {
  required String title,
  required String employeeName,
  required String? username,
  required String temporaryPassword,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Text(employeeName, style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (username != null && username.isNotEmpty) ...[
                      Text('Username: $username',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    const Text('Temporary password',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            temporaryPassword,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy password',
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: temporaryPassword));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Temporary password copied')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Share this password privately with the employee. They will be asked to choose a new password on their first sign-in.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 44,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E6B46),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Ph-34: Dialog to add a new pharmacist or staff member
class EmployeeProfileDraft {
  const EmployeeProfileDraft({
    required this.firstName,
    this.middleName,
    required this.lastName,
  });

  final String firstName;
  final String? middleName;
  final String lastName;
}

Future<String?> showSetEmployeeContactEmailDialog(
  BuildContext context, {
  required Employee employee,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _SetEmployeeContactEmailDialog(employee: employee),
  );
}

class _SetEmployeeContactEmailDialog extends StatefulWidget {
  const _SetEmployeeContactEmailDialog({required this.employee});

  final Employee employee;

  @override
  State<_SetEmployeeContactEmailDialog> createState() =>
      _SetEmployeeContactEmailDialogState();
}

class _SetEmployeeContactEmailDialogState extends State<_SetEmployeeContactEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _formError;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.employee.fullName;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Set contact Gmail',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '$name can use this address on branch sign-in → Forgot password.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_formError != null) ...[
                  Text(_formError!, style: const TextStyle(color: AppColors.danger)),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppTextField(
                  label: 'Gmail',
                  hint: 'name@gmail.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final trimmed = (v ?? '').trim();
                    if (trimmed.isEmpty) return 'Enter an email.';
                    return _emailPattern.hasMatch(trimmed) ? null : 'Enter a valid email.';
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (!(_formKey.currentState?.validate() ?? false)) return;
                          Navigator.of(context).pop(_email.text.trim());
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<EmployeeProfileDraft?> showEditEmployeeProfileDialog(
  BuildContext context, {
  required Employee employee,
}) {
  return showDialog<EmployeeProfileDraft>(
    context: context,
    builder: (context) => _EditEmployeeProfileDialog(employee: employee),
  );
}

class _EditEmployeeProfileDialog extends StatefulWidget {
  const _EditEmployeeProfileDialog({required this.employee});

  final Employee employee;

  @override
  State<_EditEmployeeProfileDialog> createState() =>
      _EditEmployeeProfileDialogState();
}

class _EditEmployeeProfileDialogState extends State<_EditEmployeeProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _middleName;
  late final TextEditingController _lastName;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _firstName = TextEditingController(text: e.firstName);
    _middleName = TextEditingController(text: e.middleName ?? '');
    _lastName = TextEditingController(text: e.lastName);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _save() {
    setState(() => _formError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      EmployeeProfileDraft(
        firstName: _firstName.text.trim(),
        middleName: _middleName.text.trim().isEmpty ? null : _middleName.text.trim(),
        lastName: _lastName.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Edit employee name',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.employee.displayId} · Name only. They update username and Gmail on Profile → Edit profile.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_formError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_formError!, style: const TextStyle(color: AppColors.danger)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'First name',
                        controller: _firstName,
                        validator: (v) => _namePattern.hasMatch((v ?? '').trim())
                            ? null
                            : 'Enter 2 to 50 letters.',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Last name',
                        controller: _lastName,
                        validator: (v) => _namePattern.hasMatch((v ?? '').trim())
                            ? null
                            : 'Enter 2 to 50 letters.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Middle name (optional)',
                  controller: _middleName,
                  validator: (v) {
                    final trimmed = (v ?? '').trim();
                    if (trimmed.isEmpty) return null;
                    return _namePattern.hasMatch(trimmed) ? null : 'Enter 2 to 50 letters.';
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFFD8E8DE),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A2E22),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E6B46),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Save',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<CreatedEmployee?> showAddEmployeeDialog(
  BuildContext context, {
  required Future<CreatedEmployee> Function({
    required String firstName,
    String? middleName,
    required String lastName,
    required String username,
    String? email,
    required String role,
    String? prcLicenseNo,
    DateTime? prcLicenseExpiry,
  }) onSubmit,
}) {
  return showDialog<CreatedEmployee>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _AddEmployeeDialog(onSubmit: onSubmit),
  );
}

class _AddEmployeeDialog extends StatefulWidget {
  final Future<CreatedEmployee> Function({
    required String firstName,
    String? middleName,
    required String lastName,
    required String username,
    String? email,
    required String role,
    String? prcLicenseNo,
    DateTime? prcLicenseExpiry,
  }) onSubmit;

  const _AddEmployeeDialog({required this.onSubmit});

  @override
  State<_AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<_AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _prcNo = TextEditingController();

  String _role = 'staff';
  DateTime? _prcExpiry;
  bool _busy = false;
  String? _formError;
  Map<String, String> _fieldErrors = {};

  @override
  void dispose() {
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _username.dispose();
    _email.dispose();
    _prcNo.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _prcExpiry ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) {
      setState(() {
        _prcExpiry = picked;
        _fieldErrors.remove('prc_license_expiry');
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _formError = null;
      _fieldErrors = {};
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_role == 'pharmacist' && _prcExpiry == null) {
      setState(() => _fieldErrors = {'prc_license_expiry': 'Pick the license expiry date.'});
      return;
    }

    final confirmed = await showTabletConfirmDialog(
      context: context,
      title: 'Add employee account?',
      targetName: '${_firstName.text.trim()} ${_lastName.text.trim()} (@${_username.text.trim()})',
      message:
          'Are you sure you want to create this ${_role == 'pharmacist' ? 'Pharmacist' : 'Staff'} account?',
      cancelLabel: 'Cancel',
      confirmLabel: 'Create account',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final created = await widget.onSubmit(
        firstName: _firstName.text.trim(),
        middleName: _middleName.text.trim().isEmpty ? null : _middleName.text.trim(),
        lastName: _lastName.text.trim(),
        username: _username.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        role: _role,
        prcLicenseNo: _role == 'pharmacist' ? _prcNo.text.trim() : null,
        prcLicenseExpiry: _role == 'pharmacist' ? _prcExpiry : null,
      );
      if (mounted) Navigator.of(context).pop(created);
    } on EmployeeFieldFailure catch (error) {
      if (mounted) {
        setState(() {
          _formError = error.message;
          _fieldErrors = error.fieldErrors;
        });
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _formError = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Add employee',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'Employees sign in with a username and password. Email is optional '
                  '(for password recovery); if you leave it blank, the app uses an internal sign-in address.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_formError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_formError!, style: const TextStyle(color: AppColors.danger)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'First name',
                        controller: _firstName,
                        errorText: _fieldErrors['first_name'],
                        validator: (v) => _namePattern.hasMatch((v ?? '').trim())
                            ? null
                            : 'Enter 2 to 50 letters.',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Last name',
                        controller: _lastName,
                        errorText: _fieldErrors['last_name'],
                        validator: (v) => _namePattern.hasMatch((v ?? '').trim())
                            ? null
                            : 'Enter 2 to 50 letters.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Middle name (optional)',
                  controller: _middleName,
                  errorText: _fieldErrors['middle_name'],
                  validator: (v) {
                    final trimmed = (v ?? '').trim();
                    if (trimmed.isEmpty) return null;
                    return _namePattern.hasMatch(trimmed) ? null : 'Enter 2 to 50 letters.';
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Username',
                  hint: 'e.g. jreyes_ph',
                  controller: _username,
                  errorText: _fieldErrors['username'],
                  validator: (v) => _usernamePattern.hasMatch((v ?? '').trim())
                      ? null
                      : '4 to 20 letters, numbers, or underscores.',
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Email (optional)',
                  hint: 'name@example.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _fieldErrors['email'],
                  validator: (v) {
                    final trimmed = (v ?? '').trim();
                    if (trimmed.isEmpty) return null;
                    return _emailPattern.hasMatch(trimmed)
                        ? null
                        : 'Enter a valid email.';
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Role',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'staff', label: Text('Staff')),
                    ButtonSegment(value: 'pharmacist', label: Text('Pharmacist')),
                  ],
                  selected: {_role},
                  onSelectionChanged: _busy
                      ? null
                      : (values) => setState(() => _role = values.first),
                ),
                if (_role == 'pharmacist') ...[
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'PRC license number',
                    hint: '7 digits',
                    controller: _prcNo,
                    keyboardType: TextInputType.number,
                    errorText: _fieldErrors['prc_license_no'],
                    validator: (v) => _prcPattern.hasMatch((v ?? '').trim())
                        ? null
                        : 'Enter the 7-digit PRC number.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('PRC license expiry',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickExpiry,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      _prcExpiry == null ? 'Select expiry date' : formatEmployeeDate(_prcExpiry!),
                    ),
                  ),
                  if (_fieldErrors['prc_license_expiry'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _fieldErrors['prc_license_expiry']!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFFD8E8DE),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A2E22),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E6B46),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Save employee',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Holds values returned from the PRC license editor dialog
class LicenseFormResult {
  final String prcLicenseNo;
  final DateTime prcLicenseExpiry;
  final bool markVerified;

  const LicenseFormResult({
    required this.prcLicenseNo,
    required this.prcLicenseExpiry,
    required this.markVerified,
  });
}

// Opens a dialog to enter or verify a pharmacist's (or owner's) PRC license
Future<LicenseFormResult?> showEmployeeLicenseDialog(
  BuildContext context, {
  required Employee employee,
  bool requireLicenseOnly = false,
}) {
  return showDialog<LicenseFormResult>(
    context: context,
    builder: (context) => _LicenseDialog(
      employee: employee,
      requireLicenseOnly: requireLicenseOnly,
    ),
  );
}

class _LicenseDialog extends StatefulWidget {
  final Employee employee;
  final bool requireLicenseOnly;

  const _LicenseDialog({
    required this.employee,
    required this.requireLicenseOnly,
  });

  @override
  State<_LicenseDialog> createState() => _LicenseDialogState();
}

class _LicenseDialogState extends State<_LicenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _prcNo;
  DateTime? _expiry;
  late bool _markVerified;
  String? _expiryError;

  @override
  void initState() {
    super.initState();
    _prcNo = TextEditingController(text: widget.employee.prcLicenseNo ?? '');
    _expiry = widget.employee.prcLicenseExpiry;
    _markVerified = !widget.requireLicenseOnly && widget.employee.licenseStatus == 'verified';
  }

  @override
  void dispose() {
    _prcNo.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _expiry != null && !_expiry!.isBefore(DateTime(now.year, now.month, now.day))
        ? _expiry!
        : now.add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) {
      setState(() {
        _expiry = picked;
        _expiryError = null;
      });
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_expiry == null) {
      setState(() => _expiryError = 'Pick the license expiry date.');
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_markVerified && _expiry!.isBefore(today)) {
      setState(() => _expiryError = 'Verified licenses must have an unexpired date.');
      return;
    }
    Navigator.of(context).pop(LicenseFormResult(
      prcLicenseNo: _prcNo.text.trim(),
      prcLicenseExpiry: _expiry!,
      markVerified: _markVerified,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.requireLicenseOnly
                      ? 'Promote to Pharmacist'
                      : 'PRC license · ${widget.employee.fullName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'PRC license number',
                  hint: '7 digits',
                  controller: _prcNo,
                  keyboardType: TextInputType.number,
                  validator: (v) => _prcPattern.hasMatch((v ?? '').trim())
                      ? null
                      : 'Enter the 7-digit PRC number.',
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('PRC license expiry',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    _expiry == null ? 'Select expiry date' : formatEmployeeDate(_expiry!),
                  ),
                ),
                if (_expiryError != null) ...[
                  const SizedBox(height: 4),
                  Text(_expiryError!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ],
                if (!widget.requireLicenseOnly) ...[
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mark license as verified'),
                    subtitle: const Text('Allows confirming and releasing Rx reservations'),
                    value: _markVerified,
                    onChanged: (v) => setState(() => _markVerified = v),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFFD8E8DE),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A2E22),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E6B46),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            widget.requireLicenseOnly ? 'Continue' : 'Save license',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
