import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routes/customer_routes.dart';
import '../widgets/theme/app_theme.dart';

class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MediTech',
      theme: AppTheme.light,
      routerConfig: ref.watch(customerRouterProvider),
    );
  }
}