import '../../models/driver/mission_models.dart';

/// Rôle effectif pour la matrice actions.
enum MissionActorRole { agent, pad, admin }

/// Actions disponibles selon phase × rôle.
class MissionActionSet {
  final bool canJoin;
  final bool canDeclarePresence;
  final bool canConfirmPresence;
  final bool canManagePreparation;
  final bool canStartIntervention;
  final bool canEndIntervention;
  final bool canEditMission;
  final bool canInvite;
  final bool canDelete;
  final bool canEditRoles;
  final bool canAddNote;
  final bool canReportIncident;
  final bool readOnly;

  const MissionActionSet({
    this.canJoin = false,
    this.canDeclarePresence = false,
    this.canConfirmPresence = false,
    this.canManagePreparation = false,
    this.canStartIntervention = false,
    this.canEndIntervention = false,
    this.canEditMission = false,
    this.canInvite = false,
    this.canDelete = false,
    this.canEditRoles = false,
    this.canAddNote = false,
    this.canReportIncident = false,
    this.readOnly = false,
  });
}

class MissionActions {
  static MissionActorRole resolveRole({
    required bool isCreator,
    required bool isPad,
  }) {
    if (isPad) return MissionActorRole.pad;
    if (isCreator) return MissionActorRole.admin;
    return MissionActorRole.agent;
  }

  static MissionActionSet resolve({
    required MissionPhase phase,
    required MissionActorRole role,
    required bool hasPendingInvitation,
    bool isAcceptedParticipant = true,
  }) {
    if (phase == MissionPhase.debrief || phase == MissionPhase.archived) {
      return const MissionActionSet(readOnly: true);
    }

    if (hasPendingInvitation) {
      return const MissionActionSet(canJoin: true);
    }

    if (!isAcceptedParticipant) {
      return const MissionActionSet(readOnly: true);
    }

    switch (phase) {
      case MissionPhase.preparation:
        return switch (role) {
          MissionActorRole.agent => const MissionActionSet(
            canDeclarePresence: true,
            canStartIntervention: true,
          ),
          MissionActorRole.pad => const MissionActionSet(
            canManagePreparation: true,
            canConfirmPresence: true,
            canStartIntervention: true,
            canEditRoles: true,
          ),
          MissionActorRole.admin => const MissionActionSet(
            canEditMission: true,
            canInvite: true,
            canDelete: true,
            canEditRoles: true,
            canStartIntervention: true,
          ),
        };
      case MissionPhase.intervention:
        return switch (role) {
          MissionActorRole.agent => const MissionActionSet(
            canAddNote: true,
            canReportIncident: true,
          ),
          MissionActorRole.pad => const MissionActionSet(
            canAddNote: true,
            canReportIncident: true,
            canEndIntervention: true,
          ),
          MissionActorRole.admin => const MissionActionSet(readOnly: true),
        };
      default:
        return const MissionActionSet(readOnly: true);
    }
  }
}
