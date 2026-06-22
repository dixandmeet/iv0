import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

class TabPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const TabPageHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedTextColor =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: hankenGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: primaryTextColor,
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: hankenGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: mutedTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
