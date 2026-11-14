import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/customer/login/login_screen.dart';
import '../widgets/theme/app_theme.dart';

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MediTech',
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}