import 'package:flutter/material.dart';
import '../screens/shared/connection_check_screen.dart';

// The pharmacy app
class PharmacyApp extends StatelessWidget {
  const PharmacyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'MediTech Pharmacy',
      home: ConnectionCheckScreen(appName: 'MediTech Pharmacy'),
    );
  }
}