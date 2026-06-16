import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Arrêts favoris de l'utilisateur, persistés localement (anonyme).
class FavoritesService extends ChangeNotifier {
  static const _key = 'favorite_stop_ids';

  final Set<String> _stopIds = {};
  bool _loaded = false;

  bool get isLoaded => _loaded;
  List<String> get stopIds => List.unmodifiable(_stopIds);
  int get count => _stopIds.length;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _stopIds
        ..clear()
        ..addAll(prefs.getStringList(_key) ?? const []);
    } catch (e) {
      debugPrint('Wazibus: favorites load failed ($e)');
    }
    _loaded = true;
    notifyListeners();
  }

  bool isFavorite(String stopId) => _stopIds.contains(stopId);

  Future<void> toggle(String stopId) async {
    if (!_stopIds.add(stopId)) {
      _stopIds.remove(stopId);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _stopIds.toList());
    } catch (e) {
      debugPrint('Wazibus: favorites persist failed ($e)');
    }
  }
}
