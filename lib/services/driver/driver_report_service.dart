import 'package:flutter/material.dart';

import '../../models/driver/driver_report.dart';
import '../supabase_service.dart';

/// Gestion des signalements terrain conducteur (table `driver_reports`).
class DriverReportService with ChangeNotifier {
  final SupabaseService _supabase;

  DriverReportService({required SupabaseService supabaseService})
      : _supabase = supabaseService;

  bool _submitting = false;
  String? _errorMessage;
  List<DriverReport> _recent = [];

  bool get submitting => _submitting;
  String? get errorMessage => _errorMessage;
  List<DriverReport> get recent => List.unmodifiable(_recent);

  /// Envoie un signalement. Retourne `true` en cas de succès.
  Future<bool> submitReport({
    required String driverId,
    required DriverReportType type,
    required DriverReportUrgency urgency,
    String? message,
    String? driverServiceId,
    String? vehicleId,
    double? latitude,
    double? longitude,
    String? photoUrl,
  }) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) {
      _errorMessage = 'Signalement indisponible hors ligne';
      notifyListeners();
      return false;
    }

    _submitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final row = await client
          .from('driver_reports')
          .insert({
            'driver_id': driverId,
            'driver_service_id': driverServiceId,
            'vehicle_id': vehicleId,
            'type': type.dbValue,
            'urgency': urgency.dbValue,
            'message': (message != null && message.trim().isNotEmpty)
                ? message.trim()
                : null,
            'latitude': latitude,
            'longitude': longitude,
            'photo_url': photoUrl,
          })
          .select()
          .single();

      _recent.insert(0, DriverReport.fromJson(row));
      _submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Wazibus: driver report submit failed ($e)');
      _errorMessage = 'Échec de l\'envoi du signalement';
      _submitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Charge les derniers signalements du conducteur.
  Future<void> fetchMine(String driverId) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode) return;

    try {
      final rows = await client
          .from('driver_reports')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(30);
      _recent = (rows as List)
          .map((r) => DriverReport.fromJson(r as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Wazibus: driver reports fetch failed ($e)');
    }
  }
}
