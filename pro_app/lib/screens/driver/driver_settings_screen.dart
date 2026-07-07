import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../services/driver/driver_settings_service.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../widgets/driver/driver_menu_item.dart';

/// Réglages de l'espace conducteur : notifications, GPS, confidentialité.
class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationService>().refreshIfPermitted();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<LocationService>().refreshIfPermitted();
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _gpsStatusLabel(LocationService location) {
    if (!location.serviceEnabled) return 'GPS désactivé sur l\'appareil';
    return switch (location.permissionStatus) {
      LocationPermission.always => 'Autorisé en arrière-plan',
      LocationPermission.whileInUse => 'Autorisé en premier plan',
      LocationPermission.denied => 'Autorisation refusée',
      LocationPermission.deniedForever => 'Autorisation bloquée',
      LocationPermission.unableToDetermine => 'État inconnu',
    };
  }

  Color _gpsStatusColor(LocationService location) {
    if (!location.serviceEnabled) return DriverHomePalette.warning;
    return switch (location.permissionStatus) {
      LocationPermission.always => DriverHomePalette.primary,
      LocationPermission.whileInUse => DriverHomePalette.blue,
      _ => DriverHomePalette.danger,
    };
  }

  Future<void> _openLocationSettings() async {
    final opened = await Geolocator.openLocationSettings();
    if (!mounted) return;
    if (!opened) _snack('Impossible d\'ouvrir les réglages de localisation');
  }

  Future<void> _openAppSettings() async {
    final opened = await openAppSettings();
    if (!mounted) return;
    if (!opened) _snack('Impossible d\'ouvrir les réglages de l\'application');
  }

  void _showPrivacyCharter() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: DriverHomePalette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: DriverHomePalette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Text(
                'Données & confidentialité',
                style: TextStyle(
                  color: DriverHomePalette.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              const _CharterLine(
                'Votre position est transmise uniquement pendant un service actif.',
              ),
              const _CharterLine(
                'Les coordonnées servent au suivi de ligne et à la coordination terrain.',
              ),
              const _CharterLine(
                'Vos données personnelles (nom, matricule, e-mail) sont liées à votre compte professionnel Naolib.',
              ),
              const _CharterLine(
                'Vous pouvez retirer les autorisations GPS à tout moment dans les réglages système.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<DriverSettingsService>();
    final location = context.watch<LocationService>();
    final supabase = context.watch<SupabaseService>();
    final gpsColor = _gpsStatusColor(location);

    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      appBar: AppBar(
        backgroundColor: DriverHomePalette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'Paramètres',
          style: TextStyle(
            color: DriverHomePalette.textDark,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _GpsStatusCard(
            label: _gpsStatusLabel(location),
            color: gpsColor,
            trackingActive: location.currentPosition != null,
            onOpenSettings: _openLocationSettings,
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Notifications'),
          const SizedBox(height: 10),
          DriverMenuGroup(
            items: [
              _SettingsToggleRow(
                icon: LucideIcons.bus,
                label: 'Service & retard',
                subtitle: 'Prise de service, fin de course, écarts horaires',
                value: settings.notifyService,
                onChanged: settings.setNotifyService,
              ),
              _SettingsToggleRow(
                icon: LucideIcons.messageCircle,
                label: 'Messages',
                subtitle: 'Échanges avec la régulation',
                value: settings.notifyMessages,
                onChanged: settings.setNotifyMessages,
              ),
              _SettingsToggleRow(
                icon: LucideIcons.triangleAlert,
                label: 'Incidents terrain',
                subtitle: 'Alertes carte et demandes d\'assistance',
                value: settings.notifyIncidents,
                onChanged: settings.setNotifyIncidents,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Application'),
          const SizedBox(height: 10),
          DriverMenuGroup(
            items: [
              _SettingsToggleRow(
                icon: LucideIcons.batteryCharging,
                label: 'Économie de batterie',
                subtitle: 'Réduit la fréquence de remontée GPS',
                value: settings.batterySaver,
                onChanged: settings.setBatterySaver,
              ),
              _SettingsToggleRow(
                icon: LucideIcons.smartphone,
                label: 'Retour haptique',
                subtitle: 'Vibrations sur les actions importantes',
                value: settings.hapticFeedback,
                onChanged: settings.setHapticFeedback,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Confidentialité'),
          const SizedBox(height: 10),
          DriverMenuGroup(
            items: [
              _SettingsNavRow(
                icon: LucideIcons.shield,
                label: 'Données & confidentialité',
                subtitle: 'Usage de la géolocalisation et des données pro',
                onTap: _showPrivacyCharter,
              ),
              _SettingsNavRow(
                icon: LucideIcons.cloud,
                label: 'Connexion serveur',
                subtitle: supabase.isOfflineMode
                    ? 'Mode hors-ligne — données locales'
                    : 'Connecté à Supabase',
                trailing: _StatusPill(
                  label: supabase.isOfflineMode ? 'Hors-ligne' : 'En ligne',
                  color: supabase.isOfflineMode
                      ? DriverHomePalette.warning
                      : DriverHomePalette.primary,
                ),
                onTap: () {},
                showChevron: false,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionTitle('Système'),
          const SizedBox(height: 10),
          DriverMenuGroup(
            items: [
              _SettingsNavRow(
                icon: LucideIcons.crosshair,
                label: 'Réglages GPS',
                subtitle: 'Autorisations de localisation de l\'appareil',
                onTap: _openLocationSettings,
              ),
              _SettingsNavRow(
                icon: LucideIcons.settings2,
                label: 'Réglages de l\'application',
                subtitle: 'Caméra, notifications système, stockage…',
                onTap: _openAppSettings,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Center(
            child: Text(
              'Aule Pro — version 1.0.0',
              style: TextStyle(
                color: DriverHomePalette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: DriverHomePalette.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _GpsStatusCard extends StatelessWidget {
  final String label;
  final Color color;
  final bool trackingActive;
  final VoidCallback onOpenSettings;

  const _GpsStatusCard({
    required this.label,
    required this.color,
    required this.trackingActive,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DriverHomePalette.border),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(LucideIcons.locateFixed, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Géolocalisation',
                  style: TextStyle(
                    color: DriverHomePalette.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trackingActive) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Position actuelle disponible',
                    style: TextStyle(
                      color: DriverHomePalette.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onOpenSettings,
            child: const Text('Réglages'),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: DriverHomePalette.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: DriverHomePalette.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: DriverHomePalette.textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 12.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          _DriverSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SettingsNavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showChevron;

  const _SettingsNavRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: DriverHomePalette.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: DriverHomePalette.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: DriverHomePalette.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: DriverHomePalette.textSecondary,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              if (showChevron) const SizedBox(width: 8),
            ],
            if (showChevron)
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: DriverHomePalette.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _DriverSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DriverSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? DriverHomePalette.primary : DriverHomePalette.border,
          borderRadius: BorderRadius.circular(14),
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
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
            child: Icon(
              LucideIcons.circleCheck,
              size: 18,
              color: DriverHomePalette.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: DriverHomePalette.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
