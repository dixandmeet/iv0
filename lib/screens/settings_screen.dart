import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../services/passive_tracking_service.dart';
import '../theme/flow_theme.dart';
import '../widgets/flow_primitives.dart';
import '../widgets/flow_widgets.dart';
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
    final supabase = Provider.of<SupabaseService>(context);
    final tracking = Provider.of<PassiveTrackingService>(context);
    final shortId = supabase.deviceUuid.split('-').first;

    return Scaffold(
      backgroundColor: FlowColors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const SizedBox(height: 6),
            const Text('Réglages', style: FlowText.title),
            const SizedBox(height: 16),

            // Bannière compte anonyme
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: FlowColors.white,
                borderRadius: BorderRadius.circular(FlowTokens.rCard),
                border: Border.all(color: FlowColors.line),
                boxShadow: FlowTokens.soft,
              ),
              child: Row(
                children: [
                  const IconTile(icon: LucideIcons.venetianMask, background: FlowColors.ink, iconColor: Colors.white, size: 48),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Compte anonyme', style: FlowText.h3),
                        const SizedBox(height: 2),
                        Text('ID local $shortId · aucune donnée perso', style: FlowText.rowSub),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),
            const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: SectionLabel('Confidentialité')),
            _Group(children: [
              _ToggleRow(
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
                icon: LucideIcons.eyeOff,
                title: 'Mode passif',
                sub: 'Détecter sans interagir',
                value: _passive,
                onChanged: (v) => setState(() => _passive = v),
              ),
            ]),

            const SizedBox(height: 22),
            const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: SectionLabel('Application')),
            _Group(children: [
              _NavRow(
                icon: LucideIcons.bell,
                title: 'Notifications',
                sub: 'Alertes de trajet & incidents',
                onTap: () {},
              ),
              _NavRow(
                icon: LucideIcons.crosshair,
                title: 'GPS & précision',
                sub: 'Haute précision',
                onTap: () {},
              ),
              _ToggleRow(
                icon: LucideIcons.batteryCharging,
                title: 'Économie de batterie',
                sub: 'Réduit la fréquence GPS',
                value: _batterySaver,
                onChanged: (v) => setState(() => _batterySaver = v),
              ),
            ]),

            const SizedBox(height: 22),
            const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: SectionLabel('Confidentialité & RGPD')),
            _Group(children: [
              _NavRow(
                icon: LucideIcons.shield,
                title: 'Charte de confidentialité',
                sub: 'Données purgées sous 15 min · jamais visible',
                onTap: () => _showCharter(context),
              ),
              _NavRow(
                icon: supabase.isOfflineMode ? LucideIcons.cloudOff : LucideIcons.cloudCheck,
                title: 'Statut de l\'application',
                sub: supabase.isOfflineMode ? 'Hors-ligne · données TAN locales' : 'Connecté (Supabase)',
                trailing: SoftBadge(
                  text: supabase.isOfflineMode ? 'HORS-LIGNE' : 'LIVE',
                  color: supabase.isOfflineMode ? FlowColors.orange : FlowColors.green,
                  background: supabase.isOfflineMode ? FlowColors.orangeSoft : FlowColors.greenSoft,
                ),
                onTap: () {},
              ),
            ]),

            const SizedBox(height: 24),
            const Center(
              child: Text('FLOW · Nantes — v1.0.0',
                  style: TextStyle(fontSize: 11, color: FlowColors.gWeak, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCharter(BuildContext context) {
    showFlowSheet(
      context,
      builder: (_) => const FlowSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Charte de confidentialité', style: FlowText.h3),
            SizedBox(height: 14),
            _CharterLine('Aucune donnée personnelle nominative (nom, e-mail, téléphone).'),
            _CharterLine('Un identifiant anonyme aléatoire est généré localement sur l\'appareil.'),
            _CharterLine('Les coordonnées brutes en arrière-plan sont purgées après 15 minutes maximum.'),
            _CharterLine('Seuls les véhicules consolidés sont visibles. Votre position n\'est JAMAIS affichée.'),
            _CharterLine('Vous pouvez retirer votre consentement à tout moment.'),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(const Padding(
          padding: EdgeInsets.only(left: 67),
          child: Divider(height: 1),
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: FlowColors.white,
        borderRadius: BorderRadius.circular(FlowTokens.rCard),
        border: Border.all(color: FlowColors.line),
        boxShadow: FlowTokens.soft,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FlowTokens.rCard),
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

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          IconTile(icon: icon),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FlowText.rowTitle.copyWith(fontSize: 14.5)),
                const SizedBox(height: 1),
                Text(sub, style: FlowText.rowSub),
              ],
            ),
          ),
          FlowSwitch(value: value, onChanged: onChanged),
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

  const _NavRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return FlowTappable(
      onTap: onTap,
      pressedScale: 0.985,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          children: [
            IconTile(icon: icon),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: FlowText.rowTitle.copyWith(fontSize: 14.5)),
                  const SizedBox(height: 1),
                  Text(sub, style: FlowText.rowSub),
                ],
              ),
            ),
            if (trailing != null) trailing! else const Icon(LucideIcons.chevronRight, size: 18, color: FlowColors.gWeak),
          ],
        ),
      ),
    );
  }
}

class _CharterLine extends StatelessWidget {
  final String text;
  const _CharterLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.circleCheck, size: 18, color: FlowColors.green),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: FlowText.rowSub.copyWith(height: 1.4))),
        ],
      ),
    );
  }
}
