import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationService with ChangeNotifier {
  Position? _currentPosition;
  bool _serviceEnabled = false;
  LocationPermission _permissionStatus = LocationPermission.denied;

  StreamSubscription<Position>? _watchSubscription;

  // Détection « en transport » : vitesse soutenue (seuil transit_probable),
  // avec hystérésis pour ne pas clignoter pendant les arrêts en station.
  static const double _transitSpeedMps = 2.5;
  static const Duration _transitGrace = Duration(seconds: 90);
  bool _inTransit = false;
  DateTime? _lastFastReadingAt;

  Position? get currentPosition => _currentPosition;
  bool get serviceEnabled => _serviceEnabled;
  LocationPermission get permissionStatus => _permissionStatus;

  /// Vrai si l'utilisateur est vraisemblablement à bord d'un transport.
  bool get isInTransit => _inTransit;

  // Initialise et vérifie les permissions
  Future<void> initialize() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_serviceEnabled) {
      debugPrint('Wazibus: GPS Location services are disabled.');
      return;
    }

    _permissionStatus = await Geolocator.checkPermission();
    if (_permissionStatus == LocationPermission.whileInUse ||
        _permissionStatus == LocationPermission.always) {
      await updateCurrentPosition();
      startWatching();
    }
  }

  // Demande les autorisations GPS (premier plan)
  Future<bool> requestForegroundPermission() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_serviceEnabled) {
      return false;
    }

    _permissionStatus = await Geolocator.checkPermission();
    if (_permissionStatus == LocationPermission.denied) {
      _permissionStatus = await Geolocator.requestPermission();
      if (_permissionStatus == LocationPermission.denied) {
        notifyListeners();
        return false;
      }
    }

    if (_permissionStatus == LocationPermission.deniedForever) {
      notifyListeners();
      return false;
    }

    await updateCurrentPosition();
    startWatching();
    notifyListeners();
    return true;
  }

  // Demande les autorisations GPS d'arrière-plan (Always)
  Future<bool> requestBackgroundPermission() async {
    // Il faut d'abord obtenir le premier plan
    final hasForeground = await requestForegroundPermission();
    if (!hasForeground) return false;

    // Si on a déjà "always", pas besoin de redemander
    if (_permissionStatus == LocationPermission.always) return true;

    // Note: Sur iOS/Android, cela ouvre les paramètres système ou affiche la pop-up de confirmation.
    // Geolocator.requestPermission() demandera le niveau maximal déclaré (Background) si configuré.
    _permissionStatus = await Geolocator.requestPermission();
    notifyListeners();
    return _permissionStatus == LocationPermission.always;
  }

  // Met à jour la position courante une seule fois
  Future<Position?> updateCurrentPosition() async {
    if (_permissionStatus == LocationPermission.denied ||
        _permissionStatus == LocationPermission.deniedForever) {
      return null;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      debugPrint('Wazibus: Error getting position ($e)');
      return null;
    }
  }

  /// Maintient [currentPosition] à jour en continu (premier plan) et met à
  /// jour l'état [isInTransit]. Sans effet si les permissions manquent.
  void startWatching() {
    if (_watchSubscription != null) return;
    if (_permissionStatus != LocationPermission.whileInUse &&
        _permissionStatus != LocationPermission.always) {
      return;
    }

    _watchSubscription = getPositionStream().listen((position) {
      _currentPosition = position;
      final now = DateTime.now();
      if (position.speed >= _transitSpeedMps) {
        _lastFastReadingAt = now;
        _inTransit = true;
      } else if (_inTransit &&
          (_lastFastReadingAt == null ||
              now.difference(_lastFastReadingAt!) > _transitGrace)) {
        _inTransit = false;
      }
      notifyListeners();
    }, onError: (err) {
      debugPrint('Wazibus: position watch error ($err)');
    });
  }

  void stopWatching() {
    _watchSubscription?.cancel();
    _watchSubscription = null;
  }

  @override
  void dispose() {
    stopWatching();
    super.dispose();
  }

  // Stream de positions pour le suivi en temps réel (premier plan)
  Stream<Position> getPositionStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Récupère une mise à jour tous les 10 mètres
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
