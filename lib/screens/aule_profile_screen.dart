import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/aule_theme_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/aule/aule_icons.dart';
import 'settings_screen.dart';

/// Écran Profil — carte utilisateur et réglages.
class AuleProfileScreen extends StatelessWidget {
  const AuleProfileScreen({super.key});

  static const _rows = [
    _ProfileRow(label: 'Mes favoris', icon: _RowIcon.star),
    _ProfileRow(label: 'Mes lignes suivies', icon: _RowIcon.line),
    _ProfileRow(label: 'Accessibilité', icon: _RowIcon.access),
    _ProfileRow(label: 'Notifications trafic', icon: _RowIcon.bell),
    _ProfileRow(label: 'Paramètres', icon: _RowIcon.gear, opensSettings: true),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    final themeService = context.watch<AuleThemeService>();

    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Profil',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
                color: c.text,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                    spreadRadius: -16,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: c.brand,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'C',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Camille Renaud',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: c.text,
                          ),
                        ),
                        Text(
                          'Abonné·e Naolib · depuis 2023',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _ThemeToggle(themeService: themeService),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                    spreadRadius: -16,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: List.generate(_rows.length, (i) {
                  final row = _rows[i];
                  return _ProfileTile(
                    row: row,
                    showDivider: i < _rows.length - 1,
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RowIcon { star, line, access, bell, gear }

class _ProfileRow {
  final String label;
  final _RowIcon icon;
  final bool opensSettings;

  const _ProfileRow({
    required this.label,
    required this.icon,
    this.opensSettings = false,
  });
}

class _ThemeToggle extends StatelessWidget {
  final AuleThemeService themeService;
  const _ThemeToggle({required this.themeService});

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    final isDark = themeService.mode == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Apparence',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
          ),
          _ThemeChip(
            label: 'Clair',
            selected: !isDark,
            onTap: () => themeService.setMode(ThemeMode.light),
          ),
          const SizedBox(width: 8),
          _ThemeChip(
            label: 'Sombre',
            selected: isDark,
            onTap: () => themeService.setMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? c.brand : c.surface2,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : c.muted,
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final _ProfileRow row;
  final bool showDivider;

  const _ProfileTile({required this.row, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: row.opensSettings
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                )
            : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: c.lineSoft))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.brandWeak,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: _icon(row.icon, c.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  row.label,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: c.text,
                  ),
                ),
              ),
              AuleIcons.chevron(size: 18, color: c.faint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(_RowIcon icon, Color color) {
    switch (icon) {
      case _RowIcon.star:
        return AuleIcons.favoriteOutline(size: 19, color: color);
      case _RowIcon.line:
        return AuleIcons.lineFollow(size: 19, color: color);
      case _RowIcon.access:
        return AuleIcons.accessibility(size: 19, color: color);
      case _RowIcon.bell:
        return AuleIcons.bell(size: 19, color: color);
      case _RowIcon.gear:
        return AuleIcons.gear(size: 19, color: color);
    }
  }
}
