import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/driver_onboarding_data.dart';
import '../../models/driver/driver_persona_icon.dart';
import '../../models/driver/driver_workspace_mode.dart';
import '../../services/driver/driver_onboarding_service.dart';
import '../../services/driver/driver_service.dart';
import '../../services/driver/driver_workspace_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../widgets/driver/driver_avatar.dart';
import '../../widgets/driver/driver_menu_item.dart';
import '../../widgets/driver/driver_mode_switcher.dart';
import 'control_plan_screen.dart';
import 'driver_feed_screen.dart';
import 'service_exchange_screen.dart';
import '../../screens/hub/hub_shell_screen.dart';
import '../../screens/resource/resource_shell_screen.dart';
import '../../services/platform/hub_engine.dart';
import 'driver_profile_screen.dart';
import 'driver_settings_screen.dart';
import 'driver_take_service_screen.dart';

/// Onglet « Menu » : profil conducteur et accès aux fonctionnalités secondaires.
class DriverMenuScreen extends StatelessWidget {
  final VoidCallback onLogout;
  final void Function(DriverWorkspaceMode mode)? onModeSwitch;

  const DriverMenuScreen({
    super.key,
    required this.onLogout,
    this.onModeSwitch,
  });

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    if (parts.isNotEmpty) return parts.first[0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final driverService = context.watch<DriverService>();
    final workspace = context.watch<DriverWorkspaceService>();
    final onboarding = context.watch<DriverOnboardingService>();
    final hub = context.watch<HubEngine>();
    final driver = driverService.driver;
    final roleLabel = workspace.currentMode.menuRoleLabel;
    final personaAsset = DriverPersonaIcon.assetFor(
      workspace: workspace.currentMode,
      gender: onboarding.savedData.gender,
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _hero(
          context,
          name: driver?.fullName ?? 'Conducteur',
          role: roleLabel,
          matricule: driver?.driverNumber,
          avatarUrl: driver?.avatarUrl,
          initials: _initials(driver?.fullName ?? 'C'),
          personaAsset: personaAsset,
          mode: workspace.currentMode,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            children: [
              if (driver != null && onModeSwitch != null) ...[
                DriverModeSwitcher(
                  profile: driver,
                  onModeSelected: onModeSwitch!,
                ),
                const SizedBox(height: 18),
              ],
              if (workspace.currentMode == DriverWorkspaceMode.controle) ...[
                DriverMenuGroup(
                  items: [
                    DriverMenuItem(
                      icon: LucideIcons.clipboardList,
                      label: 'Mes services',
                      onTap: () => _push(context, const ControlPlanScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              DriverMenuGroup(
                items: [
                  DriverMenuItem(
                    icon: LucideIcons.newspaper,
                    label: 'Fil d\'actualité',
                    onTap: () => _push(context, const DriverFeedScreen()),
                  ),
                  if (workspace.currentMode ==
                      DriverWorkspaceMode.conduite) ...[
                    DriverMenuItem(
                      icon: LucideIcons.calendarDays,
                      label: 'Mes services',
                      onTap: () =>
                          _push(context, const DriverTakeServiceScreen()),
                    ),
                    DriverMenuItem(
                      icon: LucideIcons.clock,
                      label: 'Historique',
                      onTap: () => _snack(context, 'Historique à venir'),
                    ),
                  ],
                  if (onboarding.savedData.profile == ProProfile.reseau)
                    DriverMenuItem(
                      icon: LucideIcons.repeat,
                      label: 'Échanges de service',
                      onTap: () =>
                          _push(context, const ServiceExchangeScreen()),
                    ),
                  DriverMenuItem(
                    icon: LucideIcons.activity,
                    label: 'Activité',
                    badge: hub.badgeCount > 0 ? hub.badgeCount : null,
                    onTap: () => _push(context, const HubShellScreen()),
                  ),
                  DriverMenuItem(
                    icon: LucideIcons.headphones,
                    label: 'Support',
                    onTap: () => _push(
                      context,
                      const ResourceShellScreen(
                        resourceId: '00000000-0000-4000-8000-000000000101',
                      ),
                    ),
                  ),
                  DriverMenuItem(
                    icon: LucideIcons.chartColumn,
                    label: 'Statistiques',
                    onTap: () => _snack(context, 'Statistiques à venir'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DriverMenuGroup(
                items: [
                  DriverMenuItem(
                    icon: LucideIcons.settings,
                    label: 'Paramètres',
                    onTap: () => _push(context, const DriverSettingsScreen()),
                  ),
                  DriverMenuItem(
                    icon: LucideIcons.headphones,
                    label: 'Aide app',
                    onTap: () => _snack(context, 'Support technique à venir'),
                  ),
                  DriverMenuItem(
                    icon: LucideIcons.info,
                    label: 'À propos',
                    onTap: () => _snack(context, 'Aule Pro — version 1.0'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DriverMenuGroup(
                items: [
                  DriverMenuItem(
                    icon: LucideIcons.logOut,
                    label: 'Déconnexion',
                    destructive: true,
                    showChevron: false,
                    onTap: onLogout,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  Widget _hero(
    BuildContext context, {
    required String name,
    required String role,
    required String? matricule,
    required String? avatarUrl,
    required String initials,
    required String? personaAsset,
    required DriverWorkspaceMode mode,
  }) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DriverHomePalette.gradientStart,
              DriverHomePalette.gradientEnd,
            ],
          ),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: DriverHomePalette.darkGreen.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
          child: Stack(
            children: [
              Positioned(top: -40, right: -30, child: _glow(150, 0.12)),
              Positioned(bottom: -50, left: -20, child: _glow(140, 0.08)),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Menu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _glassProfile(
                        context,
                        name: name,
                        role: role,
                        matricule: matricule,
                        avatarUrl: avatarUrl,
                        initials: initials,
                        personaAsset: personaAsset,
                        mode: mode,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassProfile(
    BuildContext context, {
    required String name,
    required String role,
    required String? matricule,
    required String? avatarUrl,
    required String initials,
    required String? personaAsset,
    required DriverWorkspaceMode mode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _push(context, const DriverProfileScreen()),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2),
                  ),
                  child: DriverAvatarCompact(
                    initials: initials,
                    imageUrl: avatarUrl,
                    size: 50,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13.5,
                        ),
                      ),
                      if (matricule != null && matricule.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          'Matricule $matricule',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (personaAsset != null) ...[
                  const SizedBox(width: 10),
                  _glassPersona(personaAsset, mode),
                ] else
                  Icon(LucideIcons.chevronRight,
                      size: 20, color: Colors.white.withValues(alpha: 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassPersona(String asset, DriverWorkspaceMode mode) {
    return Container(
      width: 60,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 42,
            child: Transform.scale(
              scale: 1.3,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                errorBuilder: (_, _, _) => Icon(
                  mode == DriverWorkspaceMode.conduite
                      ? LucideIcons.bus
                      : LucideIcons.shieldCheck,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mode.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

