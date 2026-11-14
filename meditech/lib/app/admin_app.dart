import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routes/admin_routes.dart';
import '../widgets/theme/app_theme.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MediTech Admin',
      theme: AppTheme.light,
      routerConfig: ref.watch(adminRouterProvider),
    );
  }
}