import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../services/passive_tracking_service.dart';
import '../theme/aule_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _passive = true;
  bool _batterySaver = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;

    final supabase = Provider.of<SupabaseService>(context);
    final tracking = Provider.of<PassiveTrackingService>(context);
    final shortId = supabase.deviceUuid.split('-').first;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const SizedBox(height: 6),
            Text('Réglages', style: _titleStyle(c)),
            const SizedBox(height: 16),

            // Bannière compte anonyme
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AuleTokens.rCardSm),
                border: Border.all(color: c.line),
                boxShadow: AuleTokens.cardShadow(c.shadow),
              ),
              child: Row(
                children: [
                  _IconTile(
                    icon: LucideIcons.venetianMask,
                    colors: c,
                    background: c.text,
                    iconColor: c.bg,
                    size: 48,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Compte anonyme', style: _h3Style(c)),
                        const SizedBox(height: 2),
                        Text('ID local $shortId · aucune donnée perso',
                            style: _subStyle(c)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: _SectionLabel('Confidentialité', colors: c),
            ),
            _Group(colors: c, children: [
              _ToggleRow(
                colors: c,
                icon: LucideIcons.locateFixed,
                title: 'Partage de position',
                sub: 'Contribue à la géoloc anonyme',
                value: supabase.consentBackground,
                onChanged: (v) async {
                  if (v) {
                    await supabase.updateBackgroundConsent(true);
                    await tracking.startTracking();
                  } else {
                    tracking.stopTracking();
                    await supabase.updateBackgroundConsent(false);
                  }
                },
              ),
              _ToggleRow(
                colors: c,
                icon: LucideIcons.eyeOff,
                title: 'Mode passif',
                sub: 'Détecter sans interagir',
                value: _passive,
                onChanged: (v) => setState(() => _passive = v),
              ),
            ]),

            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: _SectionLabel('Application', colors: c),
            ),
            _Group(colors: c, children: [
              _NavRow(
                colors: c,
                icon: LucideIcons.bell,
                title: 'Notifications',
                sub: 'Alertes de trajet & incidents',
                onTap: () {},
              ),
              _NavRow(
                colors: c,
                icon: LucideIcons.crosshair,
                title: 'GPS & précision',
                sub: 'Haute précision',
                onTap: () {},
              ),
              _ToggleRow(
                colors: c,
                icon: LucideIcons.batteryCharging,
                title: 'Économie de batterie',
                sub: 'Réduit la fréquence GPS',
                value: _batterySaver,
                onChanged: (v) => setState(() => _batterySaver = v),
              ),
            ]),

            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: _SectionLabel('Confidentialité & RGPD', colors: c),
            ),
            _Group(colors: c, children: [
              _NavRow(
                colors: c,
                icon: LucideIcons.shield,
                title: 'Charte de confidentialité',
                sub: 'Données purgées sous 15 min · jamais visible',
                onTap: () => _showCharter(context),
              ),
              _NavRow(
                colors: c,
                icon: supabase.isOfflineMode
                    ? LucideIcons.cloudOff
                    : LucideIcons.cloudCheck,
                title: 'Statut de l\'application',
                sub: supabase.isOfflineMode
                    ? 'Hors-ligne · données TAN locales'
                    : 'Connecté (Supabase)',
                trailing: _SoftBadge(
                  text: supabase.isOfflineMode ? 'HORS-LIGNE' : 'LIVE',
                  color: supabase.isOfflineMode ? c.warn : c.ok,
                  background: supabase.isOfflineMode ? c.surface2 : c.okBg,
                ),
                onTap: () {},
              ),
            ]),

            const SizedBox(height: 24),
            Center(
              child: Text('Wazibus · Nantes — v1.0.0',
                  style: GoogleFonts.hankenGrotesk(
                      fontSize: 11,
                      color: c.faint,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCharter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Charte de confidentialité', style: _h3Style(c)),
            const SizedBox(height: 14),
            _CharterLine(
                'Aucune donnée personnelle nominative (nom, e-mail, téléphone).',
                colors: c),
            _CharterLine(
                'Un identifiant anonyme aléatoire est généré localement sur l\'appareil.',
                colors: c),
            _CharterLine(
                'Les coordonnées brutes en arrière-plan sont purgées après 15 minutes maximum.',
                colors: c),
            _CharterLine(
                'Seuls les véhicules consolidés sont visibles. Votre position n\'est JAMAIS affichée.',
                colors: c),
            _CharterLine('Vous pouvez retirer votre consentement à tout moment.',
                colors: c),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// --- Styles Aule -----------------------------------------------------------

TextStyle _titleStyle(AuleColors c) => GoogleFonts.hankenGrotesk(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      color: c.text,
    );

TextStyle _h3Style(AuleColors c) => GoogleFonts.hankenGrotesk(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: c.text,
    );

TextStyle _rowTitleStyle(AuleColors c) => GoogleFonts.hankenGrotesk(
      fontSize: 14.5,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: c.text,
    );

TextStyle _subStyle(AuleColors c) => GoogleFonts.hankenGrotesk(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: c.muted,
    );

// --- Primitives Aule locales -----------------------------------------------

class _IconTile extends StatelessWidget {
  final IconData icon;
  final AuleColors colors;
  final Color? background;
  final Color? iconColor;
  final double size;

  const _IconTile({
    required this.icon,
    required this.colors,
    this.background,
    this.iconColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? colors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: size * 0.5, color: iconColor ?? colors.text),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AuleColors colors;
  const _SectionLabel(this.text, {required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.hankenGrotesk(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        height: 1.1,
        color: colors.faint,
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  const _SoftBadge(
      {required this.text, required this.color, required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

/// Interrupteur animé (équivalent Aule de FlowSwitch).
class _AuleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final AuleColors colors;

  const _AuleSwitch(
      {required this.value, required this.onChanged, required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? colors.brand : colors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: value ? colors.brand : colors.line),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  final AuleColors colors;
  const _Group({required this.children, required this.colors});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 67),
          child: Divider(height: 1, thickness: 1, color: colors.line),
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AuleTokens.rCardSm),
        border: Border.all(color: colors.line),
        boxShadow: AuleTokens.cardShadow(colors.shadow),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AuleTokens.rCardSm),
        child: Column(children: rows),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AuleColors colors;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          _IconTile(icon: icon, colors: colors),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _rowTitleStyle(colors)),
                const SizedBox(height: 1),
                Text(sub, style: _subStyle(colors)),
              ],
            ),
          ),
          _AuleSwitch(value: value, onChanged: onChanged, colors: colors),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final Widget? trailing;
  final VoidCallback onTap;
  final AuleColors colors;

  const _NavRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    required this.colors,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          children: [
            _IconTile(icon: icon, colors: colors),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _rowTitleStyle(colors)),
                  const SizedBox(height: 1),
                  Text(sub, style: _subStyle(colors)),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(LucideIcons.chevronRight, size: 18, color: colors.faint),
          ],
        ),
      ),
    );
  }
}

class _CharterLine extends StatelessWidget {
  final String text;
  final AuleColors colors;
  const _CharterLine(this.text, {required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child:
                Icon(LucideIcons.circleCheck, size: 18, color: colors.ok),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: _subStyle(colors).copyWith(height: 1.4)),
          ),
        ],
      ),
    );
  }
}
