import 'package:flutter/material.dart';
import '../screens/shared/connection_check_screen.dart';

// The admin app
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'MediTech Admin',
      home: ConnectionCheckScreen(appName: 'MediTech Admin'),
    );
  }
}