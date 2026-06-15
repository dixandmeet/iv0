import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/app_user_role.dart';
import '../models/driver_session.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'supabase_service.dart';

/// Prise de service conducteur : détection auto + remontée GPS certifiée.
class DriverSessionService with ChangeNotifier {
  final SupabaseService _supabaseService;
  final AuthService _authService;
  final LocationService _locationService;

  DriverSessionPhase _phase = DriverSessionPhase.idle;
  DriverSession? _session;
  String? _ambiguousRouteId;
  int? _ambiguousDirectionId;
  int? _ambiguousConfidence;
  String? _errorMessage;
  StreamSubscription<Position>? _gpsSub;
  final List<Map<String, dynamic>> _gpsBuffer = [];
  Timer? _uploadTimer;

  DriverSessionPhase get phase => _phase;
  DriverSession? get session => _session;
  int? get ambiguousConfidence => _ambiguousConfidence;
  String? get ambiguousLineLabel {
    if (_ambiguousRouteId == null) return null;
    return 'Ligne $_ambiguousRouteId';
  }

  String? get errorMessage => _errorMessage;

  DriverSessionService({
    required SupabaseService supabaseService,
    required AuthService authService,
    required LocationService locationService,
  })  : _supabaseService = supabaseService,
        _authService = authService,
        _locationService = locationService;

  bool get _canRun =>
      !_supabaseService.isOfflineMode &&
      _supabaseService.client != null &&
      _authService.role == AppUserRole.driver &&
      _authService.profile != null;

  Future<void> startTakeService() async {
    if (!_canRun) {
      _errorMessage = 'Mode conducteur indisponible';
      notifyListeners();
      return;
    }

    final granted = await _locationService.requestForegroundPermission();
    if (!granted) {
      _errorMessage = 'Autorisation GPS requise';
      notifyListeners();
      return;
    }

    _phase = DriverSessionPhase.detecting;
    _session = null;
    _gpsBuffer.clear();
    _errorMessage = null;
    notifyListeners();

    _gpsSub?.cancel();
    _gpsSub = _locationService.getPositionStream().listen(_onGpsPoint);
  }

  Future<void> _onGpsPoint(Position position) async {
    if (_phase != DriverSessionPhase.detecting &&
        _phase != DriverSessionPhase.active &&
        _phase != DriverSessionPhase.paused) {
      return;
    }

    _gpsBuffer.add({
      'lat': position.latitude,
      'lon': position.longitude,
      'heading': position.heading,
      'speed': position.speed < 0 ? 0 : position.speed,
    });
    if (_gpsBuffer.length > 10) _gpsBuffer.removeAt(0);

    if (_phase == DriverSessionPhase.detecting && _gpsBuffer.length >= 3) {
      await _tryAutoDetect();
    }

    if (_phase == DriverSessionPhase.active && _session != null) {
      await _uploadLocation(position);
    }
  }

  Future<void> _tryAutoDetect() async {
    final client = _supabaseService.client!;
    final driverId = _authService.profile!.id;

    try {
      final result = await client.rpc('start_driver_session_auto', params: {
        'p_driver_id': driverId,
        'p_points': _gpsBuffer,
      });

      final map = Map<String, dynamic>.from(result as Map);
      final status = map['status'] as String?;

      if (status == 'confirmed') {
        _session = DriverSession(
          id: map['session_id'] as String,
          routeId: map['route_id'] as String?,
          directionId: map['direction_id'] as int?,
          tripId: map['trip_id'] as String?,
          headsign: map['headsign'] as String?,
          detectionMode: 'auto',
          detectionConfidence: map['confidence'] as int?,
          status: 'active',
          startedAt: DateTime.now(),
          confirmedAt: DateTime.now(),
        );
        _phase = DriverSessionPhase.active;
        _startUploadTimer();
        notifyListeners();
        return;
      }

      if (status == 'ambiguous') {
        _ambiguousRouteId = map['route_id'] as String?;
        _ambiguousDirectionId = map['direction_id'] as int?;
        _ambiguousConfidence = map['confidence'] as int?;
        _phase = DriverSessionPhase.ambiguous;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Wazibus: auto-detect failed ($e)');
    }
  }

  Future<void> confirmAmbiguousDetection() async {
    if (_ambiguousRouteId == null || !_canRun) return;

    final client = _supabaseService.client!;
    try {
      final row = await client
          .from('driver_sessions')
          .insert({
            'driver_id': _authService.profile!.id,
            'route_id': _ambiguousRouteId,
            'direction_id': _ambiguousDirectionId,
            'detection_mode': 'corrected',
            'detection_confidence': _ambiguousConfidence,
            'status': 'active',
            'confirmed_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      _session = DriverSession.fromJson(row);
      _phase = DriverSessionPhase.active;
      _startUploadTimer();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Impossible de démarrer la session ($e)';
      notifyListeners();
    }
  }

  Future<void> pauseService() async {
    if (_session == null) return;
    _phase = DriverSessionPhase.paused;
    await _updateSessionStatus('paused');
    notifyListeners();
  }

  Future<void> resumeService() async {
    if (_session == null) return;
    _phase = DriverSessionPhase.active;
    await _updateSessionStatus('active');
    notifyListeners();
  }

  Future<void> endService() async {
    _gpsSub?.cancel();
    _gpsSub = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;

    if (_session != null) {
      await _updateSessionStatus('ended', ended: true);
    }

    _phase = DriverSessionPhase.ended;
    notifyListeners();
  }

  void resetToIdle() {
    _phase = DriverSessionPhase.idle;
    _session = null;
    _ambiguousRouteId = null;
    _ambiguousDirectionId = null;
    _ambiguousConfidence = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _updateSessionStatus(String status, {bool ended = false}) async {
    final client = _supabaseService.client;
    if (client == null || _session == null) return;

    final payload = <String, dynamic>{'status': status};
    if (ended) payload['ended_at'] = DateTime.now().toIso8601String();

    try {
      await client.from('driver_sessions').update(payload).eq('id', _session!.id);
    } catch (e) {
      debugPrint('Wazibus: session status update failed ($e)');
    }
  }

  void _startUploadTimer() {
    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      final pos = _locationService.currentPosition;
      if (pos != null && _phase == DriverSessionPhase.active) {
        await _uploadLocation(pos);
      }
    });
  }

  Future<void> _uploadLocation(Position position) async {
    final client = _supabaseService.client;
    if (client == null || _session == null) return;

    try {
      await client.from('driver_location_events').insert({
        'session_id': _session!.id,
        'geom': 'POINT(${position.longitude} ${position.latitude})',
        'speed': position.speed < 0 ? 0 : position.speed,
        'heading': position.heading,
        'accuracy': position.accuracy,
        'route_id': _session!.routeId,
        'confidence': _session!.detectionConfidence ?? 100,
      });

      // Rafraîchit la couche unifiée côté serveur
      await client.rpc('refresh_live_fleet_positions');
    } catch (e) {
      debugPrint('Wazibus: driver location upload failed ($e)');
    }
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _uploadTimer?.cancel();
    super.dispose();
  }
}
