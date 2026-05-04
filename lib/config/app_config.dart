/// Hardcoded app-level configuration.
/// Flutter clients must NEVER contain backend secrets,
/// Cloudinary secrets, Instagram tokens, or Supabase service-role keys.
/// Only the public Supabase anon key and backend base URL are kept here.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = 'https://vpshbhimgicfxgabntrb.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwc2hiaGltZ2ljZnhnYWJudHJiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0NTA1MTUsImV4cCI6MjA5MzAyNjUxNX0'
      '.ioXjoznL7EXswUjzzWZhWXYZ1xjgaNkKAluRecEb-PE';

  static const String backendUrl = 'https://socialflow1.onrender.com';

  /// Deep-link scheme registered in AndroidManifest.xml / Info.plist.
  /// The backend must redirect here after Instagram OAuth completes.
  static const String deepLinkScheme = 'socialflow';
  static const String deepLinkAuthHost = 'auth';
}

