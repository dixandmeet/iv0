import 'package:flutter/material.dart';

import '../../models/driver/control_plan_context.dart';
import 'control_mission_workspace_screen.dart';

/// Rétrocompatibilité — délègue au workspace mission de contrôle.
class ControlMissionDetailScreen extends StatelessWidget {
  final ControlMissionSummary mission;
  final bool canViewFull;
  final EffectiveInvitationStatus? effectiveInvitationStatus;
  final bool readOnly;

  const ControlMissionDetailScreen({
    super.key,
    required this.mission,
    required this.canViewFull,
    this.effectiveInvitationStatus,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return ControlMissionWorkspaceScreen(
      mission: mission,
      readOnly: readOnly,
    );
  }
}
