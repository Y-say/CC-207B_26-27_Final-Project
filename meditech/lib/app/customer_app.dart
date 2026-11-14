import 'package:flutter/material.dart';

import '../screens/shared/connection_check_screen.dart';

// The customer phone app
class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'MediTech',
      home: ConnectionCheckScreen(appName: 'MediTech'),
    );
  }
}