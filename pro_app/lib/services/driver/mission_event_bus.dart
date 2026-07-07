import 'package:flutter/foundation.dart';

import '../../models/driver/mission_models.dart';

/// Événement métier mission (bus in-app).
class MissionEvent {
  final MissionEventType type;
  final String? planId;
  final Map<String, dynamic> payload;
  final DateTime at;

  const MissionEvent({
    required this.type,
    this.planId,
    this.payload = const {},
    required this.at,
  });
}

/// Bus uniforme — alimente notifications et persistance (via service).
class MissionEventBus extends ChangeNotifier {
  final List<MissionEvent> _history = [];
  MissionEvent? _last;

  List<MissionEvent> get history => List.unmodifiable(_history);
  MissionEvent? get last => _last;

  void emit(MissionEvent event) {
    _last = event;
    _history.add(event);
    notifyListeners();
  }

  void clear() {
    _history.clear();
    _last = null;
    notifyListeners();
  }
}
