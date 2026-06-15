import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_vehicle.dart';
import '../models/live_fleet_position.dart';
import 'supabase_service.dart';

/// Suivi temps réel de la flotte via `live_fleet_positions` (Realtime + refresh RPC).
/// Retombe sur `community_vehicles` si la couche unifiée n'est pas encore déployée.
class VehicleDetectionService with ChangeNotifier {
  final SupabaseService _supabaseService;

  List<CommunityVehicle> _detectedVehicles = [];
  List<LiveFleetPosition> _livePositions = [];
  Timer? _pollingTimer;
  RealtimeChannel? _realtimeChannel;
  bool _liveFleetAvailable = false;

  List<CommunityVehicle> get detectedVehicles => _detectedVehicles;
  List<LiveFleetPosition> get livePositions => _livePositions;
  bool get usesLiveFleet => _liveFleetAvailable;

  VehicleDetectionService({required SupabaseService supabaseService})
      : _supabaseService = supabaseService;

  void startMonitoring() {
    _pollingTimer?.cancel();
    _unsubscribeRealtime();

    if (_supabaseService.isOfflineMode) {
      _detectedVehicles = [];
      _livePositions = [];
      notifyListeners();
      return;
    }

    _subscribeRealtime();
    _refreshFleet();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshFleet());
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _unsubscribeRealtime();
  }

  Future<void> _refreshFleet() async {
    if (_supabaseService.client == null || _supabaseService.isOfflineMode) return;

    try {
      await _supabaseService.client!.rpc('aggregate_community_vehicles');
    } catch (e) {
      debugPrint('Wazibus: aggregate_community_vehicles ($e)');
    }

    try {
      await _supabaseService.client!.rpc('refresh_live_fleet_positions');
      _liveFleetAvailable = true;
    } catch (e) {
      debugPrint('Wazibus: refresh_live_fleet_positions ($e) — fallback community_vehicles');
      _liveFleetAvailable = false;
    }

    if (_liveFleetAvailable) {
      await _fetchLiveFleet();
    } else {
      await _fetchCommunityVehiclesFallback();
    }
  }

  Future<void> _fetchLiveFleet() async {
    final client = _supabaseService.client;
    if (client == null) return;

    try {
      final response = await client
          .from('live_fleet_positions')
          .select()
          .order('reliability_score', ascending: false);

      _livePositions = (response as List)
          .map((row) => LiveFleetPosition.fromJson(row))
          .toList();

      _detectedVehicles =
          _livePositions.map(CommunityVehicle.fromLiveFleet).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Wazibus: live_fleet_positions fetch failed ($e) — fallback');
      _liveFleetAvailable = false;
      await _fetchCommunityVehiclesFallback();
    }
  }

  Future<void> _fetchCommunityVehiclesFallback() async {
    final client = _supabaseService.client;
    if (client == null) return;

    try {
      final response = await client.from('community_vehicles').select();
      _livePositions = [];
      _detectedVehicles = (response as List)
          .map((x) => CommunityVehicle.fromJson(x))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Wazibus: community_vehicles fetch failed ($e)');
    }
  }

  void _subscribeRealtime() {
    final client = _supabaseService.client;
    if (client == null) return;

    _realtimeChannel = client
        .channel('public:live_fleet_positions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'live_fleet_positions',
          callback: (_) {
            if (_liveFleetAvailable) {
              _fetchLiveFleet();
            }
          },
        )
        .subscribe();
  }

  void _unsubscribeRealtime() {
    final channel = _realtimeChannel;
    if (channel == null) return;
    _supabaseService.client?.removeChannel(channel);
    _realtimeChannel = null;
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
