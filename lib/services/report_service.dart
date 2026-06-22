import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'disruption_service.dart';
import 'supabase_service.dart';
import '../models/report.dart';

class ReportService with ChangeNotifier {
  final SupabaseService _supabaseService;
  final DisruptionService _disruptionService;

  /// Signalements communautaires (Supabase ou locaux hors-ligne), hors
  /// perturbations officielles.
  List<Report> _communityReports = [];

  /// Perturbations officielles Naolib (info-trafic temps réel).
  List<Report> _officialReports = [];

  /// Tous les signalements affichés : perturbations officielles d'abord,
  /// puis signalements communautaires.
  List<Report> get activeReports => [..._officialReports, ..._communityReports];

  ReportService({
    required SupabaseService supabaseService,
    DisruptionService? disruptionService,
  })  : _supabaseService = supabaseService,
        _disruptionService = disruptionService ?? DisruptionService();

  // Récupérer les signalements actifs (communautaires + perturbations
  // officielles Naolib). Les perturbations sont publiques : on les récupère
  // toujours, y compris en mode hors-ligne Supabase.
  Future<List<Report>> fetchRecentReports() async {
    final official = await _disruptionService.fetchActiveDisruptions();

    if (_supabaseService.isOfflineMode) {
      // Hors-ligne : seuls les signalements saisis localement par l'utilisateur
      // sont conservés (en mémoire). On purge ceux de plus de 2 heures.
      _communityReports.removeWhere(
          (r) => DateTime.now().difference(r.timestamp).inHours > 2);
      _officialReports = official;
      notifyListeners();
      return activeReports;
    }

    try {
      // Sélectionne les rapports des dernières 2 heures
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2)).toIso8601String();
      final response = await _supabaseService.client!
          .from('reports')
          .select()
          .gt('timestamp', twoHoursAgo)
          .order('timestamp', ascending: false);

      _communityReports =
          (response as List).map((x) => Report.fromJson(x)).toList();
    } catch (e) {
      debugPrint('Aule: Error fetching reports ($e)');
    }
    _officialReports = official;
    notifyListeners();
    return activeReports;
  }

  // Soumettre un nouveau signalement
  Future<bool> submitReport({
    required String routeId,
    required String reportType,
    required LatLng position,
    String? vehicleId,
    String? description,
  }) async {
    final newReport = Report(
      id: const Uuid().v4(),
      deviceId: _supabaseService.deviceUuid,
      routeId: routeId,
      vehicleId: vehicleId,
      reportType: reportType,
      position: position,
      timestamp: DateTime.now(),
      description: description,
    );

    if (_supabaseService.isOfflineMode) {
      _communityReports.insert(0, newReport);
      notifyListeners();
      return true;
    }

    try {
      final wktPoint = 'POINT(${position.longitude} ${position.latitude})';

      await _supabaseService.client!.from('reports').insert({
        'device_id': _supabaseService.registeredDeviceUuid,
        'route_id': routeId,
        'vehicle_id': vehicleId,
        'report_type': reportType,
        'geom': wktPoint,
        'timestamp': DateTime.now().toIso8601String(),
        'description': description,
      });

      _communityReports.insert(0, newReport);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Aule: Error submitting report ($e)');
      return false;
    }
  }
}
