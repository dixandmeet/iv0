import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/driver/driver_onboarding_data.dart';
import '../supabase_service.dart';

/// Gère l'état de l'onboarding Aule Pro (première configuration du profil).
///
/// Persiste le résultat dans SharedPreferences et, pour les agents du réseau,
/// met à jour les habilitations MSR dans la table `drivers` sur Supabase.
class DriverOnboardingService with ChangeNotifier {
  static const _keyDone = 'aule_pro_onboarding_done';
  static const _keyProfile = 'aule_pro_onboarding_profile';
  static const _keyNetwork = 'aule_pro_onboarding_network';
  static const _keyDepot = 'aule_pro_onboarding_depot';
  static const _keyGender = 'aule_pro_onboarding_gender';
  static const _keyHabilitations = 'aule_pro_onboarding_habilitations';
  static const _keyVtcActivity = 'aule_pro_onboarding_vtc_activity';
  static const _keyZone = 'aule_pro_onboarding_zone';
  static const _keyMerchantType = 'aule_pro_onboarding_merchant_type';
  static const _keyMerchantName = 'aule_pro_onboarding_merchant_name';
  static const _keyMerchantAddress = 'aule_pro_onboarding_merchant_address';
  static const _keyMerchantPhone = 'aule_pro_onboarding_merchant_phone';

  final SupabaseService _supabase;

  bool _done = false;
  bool _loaded = false;
  DriverOnboardingData _savedData = const DriverOnboardingData();

  bool get isComplete => _done;
  bool get loaded => _loaded;
  DriverOnboardingData get savedData => _savedData;

  DriverOnboardingService({required SupabaseService supabaseService})
      : _supabase = supabaseService;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _done = prefs.getBool(_keyDone) ?? false;
    if (_done) _savedData = _parsePrefs(prefs);
    _loaded = true;
    notifyListeners();
  }

  DriverOnboardingData _parsePrefs(SharedPreferences prefs) {
    final habStrs = prefs.getStringList(_keyHabilitations) ?? [];
    return DriverOnboardingData(
      profile: _parseEnum(ProProfile.values, prefs.getString(_keyProfile)),
      network:
          _parseEnum(TransportNetwork.values, prefs.getString(_keyNetwork)),
      depot: _parseEnum(DriverDepot.values, prefs.getString(_keyDepot)),
      gender: _parseEnum(DriverGender.values, prefs.getString(_keyGender)),
      habilitations: habStrs
          .map((s) => _parseEnum(DriverHabilitation.values, s))
          .whereType<DriverHabilitation>()
          .toSet(),
      vtcActivity:
          _parseEnum(VtcActivity.values, prefs.getString(_keyVtcActivity)),
      zone: _parseEnum(ActivityZone.values, prefs.getString(_keyZone)),
      merchantType:
          _parseEnum(MerchantType.values, prefs.getString(_keyMerchantType)),
      merchantName: prefs.getString(_keyMerchantName) ?? '',
      merchantAddress: prefs.getString(_keyMerchantAddress) ?? '',
      merchantPhone: prefs.getString(_keyMerchantPhone) ?? '',
    );
  }

  static T? _parseEnum<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    try {
      return values.firstWhere((v) => v.name == name);
    } catch (_) {
      return null;
    }
  }

  Future<void> complete(DriverOnboardingData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDone, true);
    await _setOrRemove(prefs, _keyProfile, data.profile?.name);
    await _setOrRemove(prefs, _keyNetwork, data.network?.name);
    await _setOrRemove(prefs, _keyDepot, data.depot?.name);
    await _setOrRemove(prefs, _keyGender, data.gender?.name);
    await prefs.setStringList(
      _keyHabilitations,
      data.habilitations.map((h) => h.name).toList(),
    );
    await _setOrRemove(prefs, _keyVtcActivity, data.vtcActivity?.name);
    await _setOrRemove(prefs, _keyZone, data.zone?.name);
    await _setOrRemove(prefs, _keyMerchantType, data.merchantType?.name);
    await prefs.setString(_keyMerchantName, data.merchantName);
    await prefs.setString(_keyMerchantAddress, data.merchantAddress);
    await prefs.setString(_keyMerchantPhone, data.merchantPhone);
    await _updateSupabase(data);
    _savedData = data;
    _done = true;
    notifyListeners();
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _keyDone,
      _keyProfile,
      _keyNetwork,
      _keyDepot,
      _keyGender,
      _keyHabilitations,
      _keyVtcActivity,
      _keyZone,
      _keyMerchantType,
      _keyMerchantName,
      _keyMerchantAddress,
      _keyMerchantPhone,
    ]) {
      await prefs.remove(key);
    }
    _savedData = const DriverOnboardingData();
    _done = false;
    notifyListeners();
  }

  static Future<void> _setOrRemove(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  /// Synchronise dépôt + habilitations MSR sur Supabase (agents du réseau).
  ///
  /// Le `depot_id` est la clé de rapprochement de l'échange de services
  /// (`list_service_exchange_feed`, `se_notify_compatible`… filtrent par
  /// dépôt) : on le résout depuis le code métier choisi (table `depots`).
  Future<void> _updateSupabase(DriverOnboardingData data) async {
    if (data.profile != ProProfile.reseau) return;
    final client = _supabase.client;
    final email = client?.auth.currentUser?.email;
    if (client == null || email == null || _supabase.isOfflineMode) return;
    try {
      final code = data.depot?.code;
      String? depotId;
      if (code != null) {
        final row = await client
            .from('depots')
            .select('id')
            .eq('code', code)
            .maybeSingle();
        depotId = row?['id'] as String?;
      }
      await client.from('drivers').update({
        'depot_id': depotId,
        'msr_control': data.habilitations.contains(DriverHabilitation.controle),
        'msr_intervention':
            data.habilitations.contains(DriverHabilitation.intervention),
      }).ilike('email', email);
      debugPrint('Onboarding: Supabase updated');
    } catch (e) {
      debugPrint('Onboarding: Supabase update failed ($e)');
    }
  }
}
