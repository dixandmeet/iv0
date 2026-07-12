class BackendConfig {
  const BackendConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rllcdvuqduuyhdcifiwp.supabase.co',
  );

  // Clé publishable Supabase : elle est conçue pour être embarquée dans le
  // client. Les droits effectifs restent protégés par les politiques RLS.
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_SoVrtwgKHm3lkFaW8r5fmA_HEH7VpL6',
  );

  static const naolibDatasetId =
      '244400404_transports_commun_naolib_nantes_metropole_gtfs';
  static const naolibCatalogUrl =
      'https://data.nantesmetropole.fr/api/explore/v2.1/catalog/datasets/'
      '$naolibDatasetId/records?limit=1';
}
