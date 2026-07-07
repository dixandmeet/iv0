import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/driver_service_record.dart';
import '../../models/driver/driver_workspace_mode.dart';
import '../../services/driver/control_plan_service.dart';
import '../../services/driver/driver_service.dart';
import '../../services/driver/driver_workspace_service.dart';
import '../../services/platform/hub_engine.dart';
import '../../theme/driver_home_palette.dart';
import '../../widgets/driver/control_home_section.dart';
import '../../widgets/driver/driver_avatar.dart';
import '../../widgets/driver/driver_service_card.dart';
import '../../widgets/msr/msr_mission_list.dart';
import '../hub/hub_shell_screen.dart';
import 'driver_line_tracking_screen.dart';

/// Onglet « Accueil » : vue d'ensemble du service en cours.
/// Branché sur les vraies données ([DriverService]).
class DriverHomeScreen extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onStartService;
  final Future<void> Function() onEndService;
  final VoidCallback onOpenTerrain;

  const DriverHomeScreen({
    super.key,
    required this.onLogout,
    required this.onStartService,
    required this.onEndService,
    required this.onOpenTerrain,
  });

  @override
  Widget build(BuildContext context) {
    final driverService = context.watch<DriverService>();
    final workspace = context.watch<DriverWorkspaceService>();
    final hub = context.watch<HubEngine>();
    final driver = driverService.driver;

    if (driverService.loading && driver == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (driver == null) {
      return const _EmptyDriver();
    }

    final mode = workspace.currentMode;
    final isDrivingMode = mode == DriverWorkspaceMode.conduite;
    final isControlMode = mode == DriverWorkspaceMode.controle;
    final active = driverService.hasActiveService;
    final service = driverService.currentService;

    final controlPlan = isControlMode
        ? context.watch<ControlPlanService>()
        : null;
    final controlMission = controlPlan?.context?.displayMission;
    final controlLoaded = controlPlan?.loaded ?? false;

    final String statusTitle;
    final String statusSubtitle;
    final bool statusActive;
    if (isDrivingMode) {
      statusActive = active || driver.status == 'available';
      statusTitle = active ? 'En service' : driver.statusLabel;
      statusSubtitle = active
          ? 'Votre service est en cours'
          : 'Aucun service en cours';
    } else if (isControlMode) {
      if (!controlLoaded) {
        statusActive = false;
        statusTitle = 'Disponibilité';
        statusSubtitle = 'Chargement de votre service…';
      } else if (controlMission != null) {
        statusActive = true;
        statusTitle = 'Service en cours';
        statusSubtitle = controlMission.status.label;
      } else {
        statusActive = true;
        statusTitle = 'Disponible';
        statusSubtitle = 'Aucun service en cours';
      }
    } else {
      statusActive = true;
      statusTitle = mode.statusBadgeLabel;
      statusSubtitle = 'Espace opérationnel actif';
    }

    return RefreshIndicator(
      onRefresh: driverService.refresh,
      color: DriverHomePalette.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              _HeaderSection(
                firstName: driver.firstNameOrFallback,
                fullName: driver.fullName,
                avatarUrl: driver.avatarUrl,
                statusTitle: statusTitle,
                statusSubtitle: statusSubtitle,
                statusActive: statusActive,
                notificationCount: hub.unreadNotificationCount,
                onNotifications: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HubShellScreen(
                      initialView: HubView.notifications,
                    ),
                  ),
                ),
                onLogout: onLogout,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 196, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDrivingMode) ...[
                      if (active && service != null)
                        DriverServiceCard(
                          line: service.lineId != null
                              ? 'Ligne ${service.lineId}'
                              : 'Service en cours',
                          serviceCode: _serviceCodeLabel(service.serviceCode),
                          vehicleLabel: _vehicleLabel(service.vehicleId),
                          departure: service.startTimeReal != null
                              ? DateFormat(
                                  'HH:mm',
                                ).format(service.startTimeReal!)
                              : '—',
                          direction: _directionLabel(service),
                          nextDeparture: service.startTimeReal != null
                              ? DateFormat(
                                  'HH:mm',
                                ).format(service.startTimeReal!)
                              : '—',
                          delayMinutes: driverService.delayMinutes,
                          busy: driverService.busy,
                          onViewRoute: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DriverLineTrackingScreen(),
                            ),
                          ),
                          onEndService: onEndService,
                        )
                      else
                        _IdleServiceCard(
                          hasPlanned: service != null,
                          busy: driverService.busy,
                          onStart: onStartService,
                        ),
                    ] else if (isControlMode)
                      ControlHomeSection(onOpenTerrain: onOpenTerrain)
                    else
                      MsrMissionList(mode: mode, onOpenTerrain: onOpenTerrain),
                    if (driverService.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        driverService.errorMessage!,
                        style: const TextStyle(color: DriverHomePalette.danger),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _directionLabel(DriverServiceRecord service) {
    final headsign = service.headsign;
    if (headsign != null && headsign.trim().isNotEmpty) return headsign.trim();
    return service.directionLabel.replaceFirst('→ ', '');
  }

  String? _serviceCodeLabel(String? code) {
    if (code == null || code.trim().isEmpty) return null;
    return 'Service $code';
  }

  String? _vehicleLabel(String? vehicle) {
    if (vehicle == null || vehicle.isEmpty || vehicle.contains('-')) {
      return null;
    }
    return 'Bus $vehicle';
  }
}

