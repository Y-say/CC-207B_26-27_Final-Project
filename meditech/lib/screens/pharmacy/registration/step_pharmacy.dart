import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../utils/validators.dart';
import '../../../widgets/common/app_text_field.dart';
import '../../../widgets/theme/app_colors.dart';
import '../../../widgets/theme/app_spacing.dart';
import 'registration_draft.dart';

// Step 1: pharmacy details, opening hours, and store location (wireframe Ph-02 to Ph-04)
class StepPharmacy extends StatefulWidget {
  const StepPharmacy({super.key, required this.draft, required this.errors});

  final RegistrationDraft draft;
  final Map<String, String> errors; // problems the server found

  @override
  State<StepPharmacy> createState() => _StepPharmacyState();
}

class _StepPharmacyState extends State<StepPharmacy> {
  static const _dayLetters = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  bool _locating = false;

  RegistrationDraft get d => widget.draft;

  // Pick an opening or closing time
  Future<void> _pickTime(bool opening) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: opening ? d.opensAt : d.closesAt,
    );
    if (picked == null) return;
    setState(() => opening ? d.opensAt = picked : d.closesAt = picked);
  }

  // Fill in the map pin from the device's location
  Future<void> _useCurrentLocation() async {
    void tell(String message) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        tell('Turn on location, or type the coordinates below.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        tell('Location permission was denied. Type the coordinates below instead.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        d.latitude.text = position.latitude.toStringAsFixed(6);
        d.longitude.text = position.longitude.toStringAsFixed(6);
      });
    } catch (_) {
      tell('Could not get your location. Type the coordinates below instead.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // Coordinates must be real numbers in range
  String? _coordinate(String? value, double limit) {
    final n = double.tryParse(value ?? '');
    if (n == null) return 'Set the store location.';
    return (n < -limit || n > limit) ? 'Not a valid location.' : null;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.errors;
    const gap = SizedBox(height: AppSpacing.md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tell us about your pharmacy',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        const Text('One application per branch. Use the details printed on your License to Operate.',
            style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.lg),

        // Names
        AppTextField(label: 'Pharmacy name', hint: 'As written on your LTO',
            controller: d.pharmacyName, errorText: e['pharmacy_name'],
            validator: (v) => Validators.required(v)),
        gap,
        AppTextField(label: 'Branch name', hint: 'e.g. Main Branch',
            controller: d.branchName, errorText: e['branch_name'],
            validator: (v) => Validators.required(v)),
        gap,
        AppTextField(label: 'Address (as written on your LTO)', hint: 'Street, barangay, city',
            controller: d.address, errorText: e['address'],
            validator: (v) => Validators.required(v)),
        gap,

        // Contact details
        AppTextField(label: 'Contact number', hint: '0333201234 or 09171234567',
            controller: d.contactNumber, errorText: e['contact_number'],
            keyboardType: TextInputType.phone, validator: Validators.contactNumber),
        gap,
        AppTextField(label: 'Pharmacy email', hint: 'branch@example.com',
            controller: d.pharmacyEmail, errorText: e['pharmacy_email'],
            keyboardType: TextInputType.emailAddress, validator: Validators.email),
        const SizedBox(height: AppSpacing.lg),

        // Days open
        const Text('Days open', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var day = 0; day < 7; day++)
              FilterChip(
                label: Text(_dayLetters[day]),
                selected: d.openDays.contains(day),
                onSelected: (on) => setState(() => on ? d.openDays.add(day) : d.openDays.remove(day)),
              ),
          ],
        ),
        if (e['hours'] != null)
          Text(e['hours']!, style: const TextStyle(color: AppColors.danger)),
        gap,

        // Opening and closing time
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickTime(true),
              child: Text('Opens at ${d.opensAt.format(context)}'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickTime(false),
              child: Text('Closes at ${d.closesAt.format(context)}'),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),

        // Store location
        const Text('Store location', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          "Do this while you're at the store for the most accurate pin. "
          'Patients get directions to this exact spot.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _locating ? null : _useCurrentLocation,
          icon: _locating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location),
          label: const Text('Use my current location'),
        ),
        gap,
        Row(children: [
          Expanded(
            child: AppTextField(label: 'Latitude', hint: '10.720200', controller: d.latitude,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                errorText: e['location'], validator: (v) => _coordinate(v, 90)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppTextField(label: 'Longitude', hint: '122.562100', controller: d.longitude,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: (v) => _coordinate(v, 180)),
          ),
        ]),
      ],
    );
  }
}