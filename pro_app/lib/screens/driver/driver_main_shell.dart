import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/driver/driver_workspace_mode.dart';
import '../../services/auth_service.dart';
import '../../services/driver/driver_service.dart';
import '../../services/driver/driver_settings_service.dart';
import '../../services/driver/driver_workspace_service.dart';
import '../../services/platform/hub_engine.dart';
import '../../services/platform/local_notification_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../widgets/driver/driver_bottom_nav.dart';
import '../hub/hub_shell_screen.dart';
import 'driver_home_screen.dart';
import 'driver_menu_screen.dart';
import 'driver_take_service_screen.dart';
import 'driver_terrain_screen.dart';

/// Coquille principale de l'espace conducteur : navigation basse à 3 onglets
/// (Accueil / Terrain / Menu) et actions transverses (prise/fin de service,
/// déconnexion, bascule mode MSR).
class DriverMainShell extends StatefulWidget {
  const DriverMainShell({super.key});

  @override
  State<DriverMainShell> createState() => _DriverMainShellState();
}

class _DriverMainShellState extends State<DriverMainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileWorkspace();
      _initHub();
    });
  }

  void _reconcileWorkspace() {
    if (!mounted) return;
    final driver = context.read<DriverService>().driver;
    context.read<DriverWorkspaceService>().reconcileWithProfile(driver);
  }

  /// Active le suivi des notifications et les compteurs de badge dès l'entrée
  /// dans l'espace conducteur (sans attendre l'ouverture du Hub).
  void _initHub() {
    if (!mounted) return;
    final hub = context.read<HubEngine>();
    final settings = context.read<DriverSettingsService>();
    final local = context.read<LocalNotificationService>();
    final userId = context.read<AuthService>().profile?.id;

    // Relais des notifications realtime vers une bannière système, filtré par
    // les préférences du conducteur. On évite la bannière si l'écran des
    // notifications est déjà ouvert (l'info est alors visible directement).
    hub.onIncomingNotification = (notif) {
      if (hub.view == HubView.notifications) return;
      if (!settings.allowsCategory(notif.category)) return;
      local.show(notif);
    };
    local.onSelect = (_) => _openHubNotifications();
    local.requestPermissions();

    if (userId != null) hub.subscribeRealtime(userId);
    hub.refreshCounts();
  }

  void _openHubNotifications() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HubShellScreen(initialView: HubView.notifications),
      ),
    );
  }

  void _goToTab(int i) => setState(() => _index = i);

  void _startService() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DriverTakeServiceScreen()),
    );
  }

  Future<void> _confirmEndService() async {
    final driver = context.read<DriverService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer le service ?'),
        content: const Text(
          'La géolocalisation sera arrêtée et un résumé vous sera présenté.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (ok == true) await driver.endService();
  }

  Future<void> _confirmModeSwitch(DriverWorkspaceMode target) async {
    final driverService = context.read<DriverService>();
    final workspace = context.read<DriverWorkspaceService>();
    final profile = driverService.driver;

    final result = workspace.trySwitchMode(
      target,
      profile: profile,
      hasActiveService: driverService.hasActiveService,
    );

    switch (result) {
      case WorkspaceSwitchResult.unchanged:
        return;
      case WorkspaceSwitchResult.switched:
        await workspace.applySwitch(target);
        return;
      case WorkspaceSwitchResult.needsConfirmation:
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Passer en mode ${target.label} ?'),
            content: Text(
              'Un service de conduite est en cours. '
              'Il sera terminé et la géolocalisation véhicule sera arrêtée '
              'avant de basculer en mode ${target.label.toLowerCase()}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Terminer et basculer'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await workspace.completeSwitch(
            target,
            driver: driverService,
            endDrivingService: true,
          );
        }
    }
  }

  Future<void> _confirmLogout() async {
    final driver = context.read<DriverService>();
    final auth = context.read<AuthService>();

    if (driver.hasActiveService) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Service en cours'),
          content: const Text(
            'Un service est actif. Terminez-le avant de vous déconnecter, '
            'ou déconnectez-vous quand même (le GPS sera coupé).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Se déconnecter'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final driverProfile = context.watch<DriverService>().driver;
    final onModeSwitch = driverProfile != null
        ? (DriverWorkspaceMode m) => _confirmModeSwitch(m)
        : null;

    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      body: IndexedStack(
        index: _index,
        children: [
          DriverHomeScreen(
            onLogout: _confirmLogout,
            onStartService: _startService,
            onEndService: _confirmEndService,
            onOpenTerrain: () => _goToTab(1),
          ),
          DriverTerrainScreen(isActive: _index == 1),
          DriverMenuScreen(
            onLogout: _confirmLogout,
            onModeSwitch: onModeSwitch,
          ),
        ],
      ),
      bottomNavigationBar: DriverBottomNav(
        currentIndex: _index,
        onTap: _goToTab,
      ),
    );
  }
}
