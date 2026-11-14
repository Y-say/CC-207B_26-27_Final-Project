import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

// Starts any of the three apps: checks settings, connects to Supabase, then shows the app
Future<void> bootstrap(Widget app) async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.check();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  runApp(ProviderScope(child: app));
}