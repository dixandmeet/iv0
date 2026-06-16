import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoris de l'utilisateur, persistés localement (anonyme) :
/// arrêts (par `stopId`) et lignes (par `routeId`).
class FavoritesService extends ChangeNotifier {
  static const _stopsKey = 'favorite_stop_ids';
  static const _linesKey = 'favorite_route_ids';

  final Set<String> _stopIds = {};
  final Set<String> _routeIds = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  // --- Arrêts ---------------------------------------------------------------
  List<String> get stopIds => List.unmodifiable(_stopIds);
  int get count => _stopIds.length;
  bool isFavorite(String stopId) => _stopIds.contains(stopId);

  // --- Lignes ---------------------------------------------------------------
  List<String> get routeIds => List.unmodifiable(_routeIds);
  int get lineCount => _routeIds.length;
  bool isFavoriteLine(String routeId) => _routeIds.contains(routeId);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _stopIds
        ..clear()
        ..addAll(prefs.getStringList(_stopsKey) ?? const []);
      _routeIds
        ..clear()
        ..addAll(prefs.getStringList(_linesKey) ?? const []);
    } catch (e) {
      debugPrint('Wazibus: favorites load failed ($e)');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggle(String stopId) async {
    if (!_stopIds.add(stopId)) {
      _stopIds.remove(stopId);
    }
    notifyListeners();
    await _persist(_stopsKey, _stopIds);
  }

  Future<void> toggleLine(String routeId) async {
    if (!_routeIds.add(routeId)) {
      _routeIds.remove(routeId);
    }
    notifyListeners();
    await _persist(_linesKey, _routeIds);
  }

  Future<void> _persist(String key, Set<String> values) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, values.toList());
    } catch (e) {
      debugPrint('Wazibus: favorites persist failed ($e)');
    }
  }
}
