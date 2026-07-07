import 'package:flutter/foundation.dart';

import 'mission_event_bus.dart';
import '../../models/driver/mission_models.dart';

/// Notifications découplées des RPC — écoute le bus d'événements.
class MissionNotificationService {
  MissionNotificationService({required MissionEventBus bus}) : _bus = bus {
    _bus.addListener(_onEvent);
  }

  final MissionEventBus _bus;
  final ValueNotifier<String?> lastMessage = ValueNotifier(null);

  void _onEvent() {
    final event = _bus.last;
    if (event == null) return;
    lastMessage.value = _messageFor(event);
  }

  String? _messageFor(MissionEvent event) {
    return switch (event.type) {
      MissionEventType.missionCreated => 'Service créé — préparation en cours',
      MissionEventType.memberJoined => 'Un agent a rejoint le service',
      MissionEventType.memberDeclined => 'Invitation refusée',
      MissionEventType.memberPresent => 'Présence enregistrée',
      MissionEventType.roleUpdated => 'Rôles mis à jour',
      MissionEventType.missionStarted => 'Intervention démarrée',
      MissionEventType.missionCompleted => 'Intervention terminée',
      _ => null,
    };
  }

  void dispose() {
    _bus.removeListener(_onEvent);
    lastMessage.dispose();
  }
}
