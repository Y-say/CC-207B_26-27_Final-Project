import 'package:flutter/material.dart';

import '../screens/shared/connection_check_screen.dart';
import '../widgets/theme/app_theme.dart';

// The customer phone app
class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediTech',
      theme: AppTheme.light,
      home: ConnectionCheckScreen(appName: 'MediTech'),
    );
  }
}