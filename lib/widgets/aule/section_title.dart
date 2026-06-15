import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/aule_theme.dart';

class SectionTitle extends StatelessWidget {
  final Widget icon;
  final String title;

  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 13),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: c.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
