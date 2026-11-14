import 'package:flutter/material.dart';

import '../screens/pharmacy/registration/registration_screen.dart';
import '../widgets/theme/app_theme.dart';

// The pharmacy tablet app
class PharmacyApp extends StatelessWidget {
  const PharmacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediTech Pharmacy',
      theme: AppTheme.light,
      // Temporary: opens registration directly until sign-in and routing are ready
      home: const RegistrationScreen(),
    );
  }
}