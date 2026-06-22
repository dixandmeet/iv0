import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/driver/driver_profile.dart';
import '../../models/driver/driver_service_record.dart';
import '../auth_service.dart';
import '../location_service.dart';
import '../supabase_service.dart';

/// Logique métier du mode conducteur :
/// - détection du rôle (présence dans la table `drivers` par e-mail) ;
/// - service du jour, prise et fin de service ;
/// - remontée GPS vers `vehicle_positions` tant que le service est actif.
class DriverService with ChangeNotifier {
  final SupabaseService _supabase;
  final LocationService _location;
  AuthService _auth;

  DriverService({
    required SupabaseService supabaseService,
    required AuthService authService,
    required LocationService locationService,
  })  : _supabase = supabaseService,
        _auth = authService,
        _location = locationService {
    syncWithAuth(authService);
  }

  // --- État rôle / chargement ---
  bool _loading = true;
  DriverProfile? _driver;
  String? _lastSyncedEmail;

  bool get loading => _loading;
  DriverProfile? get driver => _driver;
  bool get isDriver => _driver != null;

  // --- Service du jour / en cours ---
  DriverServiceRecord? _currentService;
  DriverServiceRecord? _completedService; // résumé fin de service
  bool _busy = false; // opération réseau en cours (start/end)
  String? _errorMessage;

  DriverServiceRecord? get currentService => _currentService;
  DriverServiceRecord? get completedService => _completedService;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;
  bool get hasActiveService => _currentService?.isRunning ?? false;

  // --- GPS ---
  StreamSubscription<Position>? _gpsSub;
  Timer? _uploadTimer;
  Position? _lastPosition;
  bool _gpsActive = false;
  DateTime? _lastUploadAt;

  bool get gpsActive => _gpsActive;
  Position? get lastPosition => _lastPosition;

  // --- Avance / retard auto-déclaré (minutes ; + = retard, - = avance) ---
  int _delayMinutes = 0;
  int get delayMinutes => _delayMinutes;

  /// Réagit à un changement d'authentification (appelé par le ProxyProvider).
  void syncWithAuth(AuthService auth) {
    _auth = auth;
    final email = auth.email?.toLowerCase();
    if (email == _lastSyncedEmail && !_loading) return;
    _lastSyncedEmail = email;
    _loadDriver();
  }

  Future<void> _loadDriver() async {
    _loading = true;
    notifyListeners();

    final client = _supabase.client;
    final email = _auth.email;
    if (_supabase.isOfflineMode || client == null || email == null) {
      // Déconnexion / session anonyme : on coupe toute remontée GPS résiduelle.
      await _stopGpsTracking();
      _driver = null;
      _currentService = null;
      _completedService = null;
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      final row = await client
          .from('drivers')
          .select()
          .ilike('email', email)
          .maybeSingle();
      _driver = row != null ? DriverProfile.fromJson(row) : null;
      if (_driver != null) {
        await _loadCurrentService();
      }
    } catch (e) {
      debugPrint('Wazibus: driver load error ($e)');
      _driver = null;
    }

    _loading = false;
    notifyListeners();
  }

  /// Recharge le service du jour : reprend un service actif/en pause s'il
  /// existe, sinon retient le prochain créneau planifié.
  Future<void> _loadCurrentService() async {
    final client = _supabase.client;
    if (client == null || _driver == null) return;

    try {
      final rows = await client
          .from('driver_services')
          .select()
          .eq('driver_id', _driver!.id)
          .inFilter('status', ['active', 'paused', 'planned'])
          .order('start_time_planned', ascending: true, nullsFirst: false)
          .limit(20);

      final records = (rows as List)
          .map((r) => DriverServiceRecord.fromJson(r as Map<String, dynamic>))
          .toList();

      // Priorité à un service déjà en cours, sinon le prochain créneau planifié.
      DriverServiceRecord? running;
      DriverServiceRecord? planned;
      for (final r in records) {
        if (r.isRunning) {
          running = r;
          break;
        }
        planned ??= r;
      }
      _currentService = running ?? planned;

      // Reprend la remontée GPS si on relance l'app sur un service actif.
      if (_currentService?.isActive ?? false) {
        await _startGpsTracking();
      }
    } catch (e) {
      debugPrint('Wazibus: current service load error ($e)');
    }
  }

  Future<void> refresh() => _loadDriver();

