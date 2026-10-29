import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'features/auth/patient_login_screen.dart';
import 'features/patient/patient_main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const MediTechApp());
}

class MediTechApp extends StatelessWidget {
  const MediTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF3F5F6),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF365F4C)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const PatientLoginScreen(),
        '/patient-home': (context) => const PatientMainScreen(),
      },
    );
  }
}
