import 'package:flutter/material.dart';

import '../screens/customer/landing/landing_screen.dart';
import '../widgets/theme/app_theme.dart';

// The customer phone app opens on the landing page
class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediTech',
      theme: AppTheme.light,
      home: const LandingScreen(),
    );
  }
}