  // ---------------------------------------------------------------------------
  // Prise de service
  // ---------------------------------------------------------------------------
  /// Crée ou met à jour le service du jour, le passe en `active`, enregistre
  /// `start_time_real` et démarre la géolocalisation.
  Future<bool> takeService({
    String? vehicleId,
    String? lineId,
    int? directionId,
    String? headsign,
  }) async {
    final client = _supabase.client;
    if (client == null || _driver == null) {
      _errorMessage = 'Mode conducteur indisponible hors ligne';
      notifyListeners();
      return false;
    }

    // La géolocalisation est requise pour la prise de service.
    final granted = await _location.requestForegroundPermission();
    if (!granted) {
      _errorMessage = 'Autorisation GPS requise pour prendre le service';
      notifyListeners();
      return false;
    }

    _busy = true;
    _errorMessage = null;
    notifyListeners();

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'vehicle_id': vehicleId,
      'line_id': lineId,
      'direction_id': directionId,
      'headsign': headsign,
      'status': 'active',
      'start_time_real': now,
    };

    try {
      Map<String, dynamic> row;
      if (_currentService != null && _currentService!.id.isNotEmpty) {
        row = await client
            .from('driver_services')
            .update(payload)
            .eq('id', _currentService!.id)
            .select()
            .single();
      } else {
        row = await client
            .from('driver_services')
            .insert({
              'driver_id': _driver!.id,
              'start_time_planned': now,
              ...payload,
            })
            .select()
            .single();
      }

      _currentService = DriverServiceRecord.fromJson(row);
      _delayMinutes = 0;
      await _setDriverStatus('on_service');
      await _startGpsTracking();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Wazibus: takeService error ($e)');
      _errorMessage = 'Impossible de prendre le service ($e)';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Fin de service
  // ---------------------------------------------------------------------------
  /// Enregistre `end_time_real`, passe le service en `completed`, coupe le GPS
  /// et expose un résumé.
  Future<bool> endService() async {
    final service = _currentService;
    final client = _supabase.client;
    if (service == null || client == null) return false;

    _busy = true;
    notifyListeners();

    await _stopGpsTracking();

    try {
      final row = await client
          .from('driver_services')
          .update({
            'status': 'completed',
            'end_time_real': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', service.id)
          .select()
          .single();

      _completedService = DriverServiceRecord.fromJson(row);
      _currentService = null;
      _delayMinutes = 0;
      await _setDriverStatus('available');
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Wazibus: endService error ($e)');
      _errorMessage = 'Impossible de terminer le service ($e)';
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  void clearCompletedSummary() {
    _completedService = null;
    notifyListeners();
  }

  // --- Avance / retard ---
  void adjustDelay(int deltaMinutes) {
    _delayMinutes = (_delayMinutes + deltaMinutes).clamp(-30, 60);
    notifyListeners();
  }

  void resetDelay() {
    _delayMinutes = 0;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Géolocalisation
  // ---------------------------------------------------------------------------
  Future<void> _startGpsTracking() async {
    if (_gpsActive) return;
    _gpsActive = true;

    _gpsSub?.cancel();
    _gpsSub = _location.getPositionStream().listen(
      (pos) {
        _lastPosition = pos;
        notifyListeners();
      },
      onError: (err) => debugPrint('Wazibus: driver gps stream error ($err)'),
    );

    // Envoi régulier (toutes les 10 s) tant que le service est actif.
    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _uploadPosition();
    });

    // Premier point dès que possible.
    final initial = await _location.updateCurrentPosition();
    if (initial != null) {
      _lastPosition = initial;
      await _uploadPosition();
    }
    notifyListeners();
  }

  Future<void> _stopGpsTracking() async {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    await _gpsSub?.cancel();
    _gpsSub = null;
    _gpsActive = false;
    _lastPosition = null;
    notifyListeners();
  }

  Future<void> _uploadPosition() async {
    final client = _supabase.client;
    final service = _currentService;
    final pos = _lastPosition;
    // La position n'est envoyée que si un service est réellement actif.
    if (client == null ||
        _driver == null ||
        service == null ||
        !service.isActive ||
        pos == null) {
      return;
    }

    // Throttle : au plus un envoi toutes les ~8 s.
    final now = DateTime.now();
    if (_lastUploadAt != null && now.difference(_lastUploadAt!).inSeconds < 8) {
      return;
    }
    _lastUploadAt = now;

    try {
      await client.from('vehicle_positions').insert({
        'driver_service_id': service.id,
        'vehicle_id': service.vehicleId,
        'driver_id': _driver!.id,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'speed': pos.speed < 0 ? 0 : pos.speed,
        'heading': pos.heading,
        'accuracy': pos.accuracy,
      });
    } catch (e) {
      // Erreur réseau : on n'interrompt pas le service, on réessaiera au tick suivant.
      debugPrint('Wazibus: vehicle_positions upload failed ($e)');
    }
  }

  Future<void> _setDriverStatus(String status) async {
    final client = _supabase.client;
    if (client == null || _driver == null) return;
    try {
      await client.from('drivers').update({'status': status}).eq('id', _driver!.id);
    } catch (e) {
      debugPrint('Wazibus: driver status update failed ($e)');
    }
  }

  @override
  void dispose() {
    _uploadTimer?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }
}
