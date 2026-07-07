import 'package:aule_pro/models/driver/control_plan_context.dart';
import 'package:aule_pro/models/driver/control_team.dart';
import 'package:aule_pro/models/driver/mission_models.dart';
import 'package:aule_pro/services/driver/mission_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MissionActions', () {
    test('tout participant accepté peut démarrer en préparation', () {
      for (final role in MissionActorRole.values) {
        final actions = MissionActions.resolve(
          phase: MissionPhase.preparation,
          role: role,
          hasPendingInvitation: false,
          isAcceptedParticipant: true,
        );
        expect(actions.canStartIntervention, isTrue);
      }
    });

    test('seul le PAD peut terminer une intervention', () {
      final agent = MissionActions.resolve(
        phase: MissionPhase.intervention,
        role: MissionActorRole.agent,
        hasPendingInvitation: false,
      );
      final pad = MissionActions.resolve(
        phase: MissionPhase.intervention,
        role: MissionActorRole.pad,
        hasPendingInvitation: false,
      );

      expect(agent.canEndIntervention, isFalse);
      expect(pad.canEndIntervention, isTrue);
    });

    test('un membre non accepté ne peut pas agir', () {
      final actions = MissionActions.resolve(
        phase: MissionPhase.preparation,
        role: MissionActorRole.agent,
        hasPendingInvitation: false,
        isAcceptedParticipant: false,
      );

      expect(actions.readOnly, isTrue);
      expect(actions.canStartIntervention, isFalse);
    });
  });

  test('un refus bloque la readiness et invalide le rôle concerné', () {
    const team = ControlTeam(
      id: 'team-1',
      name: 'Équipe',
      members: [
        TeamMember(
          userId: 'pad',
          invitationStatus: InvitationStatus.declined,
          mentions: {TeamMention.pad},
          displayName: 'Agent PAD',
        ),
        TeamMember(
          userId: 'chef',
          invitationStatus: InvitationStatus.accepted,
          mentions: {TeamMention.chef, TeamMention.tpe},
          presenceStatus: 'present',
        ),
      ],
    );

    final readiness = TeamReadiness.fromTeam(team);

    expect(readiness.ready, isFalse);
    expect(readiness.items.firstWhere((i) => i.key == 'pad').done, isFalse);
    expect(readiness.blockingLabel, contains('a refusé'));
  });

  test('copyWith conserve les métadonnées terrain de la mission', () {
    final startedAt = DateTime(2026, 7, 1, 8);
    final mission = ControlMissionSummary(
      id: 'mission-1',
      planName: 'Mission',
      teamName: 'Équipe',
      missionDisplayNumber: 248,
      objective: 'Informations & Contrôles',
      priorityDb: 'high',
      interventionStartedAt: startedAt,
      channelId: 'channel-1',
    );

    final copied = mission.copyWith(fullAccess: true);

    expect(copied.missionDisplayNumber, 248);
    expect(copied.objective, 'Informations & Contrôles');
    expect(copied.priorityDb, 'high');
    expect(copied.interventionStartedAt, startedAt);
    expect(copied.channelId, 'channel-1');
  });
}
