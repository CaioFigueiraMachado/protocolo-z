/// Configuração do Supabase.
///
/// A chave abaixo é a chave PÚBLICA (anon). Ela pode ficar no app porque
/// toda a segurança é feita pela RLS e pelas funções RPC no banco.
/// A chave `service_role` NUNCA deve aparecer no app nem no repositório.
///
/// Para usar outro projeto sem editar o código:
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://guewwoaocvenroujloch.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd1ZXd3b2FvY3ZlbnJvdWpsb2NoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ1NTAwMjcsImV4cCI6MjExMDEyNjAyN30.qAYp3LVw06Z3HGtQv1NtNfFqLjyaG2GtwsU_R8IVsCg',
  );
}
