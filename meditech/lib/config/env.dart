// Settings passed in when the app starts (from env/<name>.json)
class Env {
  // Where the Supabase server is
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  // The public key the app is allowed to use
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  // dev, staging, or prod
  static const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  // Stop early with a clear message if settings are missing
  static void check() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'Missing settings. Run with --dart-define-from-file=env/dev.json',
      );
    }
  }
}