import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../services/passive_tracking_service.dart';
import '../theme/flow_theme.dart';
import '../widgets/flow_primitives.dart';
import 'main_shell.dart';

class PrivacyConsentScreen extends StatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  bool _loading = false;

  Future<void> _handleConsent(BuildContext context, bool accepted) async {
    setState(() => _loading = true);

    final navigator = Navigator.of(context);
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    final location = Provider.of<LocationService>(context, listen: false);
    final tracking = Provider.of<PassiveTrackingService>(context, listen: false);

    await supabase.updateBackgroundConsent(accepted);

    if (accepted) {
      // Une erreur de permission (refus, config manquante…) ne doit jamais
      // bloquer l'accès à la carte : l'app fonctionne aussi sans GPS.
      try {
        final hasPerm = await location.requestBackgroundPermission();
        if (hasPerm) {
          await tracking.startTracking();
        }
      } catch (e) {
        debugPrint('Wazibus: location permission failed ($e). Continuing.');
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);

    navigator.pushReplacement(
      FlowPageRoute(page: const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo
              Center(
                child: Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    color: FlowColors.ink,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: FlowTokens.soft,
                  ),
                  child: const Center(
                    child: Text('F',
                        style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -2)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text('FLOW', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
              const SizedBox(height: 8),
              const Text(
                'Le GPS communautaire de vos transports en commun à Nantes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: FlowColors.g2, fontWeight: FontWeight.w500, height: 1.4),
              ),
              const Spacer(flex: 2),

              // Encadré info
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: FlowColors.fill,
                  borderRadius: BorderRadius.circular(FlowTokens.rCard),
                ),
                child: const Column(
                  children: [
                    _InfoRow(LucideIcons.venetianMask, '100 % anonyme',
                        'Aucun compte. Aucun nom, e-mail ou numéro stocké.'),
                    SizedBox(height: 16),
                    _InfoRow(LucideIcons.locateFixed, 'Géolocalisation passive',
                        'Votre position aide à détecter les bus et trams pour tous les usagers.'),
                    SizedBox(height: 16),
                    _InfoRow(LucideIcons.eyeOff, 'Confidentialité absolue',
                        'Vous n\'êtes jamais visible. Positions brutes effacées après 15 min.'),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              if (_loading)
                const Center(child: CircularProgressIndicator(color: FlowColors.blue))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FlowButton(
                      label: 'Activer et participer',
                      onPressed: () => _handleConsent(context, true),
                    ),
                    const SizedBox(height: 6),
                    FlowButton(
                      label: 'Continuer en mode lecture seule',
                      variant: FlowButtonVariant.ghost,
                      onPressed: () => _handleConsent(context, false),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoRow(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: FlowColors.white, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: FlowColors.blue, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: FlowColors.ink)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: FlowColors.g2, height: 1.35, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
