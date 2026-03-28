class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wfedjijaprrpahdijgau.supabase.co',
  );

  // Publishable/anon key (ok to embed in client apps).
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_cN11XAyvRUYNqz4WZOvLEg_8Kdd1Yuc',
  );
}

