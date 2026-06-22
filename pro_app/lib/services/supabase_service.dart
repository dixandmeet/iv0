import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseService with ChangeNotifier {

  SupabaseClient? _client;
  // Vrai quand aucun backend live n'est joignable. Dans ce cas, l'app affiche
  // les vraies données TAN embarquées en assets, mais sans couche communautaire
  // temps réel (véhicules / signalements live), qui nécessite Supabase.
  bool _isOfflineMode = false;
  String? _deviceId;
  String? _deviceUuid; // UUID de la table anonymous_devices
  bool _consentBackground = false;

  bool get isOfflineMode => _isOfflineMode;
  SupabaseClient? get client => _client;
  String get deviceId => _deviceId ?? 'local_device_id';
  String get deviceUuid => _deviceUuid ?? '00000000-0000-0000-0000-000000000000';

  /// UUID réel de l'appareil en BDD, ou null s'il n'a pas pu être enregistré
  /// (à utiliser pour les colonnes avec clé étrangère vers anonymous_devices).
  String? get registeredDeviceUuid => _deviceUuid;
  bool get consentBackground => _consentBackground;

  // Initialisation du service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Génère ou récupère un ID unique anonyme pour l'appareil.
    // Repli sur les anciennes clés `wazibus_*` pour préserver l'identité device
    // et le consentement des installs existants après le rebrand Aule.
    _deviceId =
        prefs.getString('aule_device_id') ?? prefs.getString('wazibus_device_id');
    _deviceId ??= const Uuid().v4();
    await prefs.setString('aule_device_id', _deviceId!);

    _consentBackground = prefs.getBool('aule_consent_background') ??
        prefs.getBool('wazibus_consent_background') ??
        false;

    // Tentative d'initialisation de Supabase
    try {
      if (SupabaseConfig.isPlaceholder) {
        // Aucune clé Supabase configurée : on reste hors-ligne (données TAN locales).
        _isOfflineMode = true;
        debugPrint('Aule: Supabase keys not set. Running offline (local TAN data).');
      } else {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.publishableKey,
        );
        _client = Supabase.instance.client;
        _isOfflineMode = false;
        debugPrint('Aule: Supabase initialized successfully.');

        // Connexion anonyme
        await _authenticateAnonymously();
      }
    } catch (e) {
      _isOfflineMode = true;
      debugPrint('Aule: Failed to initialize Supabase ($e). Falling back to offline (local TAN data).');
    }
  }

  // Authentification anonyme Supabase
  Future<void> _authenticateAnonymously() async {
    if (_client == null || _isOfflineMode) return;

    try {
      // Supabase gère la connexion anonyme de manière transparente si configurée
      final session = _client!.auth.currentSession;
      if (session == null) {
        final AuthResponse res = await _client!.auth.signInAnonymously();
        debugPrint('Aule: Logged in anonymously as ${res.user?.id}');
      }

      // Enregistre l'appareil dans la table anonymous_devices
      await _registerDeviceInDatabase();
    } catch (e) {
      debugPrint('Aule: Auth error ($e). Switching to offline (local TAN data).');
      _isOfflineMode = true;
    }
  }

  // Enregistre ou met à jour l'appareil en BDD Supabase
  Future<void> _registerDeviceInDatabase() async {
    if (_client == null || _isOfflineMode) return;

    try {
      final res = await _client!
          .from('anonymous_devices')
          .upsert({
            'device_token': _deviceId,
            'consent_background_tracking': _consentBackground,
            'last_seen_at': DateTime.now().toIso8601String(),
          }, onConflict: 'device_token')
          .select('id')
          .single();
      
      _deviceUuid = res['id'] as String;
      debugPrint('Aule: Device registered in DB with UUID: $_deviceUuid');
    } catch (e) {
      debugPrint('Aule: Error registering device in DB ($e)');
    }
  }

  // Met à jour le consentement RGPD pour le suivi en arrière-plan
  Future<void> updateBackgroundConsent(bool consented) async {
    _consentBackground = consented;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('aule_consent_background', consented);

    if (!_isOfflineMode && _client != null) {
      try {
        await _client!.from('anonymous_devices').update({
          'consent_background_tracking': consented,
          'last_seen_at': DateTime.now().toIso8601String(),
        }).eq('device_token', deviceId);
      } catch (e) {
        debugPrint('Aule: Failed to sync consent to DB ($e)');
      }
    }
    notifyListeners();
  }
}
