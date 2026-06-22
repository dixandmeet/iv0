/// Configuration Supabase partagée par les apps Aule (voyageur & pro) et,
/// à terme, alignée avec le dashboard web.
///
/// Source de vérité unique des identifiants backend : pour migrer de projet
/// Supabase, on ne modifie QUE ce fichier (cf. commit « migration Supabase »).
class SupabaseConfig {
  const SupabaseConfig._();

  /// URL du projet Supabase.
  static const String url = 'https://rllcdvuqduuyhdcifiwp.supabase.co';

  /// Clé publishable (anon) du projet.
  static const String publishableKey =
      'sb_publishable_SoVrtwgKHm3lkFaW8r5fmA_HEH7VpL6';

  /// Vrai tant que les identifiants n'ont pas été renseignés.
  static bool get isPlaceholder =>
      url.contains('your-supabase-project') ||
      publishableKey.contains('your-anon-public-key');
}
