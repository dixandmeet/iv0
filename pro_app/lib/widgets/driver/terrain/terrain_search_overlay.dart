import 'package:flutter/material.dart';

import '../../../services/driver/terrain_search_service.dart';
import '../../../theme/driver_home_palette.dart';

/// Overlay de résultats de recherche classés par pertinence.
class TerrainSearchOverlay extends StatelessWidget {
  final List<TerrainSearchCategory> categories;
  final ValueChanged<TerrainSearchResult> onResultTap;
  final VoidCallback onClose;

  const TerrainSearchOverlay({
    super.key,
    required this.categories,
    required this.onResultTap,
    required this.onClose,
  });

  static String _stars(int priority) =>
      '★' * priority.clamp(1, 5) + '☆' * (5 - priority.clamp(1, 5));

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Material(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(20),
        elevation: 8,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Aucun résultat',
            style: TextStyle(color: DriverHomePalette.textSecondary),
          ),
        ),
      );
    }

    return Material(
      color: DriverHomePalette.card,
      borderRadius: BorderRadius.circular(20),
      elevation: 8,
      shadowColor: const Color(0x1A101A14),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.45,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          shrinkWrap: true,
          children: [
            for (var ci = 0; ci < categories.length; ci++) ...[
              if (ci > 0)
                const Divider(height: 20, color: DriverHomePalette.border),
              Text(
                '${_stars(categories[ci].priority)} ${categories[ci].label}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: DriverHomePalette.textDark,
                ),
              ),
              const SizedBox(height: 8),
              for (final r in categories[ci].results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    r.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: r.subtitle.isEmpty
                      ? null
                      : Text(
                          r.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                  onTap: () => onResultTap(r),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
