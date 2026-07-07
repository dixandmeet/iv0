import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/driver/mission_models.dart';
import '../../theme/driver_home_palette.dart';
import '../../widgets/driver/control_mission/mission_shared_widgets.dart';
import 'control_plan_screen.dart';

class ControlMissionDebriefScreen extends StatelessWidget {
  final MissionDebrief debrief;

  const ControlMissionDebriefScreen({super.key, required this.debrief});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      appBar: AppBar(
        title: const Text('Débrief'),
        backgroundColor: DriverHomePalette.gradientStart,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              debrief.missionName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            if (debrief.displayNumber != null)
              Text('Service #${debrief.displayNumber}'),
            if (debrief.referenceCode != null)
              Text(
                debrief.referenceCode!,
                style: const TextStyle(
                  color: DriverHomePalette.textSecondary,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 20),
            _line('Durée', debrief.durationLabel),
            _line('Équipe', '${debrief.teamSize} agents'),
            if (debrief.padName != null) _line('PAD', debrief.padName!),
            if (debrief.operationalResponsibleName != null)
              _line('Responsable', debrief.operationalResponsibleName!),
            _line('Incidents', '${debrief.incidentsCount}'),
            _line('Notes', '${debrief.notesCount}'),
            const Spacer(),
            MissionGradientButton(
              label: 'Retour à mes services',
              icon: LucideIcons.arrowLeft,
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ControlPlanScreen()),
                  (r) => r.isFirst,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              k,
              style: const TextStyle(color: DriverHomePalette.textSecondary),
            ),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
