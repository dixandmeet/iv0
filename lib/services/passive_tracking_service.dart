import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'supabase_service.dart';
import 'location_service.dart';
import '../models/location_event.dart';

class PassiveTrackingService with ChangeNotifier {
  final SupabaseService _supabaseService;
  final LocationService _locationService;

  bool _isTracking = false;
  StreamSubscription<Position>? _positionSubscription;

  bool get isTracking => _isTracking;

  PassiveTrackingService({
    required SupabaseService supabaseService,
    required LocationService locationService,
  })  : _supabaseService = supabaseService,
        _locationService = locationService;

  // Démarrer le suivi passif
  Future<void> startTracking() async {
    if (_isTracking) return;

    // Sans backend live, la contribution communautaire est impossible
    // (rien à téléverser) : on n'active donc pas le suivi.
    if (_supabaseService.isOfflineMode) {
      debugPrint('Aule: Tracking unavailable offline (no live backend).');
      return;
    }

    // Vérifie le consentement de l'utilisateur
    if (!_supabaseService.consentBackground) {
      debugPrint('Aule: Tracking failed to start: No background consent.');
      return;
    }

    _isTracking = true;
    notifyListeners();

    _startRealTracking();
    debugPrint('Aule: Passive tracking started.');
  }

  // Arrêter le suivi passif
  void stopTracking() {
    if (!_isTracking) return;

    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;

    notifyListeners();
    debugPrint('Aule: Passive tracking stopped.');
  }

  // Lancement du suivi sur le GPS réel
  void _startRealTracking() {
    _positionSubscription = _locationService.getPositionStream().listen((Position position) {
      _handleNewPosition(position);
    }, onError: (err) {
      debugPrint('Aule: Real tracking stream error: $err');
    });
  }

  // Traitement et téléversement de la position
  Future<void> _handleNewPosition(Position position) async {
    // 1. Détermination de l'état estimé de l'usager
    String state = 'walking';
    if (position.speed < 0.5) {
      state = 'waiting';
    } else if (position.speed >= 2.5) {
      state = 'transit_probable';
    }

    final event = LocationEvent(
      deviceId: _supabaseService.deviceUuid,
      position: LatLng(position.latitude, position.longitude),
      speed: position.speed,
      heading: position.heading,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
      estimatedState: state,
    );

    debugPrint('Aule Tracking Event: ${position.latitude}, ${position.longitude} | Speed: ${position.speed} m/s | State: $state');

    // 2. Téléversement vers Supabase
    if (!_supabaseService.isOfflineMode && _supabaseService.client != null) {
      try {
        final client = _supabaseService.client!;
        // Formatte la géométrie au format PostGIS Point WKT: POINT(longitude latitude)
        final wktPoint = 'POINT(${event.position.longitude} ${event.position.latitude})';

        await client.from('user_location_events').insert({
          'device_id': event.deviceId,
          'geom': wktPoint,
          'speed': event.speed,
          'heading': event.heading,
          'accuracy': event.accuracy,
          'timestamp': event.timestamp.toIso8601String(),
          'estimated_state': event.estimatedState,
        });
        debugPrint('Aule: Uploaded location to Supabase.');
      } catch (e) {
        debugPrint('Aule: Failed to upload location event ($e)');
      }
    }
  }
}
