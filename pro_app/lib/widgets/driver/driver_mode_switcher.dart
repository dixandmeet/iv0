import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/driver/driver_profile.dart';
import '../../models/driver/driver_workspace_mode.dart';
import '../../services/driver/driver_workspace_service.dart';
import '../../theme/driver_home_palette.dart';

/// Segmented control pour basculer entre Conduite et mode(s) MSR.
class DriverModeSwitcher extends StatelessWidget {
  final DriverProfile profile;
  final ValueChanged<DriverWorkspaceMode> onModeSelected;

  const DriverModeSwitcher({
    super.key,
    required this.profile,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (!profile.hasMsrCapabilities) return const SizedBox.shrink();

    final workspace = context.watch<DriverWorkspaceService>();
    final modes = workspace.availableModes(profile);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DriverHomePalette.border.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < modes.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _ModeSegment(
                mode: modes[i],
                selected: workspace.currentMode == modes[i],
                onTap: () {
                  if (workspace.currentMode != modes[i]) {
                    onModeSelected(modes[i]);
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  final DriverWorkspaceMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _ModeSegment({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = mode.accentColor;
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      elevation: selected ? 1 : 0,
      shadowColor: DriverHomePalette.cardShadow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Text(
            mode.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? color : DriverHomePalette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