class _HeaderSection extends StatelessWidget {
  final String firstName;
  final String fullName;
  final String? avatarUrl;
  final String statusTitle;
  final String statusSubtitle;
  final bool statusActive;
  final int notificationCount;
  final VoidCallback onNotifications;
  final VoidCallback onLogout;

  const _HeaderSection({
    required this.firstName,
    required this.fullName,
    required this.avatarUrl,
    required this.statusTitle,
    required this.statusSubtitle,
    required this.statusActive,
    required this.notificationCount,
    required this.onNotifications,
    required this.onLogout,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Bonne nuit';
    if (hour < 18) return 'Bonjour';
    return 'Bonsoir';
  }

  String _initialsOf(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final date = toBeginningOfSentenceCase(
      DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now()),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        height: 232,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D6A52), Color(0xFF0A5C46)],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(40),
          ),
          child: Stack(
            children: [
              const Positioned(
                width: 310,
                height: 310,
                top: -180,
                right: -90,
                child: _DecorativeCircle(opacity: 0.055),
              ),
              const Positioned(
                width: 220,
                height: 220,
                top: 38,
                right: -95,
                child: _DecorativeCircle(opacity: 0.04),
              ),
              const Positioned(
                width: 150,
                height: 150,
                bottom: -80,
                left: -55,
                child: _DecorativeCircle(opacity: 0.09),
              ),
              SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 450;
                    final actionSize = compact ? 42.0 : 48.0;
                    final identityTop = compact ? 40.0 : 28.0;
                    final statusTop = compact ? 118.0 : 108.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Stack(
                        children: [
                          Positioned(
                            top: compact ? 0 : 32,
                            right: 0,
                            child: Row(
                              children: [
                                _GlassIconButton(
                                  icon: LucideIcons.bell,
                                  size: actionSize,
                                  badge: notificationCount,
                                  onTap: onNotifications,
                                ),
                                const SizedBox(width: 8),
                                _GlassIconButton(
                                  icon: LucideIcons.logOut,
                                  size: actionSize,
                                  onTap: onLogout,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: identityTop,
                            left: 0,
                            right: compact ? 0 : actionSize * 2 + 32,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: DriverAvatarCompact(
                                    initials: _initialsOf(fullName),
                                    imageUrl: avatarUrl,
                                    size: 52,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: compact ? 22 : 25,
                                            height: 1.1,
                                            color: Colors.white,
                                            letterSpacing: -0.6,
                                          ),
                                          children: [
                                            TextSpan(text: '${_greeting()}, '),
                                            TextSpan(
                                              text: firstName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        date,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: compact ? 13 : 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: statusTop,
                            left: 72,
                            right: 0,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _AvailabilityBadge(
                                title: statusTitle,
                                subtitle: statusSubtitle,
                                active: statusActive,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  final double opacity;

  const _DecorativeCircle({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;

  const _AvailabilityBadge({
    required this.title,
    required this.subtitle,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF46C992).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF34D058)
                  : Colors.white.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: const Color(0xFF34D058).withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final int? badge;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.size,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, size: size * 0.43, color: Colors.white),
              if (badge != null && badge! > 0)
                Positioned(
                  right: -1,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 21,
                      minHeight: 21,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF04F3D),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdleServiceCard extends StatelessWidget {
  final bool hasPlanned;
  final bool busy;
  final VoidCallback onStart;

  const _IdleServiceCard({
    required this.hasPlanned,
    required this.busy,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            DriverHomePalette.gradientStart,
            DriverHomePalette.gradientEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: DriverHomePalette.gradientEnd.withValues(alpha: 0.2),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.calendarClock, size: 34, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            hasPlanned ? 'Service prêt à démarrer' : 'Aucun service en cours',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Démarrez votre service pour activer le suivi temps réel.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: busy ? null : onStart,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (busy)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: DriverHomePalette.gradientEnd,
                          ),
                        )
                      else
                        const Icon(
                          LucideIcons.play,
                          size: 17,
                          color: DriverHomePalette.gradientEnd,
                        ),
                      const SizedBox(width: 8),
                      const Text(
                        'Démarrer mon service',
                        style: TextStyle(
                          color: DriverHomePalette.gradientEnd,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDriver extends StatelessWidget {
  const _EmptyDriver();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Compte conducteur introuvable.\nContactez votre exploitation.',
          textAlign: TextAlign.center,
          style: TextStyle(color: DriverHomePalette.textDark),
        ),
      ),
    );
  }
}
