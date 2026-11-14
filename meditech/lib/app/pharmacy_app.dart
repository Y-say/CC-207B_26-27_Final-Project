import 'package:flutter/material.dart';

import '../screens/pharmacy/sign_in/pharmacy_sign_in_screen.dart';
import '../widgets/theme/app_theme.dart';

// The pharmacy app opens on its sign-in screen
class PharmacyApp extends StatelessWidget {
  const PharmacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediTech Pharmacy',
      theme: AppTheme.light,
      home: const PharmacySignInScreen(),
    );
  }
}