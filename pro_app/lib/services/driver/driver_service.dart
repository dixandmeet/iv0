import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/driver/driver_profile.dart';
import '../../models/driver/driver_service_record.dart';
import '../../models/driver/transport_service.dart';
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
  DriverAccessStatus _accessStatus = DriverAccessStatus.none;

  bool get loading => _loading;
  DriverProfile? get driver => _driver;
  bool get isDriver => _driver != null;

  /// État d'accès conducteur (fiche validée, en attente, refusée ou aucun).
  DriverAccessStatus get accessStatus => _accessStatus;
  bool get hasPendingAccess => _accessStatus == DriverAccessStatus.pending;

  // --- Service du jour / en cours ---
  DriverServiceRecord? _currentService;
  DriverServiceRecord? _completedService; // résumé fin de service
  bool _busy = false; // opération réseau en cours (start/end)
  bool _updatingProfile = false;
  bool _updatingAvatar = false;
  String? _errorMessage;

  DriverServiceRecord? get currentService => _currentService;
  DriverServiceRecord? get completedService => _completedService;
  bool get busy => _busy;
  bool get updatingProfile => _updatingProfile;
  bool get updatingAvatar => _updatingAvatar;
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
      _accessStatus = DriverAccessStatus.none;
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
        _accessStatus = DriverAccessStatus.driver;
        await _loadCurrentService();
      } else {
        // Pas de fiche : demande d'accès en attente, ou revendication différée
        // (matricule saisi à l'inscription mais session obtenue après
        // confirmation e-mail).
        _accessStatus = await _auth.driverAccessStatus();
        if (_accessStatus == DriverAccessStatus.none) {
          await _tryDeferredClaim(email);
        }
      }
    } catch (e) {
      debugPrint('Aule: driver load error ($e)');
      _driver = null;
      _accessStatus = DriverAccessStatus.none;
    }

    _loading = false;
    notifyListeners();
  }

  /// Revendique le matricule mémorisé dans les métadonnées du compte si aucune
  /// fiche/demande n'existe encore (cas inscription avec confirmation e-mail).
  Future<void> _tryDeferredClaim(String email) async {
    final client = _supabase.client;
    final meta = client?.auth.currentUser?.userMetadata;
    final mat = meta?['employee_id'];
    if (client == null ||
        meta?['signup_type'] != 'driver' ||
        mat is! String ||
        mat.trim().isEmpty) {
      return;
    }
    try {
      final outcome =
          await client.rpc('claim_driver_access', params: {'p_employee_id': mat});
      if (outcome == 'validated') {
        final row = await client
            .from('drivers')
            .select()
            .ilike('email', email)
            .maybeSingle();
        _driver = row != null ? DriverProfile.fromJson(row) : null;
        if (_driver != null) {
          _accessStatus = DriverAccessStatus.driver;
          await _loadCurrentService();
        }
      } else if (outcome == 'pending') {
        _accessStatus = DriverAccessStatus.pending;
      }
    } catch (e) {
      debugPrint('Aule: deferred claim error ($e)');
    }
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
      debugPrint('Aule: current service load error ($e)');
    }
  }

  Future<void> refresh() => _loadDriver();

  /// Met à jour les informations personnelles modifiables du conducteur.
  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final client = _supabase.client;
    if (client == null || _supabase.isOfflineMode || _driver == null) {
      _errorMessage = 'Connexion indisponible';
      notifyListeners();
      return false;
    }

    _updatingProfile = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final row = await client
          .from('drivers')
          .update({
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'phone': phone?.trim().isEmpty ?? true ? null : phone!.trim(),
          })
          .eq('id', _driver!.id)
          .select()
          .single();
      _driver = DriverProfile.fromJson(row);
      _errorMessage = null;
      _updatingProfile = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Aule: driver profile update failed ($e)');
      _errorMessage = 'Impossible de mettre à jour le profil';
      _updatingProfile = false;
      notifyListeners();
      return false;
    }
  }

  static const _avatarBucket = 'driver-avatars';

  /// Envoie une photo de profil (JPEG/PNG/WebP) vers Storage puis met à jour
  /// la fiche conducteur.
  Future<bool> uploadAvatar(XFile file) async {
    final client = _supabase.client;
    final user = client?.auth.currentUser;
    if (client == null || _supabase.isOfflineMode || _driver == null) {
      _errorMessage = 'Connexion indisponible';
      notifyListeners();
      return false;
    }
    if (user == null || user.isAnonymous) {
      _errorMessage = 'Session invalide — reconnectez-vous';
      notifyListeners();
      return false;
    }

    _updatingAvatar = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('Fichier vide');
      }

      final extension = _avatarExtension(file);
      final contentType = _avatarContentType(extension);
      final storagePath = '${user.id}/avatar.$extension';

      // Supprime d'abord les variantes existantes puis envoie (évite les
      // conflits upsert / politiques UPDATE sur certains hébergeurs).
      await client.storage.from(_avatarBucket).remove([
        '${user.id}/avatar.jpg',
        '${user.id}/avatar.jpeg',
        '${user.id}/avatar.png',
        '${user.id}/avatar.webp',
      ]);

      await client.storage.from(_avatarBucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );

      final baseUrl =
          client.storage.from(_avatarBucket).getPublicUrl(storagePath);
      final avatarUrl =
          '$baseUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      final row = await client
          .from('drivers')
          .update({'avatar_url': avatarUrl})
          .eq('id', _driver!.id)
          .select()
          .single();
      _driver = DriverProfile.fromJson(row);
      _errorMessage = null;
      _updatingAvatar = false;
      notifyListeners();
      return true;
    } on StorageException catch (e) {
      debugPrint('Aule: driver avatar storage failed (${e.statusCode}) $e');
      _errorMessage = _avatarStorageError(e);
      _updatingAvatar = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Aule: driver avatar upload failed ($e)');
      _errorMessage = _avatarGenericError(e);
      _updatingAvatar = false;
      notifyListeners();
      return false;
    }
  }

  /// Supprime la photo de profil (Storage + colonne `avatar_url`).
  Future<bool> removeAvatar() async {
    final client = _supabase.client;
    final user = client?.auth.currentUser;
    if (client == null || _supabase.isOfflineMode || _driver == null) {
      _errorMessage = 'Connexion indisponible';
      notifyListeners();
      return false;
    }
    if (user == null || user.isAnonymous) {
      _errorMessage = 'Session invalide — reconnectez-vous';
      notifyListeners();
      return false;
    }

    _updatingAvatar = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = user.id;
      await client.storage.from(_avatarBucket).remove([
        '$userId/avatar.jpg',
        '$userId/avatar.jpeg',
        '$userId/avatar.png',
        '$userId/avatar.webp',
      ]);

      final row = await client
          .from('drivers')
          .update({'avatar_url': null})
          .eq('id', _driver!.id)
          .select()
          .single();
      _driver = DriverProfile.fromJson(row);
      _errorMessage = null;
      _updatingAvatar = false;
      notifyListeners();
      return true;
    } on StorageException catch (e) {
      debugPrint('Aule: driver avatar delete storage failed (${e.statusCode}) $e');
      _errorMessage = _avatarStorageError(e);
      _updatingAvatar = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Aule: driver avatar delete failed ($e)');
      _errorMessage = 'Impossible de supprimer la photo';
      _updatingAvatar = false;
      notifyListeners();
      return false;
    }
  }

  String _avatarExtension(XFile file) {
    final mime = file.mimeType?.toLowerCase();
    if (mime == 'image/png') return 'png';
    if (mime == 'image/webp') return 'webp';
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'png';
    if (path.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _avatarContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _avatarStorageError(StorageException e) {
    final code = e.statusCode;
    final message = e.message.toLowerCase();
    if (code == '404' || message.contains('bucket')) {
      return 'Stockage photo non configuré sur le serveur';
    }
    if (code == '403' ||
        message.contains('policy') ||
        message.contains('denied')) {
      return 'Accès refusé — vérifiez votre connexion conducteur';
    }
    if (message.contains('mime') || message.contains('content')) {
      return 'Format d\'image non supporté (JPEG ou PNG)';
    }
    return 'Impossible d\'envoyer la photo';
  }

  String _avatarGenericError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('avatar_url') || text.contains('column')) {
      return 'Mise à jour serveur requise (avatar_url)';
    }
    if (text.contains('fichier')) {
      return 'Impossible de lire l\'image sélectionnée';
    }
    return 'Impossible d\'envoyer la photo';
  }

  // ---------------------------------------------------------------------------
  // Services de roulement (table transport_services, lecture seule)
  // ---------------------------------------------------------------------------
  /// Services qui démarrent sur le véhicule [vehicleKey] (« ligne-train »,
  /// ex. « 1-31 »), pour que le conducteur choisisse sa vacation. Filtrable par
  /// [period] (edition : VERT / BLEU / HIVER). Triés par heure de début.
  Future<List<TransportService>> findServicesByVehicle(
    String vehicleKey, {
    String? period,
  }) async {
    final client = _supabase.client;
    if (client == null || vehicleKey.trim().isEmpty) return const [];

    final key = vehicleKey.toUpperCase().replaceAll(RegExp(r'\s'), '');
    try {
      var query =
          client.from('transport_services').select().eq('vehicle_key', key);
      if (period != null && period.isNotEmpty) {
        query = query.eq('edition', period);
      }
      final rows = await query.limit(50);
      final services = (rows as List)
          .map((r) => TransportService.fromJson(r as Map<String, dynamic>))
          .toList();
      services.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      return services;
    } catch (e) {
      debugPrint('Aule: findServicesByVehicle error ($e)');
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Prise de service
  // ---------------------------------------------------------------------------
  /// Crée ou met à jour le service du jour, le passe en `active`, enregistre
  /// `start_time_real` et démarre la géolocalisation.
  Future<bool> takeService({
    String? vehicleId,
    String? lineId,
    String? trainNumber,
    String? serviceCode,
    String? dayCode,
    String? parkingSlot,
    DateTime? plannedStart,
    DateTime? plannedEnd,
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
      'train_number': trainNumber,
      'service_code': serviceCode,
      'day_code': dayCode,
      'parking_slot': parkingSlot,
      'direction_id': directionId,
      'headsign': headsign,
      'status': 'active',
      'start_time_real': now,
    };
    if (plannedStart != null) {
      payload['start_time_planned'] = plannedStart.toUtc().toIso8601String();
    }
    if (plannedEnd != null) {
      payload['end_time_planned'] = plannedEnd.toUtc().toIso8601String();
    }

    // Écrit le service ; tolère l'absence de la colonne train_number (migration
    // 022 pas encore appliquée) en réessayant sans elle plutôt que d'échouer.
    Future<Map<String, dynamic>> write(Map<String, dynamic> p) {
      if (_currentService != null && _currentService!.id.isNotEmpty) {
        return client
            .from('driver_services')
            .update(p)
            .eq('id', _currentService!.id)
            .select()
            .single();
      }
      return client
          .from('driver_services')
          .insert({
            'driver_id': _driver!.id,
            'start_time_planned': now,
            ...p,
          })
          .select()
          .single();
    }

    try {
      Map<String, dynamic> row;
      try {
        row = await write(payload);
      } catch (e) {
        // Repli si une colonne récente manque encore (migrations 022/023/059
        // non appliquées) : on réécrit sans les colonnes optionnelles.
        final s = e.toString();
        final missingTrain = s.contains('train_number');
        final missingService = s.contains('service_code');
        final missingDayCode = s.contains('day_code');
        final missingParkingSlot = s.contains('parking_slot');
        if (s.contains('PGRST204') ||
            missingTrain ||
            missingService ||
            missingDayCode ||
            missingParkingSlot) {
          debugPrint('Aule: colonne récente absente, repli prise de service.');
          row = await write(Map<String, dynamic>.from(payload)
            ..remove('train_number')
            ..remove('service_code')
            ..remove('day_code')
            ..remove('parking_slot'));
        } else {
          rethrow;
        }
      }

      _currentService = DriverServiceRecord.fromJson(row);
      _delayMinutes = 0;
      await _setDriverStatus('on_service');
      await _startGpsTracking();
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Aule: takeService error ($e)');
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
      debugPrint('Aule: endService error ($e)');
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
      onError: (err) => debugPrint('Aule: driver gps stream error ($err)'),
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
      debugPrint('Aule: vehicle_positions upload failed ($e)');
    }
  }

  Future<void> _setDriverStatus(String status) async {
    final client = _supabase.client;
    if (client == null || _driver == null) return;
    try {
      await client.from('drivers').update({'status': status}).eq('id', _driver!.id);
    } catch (e) {
      debugPrint('Aule: driver status update failed ($e)');
    }
  }

  @override
  void dispose() {
    _uploadTimer?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }
}
