import 'package:flutter/material.dart';

import '../../theme/flow_theme.dart';

/// Titre de section pour l'écran Accueil (emoji + libellé).
class HomeSectionHeader extends StatelessWidget {
  final String emoji;
  final String title;

  const HomeSectionHeader({
    super.key,
    required this.emoji,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Text(
        '$emoji $title',
        style: FlowText.title,
      ),
    );
  }
}
