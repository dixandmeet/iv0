import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/aule_theme.dart';

/// Une entrée du segmented control : icône + libellé.
typedef SegmentedTab = ({IconData icon, String label});

/// Segmented control en pilule (style cohérent avec les onglets des Favoris),
/// utilisé pour basculer entre les sous-vues du hub Horaires.
class SegmentedTabs extends StatelessWidget {
  final List<SegmentedTab> tabs;
  final int selected;
  final AuleColors colors;
  final ValueChanged<int> onSelected;

  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.colors,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? colors.brand : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: i == selected
                        ? [
                            BoxShadow(
                              color: colors.brand.withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tabs[i].icon,
                        size: 16,
                        color: i == selected ? Colors.white : colors.muted,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          tabs[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: hankenGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: i == selected ? Colors.white : colors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
