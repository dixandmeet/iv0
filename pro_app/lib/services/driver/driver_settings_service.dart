import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences locales de l'espace conducteur (notifications, économie batterie…).
class DriverSettingsService with ChangeNotifier {
  static const _keyNotifyService = 'aule_pro_notify_service';
  static const _keyNotifyMessages = 'aule_pro_notify_messages';
  static const _keyNotifyIncidents = 'aule_pro_notify_incidents';
  static const _keyBatterySaver = 'aule_pro_battery_saver';
  static const _keyHaptic = 'aule_pro_haptic';

  bool _loaded = false;
  bool _notifyService = true;
  bool _notifyMessages = true;
  bool _notifyIncidents = true;
  bool _batterySaver = false;
  bool _hapticFeedback = true;

  bool get loaded => _loaded;
  bool get notifyService => _notifyService;
  bool get notifyMessages => _notifyMessages;
  bool get notifyIncidents => _notifyIncidents;
  bool get batterySaver => _batterySaver;
  bool get hapticFeedback => _hapticFeedback;

  /// Indique si une catégorie de notification doit déboucher sur une bannière,
  /// selon les préférences du conducteur. Mappe les catégories serveur
  /// (`message`/`alert`/`activity`) sur les trois bascules de l'écran réglages.
  bool allowsCategory(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.message:
        return _notifyMessages;
      case NotificationCategory.alert:
        return _notifyIncidents;
      case NotificationCategory.activity:
      case NotificationCategory.unknown:
        return _notifyService;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _notifyService = prefs.getBool(_keyNotifyService) ?? true;
    _notifyMessages = prefs.getBool(_keyNotifyMessages) ?? true;
    _notifyIncidents = prefs.getBool(_keyNotifyIncidents) ?? true;
    _batterySaver = prefs.getBool(_keyBatterySaver) ?? false;
    _hapticFeedback = prefs.getBool(_keyHaptic) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setNotifyService(bool value) =>
      _setBool(_keyNotifyService, value, (v) => _notifyService = v);

  Future<void> setNotifyMessages(bool value) =>
      _setBool(_keyNotifyMessages, value, (v) => _notifyMessages = v);

  Future<void> setNotifyIncidents(bool value) =>
      _setBool(_keyNotifyIncidents, value, (v) => _notifyIncidents = v);

  Future<void> setBatterySaver(bool value) =>
      _setBool(_keyBatterySaver, value, (v) => _batterySaver = v);

  Future<void> setHapticFeedback(bool value) =>
      _setBool(_keyHaptic, value, (v) => _hapticFeedback = v);

  Future<void> _setBool(
    String key,
    bool value,
    void Function(bool) assign,
  ) async {
    assign(value);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
