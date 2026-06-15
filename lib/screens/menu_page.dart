import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/aule_theme_service.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../widgets/aule/aule_icons.dart';
import '../widgets/nearby_stops/tab_page_header.dart';
import 'auth/staff_login_screen.dart';
import 'settings_screen.dart';

class MenuPage extends StatelessWidget {
  final VoidCallback? onOpenHoraires;
  final VoidCallback? onOpenItinerary;

  const MenuPage({
    super.key,
    this.onOpenHoraires,
    this.onOpenItinerary,
  });

  static const _rows = [
    _MenuRow(
      label: 'Horaires',
      icon: LucideIcons.clock,
      action: _MenuAction.horaires,
    ),
    _MenuRow(
      label: 'Calculer un itinéraire',
      icon: LucideIcons.route,
      action: _MenuAction.itinerary,
    ),
    _MenuRow(
      label: 'Mes lignes suivies',
      icon: LucideIcons.bus,
    ),
    _MenuRow(
      label: 'Accessibilité',
      icon: LucideIcons.accessibility,
    ),
    _MenuRow(
      label: 'Notifications trafic',
      icon: LucideIcons.bell,
    ),
    _MenuRow(
      label: 'Espace conducteur / MSR',
      icon: LucideIcons.badgeCheck,
      action: _MenuAction.staffLogin,
    ),
    _MenuRow(
      label: 'Paramètres',
      icon: LucideIcons.settings,
      action: _MenuAction.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final primaryTextColor =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedTextColor =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);

    final supabase = context.watch<SupabaseService>();
    final themeService = context.watch<AuleThemeService>();
    final shortId = supabase.deviceUuid.split('-').first;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const TabPageHeader(
            title: 'Menu',
            subtitle: 'Compte, réglages et préférences',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderCol),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B66F5),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      LucideIcons.venetianMask,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compte anonyme',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                        Text(
                          'ID local $shortId · aucune donnée perso',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: mutedTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _ThemeToggle(
              themeService: themeService,
              cardBg: cardBg,
              borderCol: borderCol,
              primaryTextColor: primaryTextColor,
              mutedTextColor: mutedTextColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderCol),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: List.generate(_rows.length, (i) {
                  final row = _rows[i];
                  return _MenuTile(
                    row: row,
                    showDivider: i < _rows.length - 1,
                    borderCol: borderCol,
                    primaryTextColor: primaryTextColor,
                    onOpenHoraires: onOpenHoraires,
                    onOpenItinerary: onOpenItinerary,
                  );
                }),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'Aule · Nantes',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: mutedTextColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MenuAction { horaires, itinerary, settings, staffLogin }

class _MenuRow {
  final String label;
  final IconData icon;
  final _MenuAction? action;

  const _MenuRow({
    required this.label,
    required this.icon,
    this.action,
  });
}

class _ThemeToggle extends StatelessWidget {
  final AuleThemeService themeService;
  final Color cardBg;
  final Color borderCol;
  final Color primaryTextColor;
  final Color mutedTextColor;

  const _ThemeToggle({
    required this.themeService,
    required this.cardBg,
    required this.borderCol,
    required this.primaryTextColor,
    required this.mutedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeService.mode == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Apparence',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
          ),
          _ThemeChip(
            label: 'Clair',
            selected: !isDark,
            onTap: () => themeService.setMode(ThemeMode.light),
            mutedTextColor: mutedTextColor,
          ),
          const SizedBox(width: 8),
          _ThemeChip(
            label: 'Sombre',
            selected: isDark,
            onTap: () => themeService.setMode(ThemeMode.dark),
            mutedTextColor: mutedTextColor,
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
  final Color mutedTextColor;

  const _ThemeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.mutedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B66F5) : mutedTextColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : mutedTextColor,
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final _MenuRow row;
  final bool showDivider;
  final Color borderCol;
  final Color primaryTextColor;
  final VoidCallback? onOpenHoraires;
  final VoidCallback? onOpenItinerary;

  const _MenuTile({
    required this.row,
    required this.showDivider,
    required this.borderCol,
    required this.primaryTextColor,
    this.onOpenHoraires,
    this.onOpenItinerary,
  });

  void _handleTap(BuildContext context) {
    switch (row.action) {
      case _MenuAction.horaires:
        onOpenHoraires?.call();
      case _MenuAction.itinerary:
        onOpenItinerary?.call();
      case _MenuAction.settings:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      case _MenuAction.staffLogin:
        if (context.read<AuthService>().isAuthenticatedStaff) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vous êtes déjà connecté en mode terrain')),
          );
          break;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StaffLoginScreen()),
        );
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTap(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: borderCol))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B66F5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(row.icon, size: 18, color: const Color(0xFF1B66F5)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  row.label,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
              ),
              AuleIcons.chevron(size: 18, color: borderCol),
            ],
          ),
        ),
      ),
    );
  }
}
