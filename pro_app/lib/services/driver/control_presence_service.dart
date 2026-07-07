import 'dart:async';

import '../location_service.dart';
import 'control_plan_service.dart';

/// Détection présence : GPS périodique + fallback manuel via service plan.
class ControlPresenceService {
  final ControlPlanService _planService;
  final LocationService _location;

  Timer? _timer;
  String? _activeTeamId;

  ControlPresenceService({
    required ControlPlanService planService,
    required LocationService locationService,
  })  : _planService = planService,
        _location = locationService;

  void startWatching(String teamId) {
    if (_activeTeamId == teamId && _timer != null) return;
    stopWatching();
    _activeTeamId = teamId;
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _tick());
    unawaited(_tick());
  }

  void stopWatching() {
    _timer?.cancel();
    _timer = null;
    _activeTeamId = null;
  }

  Future<void> _tick() async {
    final teamId = _activeTeamId;
    if (teamId == null) return;
    final pos = _location.currentPosition ?? await _location.updateCurrentPosition();
    if (pos == null) return;
    await _planService.syncPresence(teamId, pos.latitude, pos.longitude);
  }

  Future<PresenceResult> declareArrived(String teamId) =>
      _planService.declarePresence(teamId);

  void dispose() => stopWatching();
}
