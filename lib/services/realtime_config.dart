/// Configuration centrale de l'accès aux flux temps réel Naolib hébergés sur
/// le gateway Okina (Gravitee.io).
///
/// ────────────────────────────────────────────────────────────────────────
/// ACTIVATION DU TEMPS RÉEL LIVE
/// ────────────────────────────────────────────────────────────────────────
/// 1. Créer un compte sur https://data.nantesmetropole.fr puis souscrire au
///    jeu de données « Services d'informations en temps réel ... GTFS-RT »
///    (et/ou SIRI Lite). La souscription fournit une clé d'API Okina.
/// 2. Renseigner [okinaApiKey] ci-dessous (ou via --dart-define=OKINA_API_KEY).
/// 3. C'est tout : [GtfsRtService] et [OperatorRealtimeService] s'activent
///    automatiquement et les horaires estimés laissent place aux retards réels.
///
/// Tant que la clé est vide, toute la chaîne temps réel est désactivée et
/// l'application retombe proprement sur les horaires théoriques / l'estimation.
class RealtimeConfig {
  RealtimeConfig._();

  /// Clé d'API Okina. Vide par défaut → temps réel live désactivé.
  /// Surchargée si l'app est lancée avec `--dart-define=OKINA_API_KEY=...`.
  static const String okinaApiKey =
      String.fromEnvironment('OKINA_API_KEY', defaultValue: '');

  /// En-tête d'authentification du gateway Gravitee.io d'Okina.
  static const String apiKeyHeader = 'X-Gravitee-Api-Key';

  /// Identifiant d'organisation Naolib dans les chemins de flux GTFS-RT.
  static const String gtfsRtOrg = 'NAOLIBORG';

  /// Base des flux GTFS-RT (trip-updates / alerts / vehicle-positions).
  static const String gtfsRtBase =
      'https://api.okina.fr/gateway/semgtfsrt/realtime';

  /// Base SIRI-Lite (Stop Monitoring), variante JSON.
  static const String siriLiteBase =
      'https://api.okina.fr/gateway/sem/realtime';

  /// Vrai si une clé est configurée : conditionne toute requête live.
  static bool get isLiveEnabled => okinaApiKey.isNotEmpty;

  /// En-têtes HTTP d'authentification (vides si pas de clé).
  static Map<String, String> authHeaders() =>
      isLiveEnabled ? {apiKeyHeader: okinaApiKey} : const {};

  /// URL complète d'un flux GTFS-RT (`trip-updates`, `alerts`, ...).
  static Uri gtfsRtFeed(String feed) =>
      Uri.parse('$gtfsRtBase/$feed/$gtfsRtOrg');
}
