import 'package:flutter/material.dart';

import 'models/line.dart';
import 'services/transport_repository.dart';
import 'screens/guidage_screen.dart';
import 'screens/home_screen.dart';
import 'screens/prise_service_screen.dart';
import 'screens/radar_screen.dart';
import 'widgets/splash_overlay.dart';

enum _AppScreen { home, priseService, guidage, radar }

/// Réglage de démo : compte cumulant les deux habilitations (conducteur + MSR),
/// avec bascule manuelle sur l'accueil. Passer à AccountModes.conducteur ou
/// AccountModes.controle pour simuler un compte à profil unique.
const _kAccountModes = AccountModes.mixte;

class AppShell extends StatefulWidget {
  final TransportDataSource repository;
  const AppShell({super.key, required this.repository});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _booting = true;
  AgentRole _role = AgentRole.conducteur;
  _AppScreen _screen = _AppScreen.home;
  ActiveService? _service;

  bool get _isMixte => _kAccountModes == AccountModes.mixte;
  bool get _isCond => _isMixte
      ? _role == AgentRole.conducteur
      : _kAccountModes == AccountModes.conducteur;

  _AppScreen get _effectiveScreen {
    const condScreens = {
      _AppScreen.home,
      _AppScreen.priseService,
      _AppScreen.guidage,
    };
    const ctrlScreens = {_AppScreen.home, _AppScreen.radar};
    final allowed = _isCond ? condScreens : ctrlScreens;
    return allowed.contains(_screen) ? _screen : _AppScreen.home;
  }

  @override
  Widget build(BuildContext context) {
    // Splash puis app : on affiche l'un OU l'autre (jamais un overlay
    // par-dessus l'app), sinon le splash en fondu continue d'intercepter
    // les taps même une fois invisible.
    if (_booting) {
      return SplashOverlay(onFinished: () => setState(() => _booting = false));
    }

    final screen = _effectiveScreen;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      child: KeyedSubtree(key: ValueKey(screen), child: _buildScreen(screen)),
    );
  }

  Widget _buildScreen(_AppScreen screen) {
    switch (screen) {
      case _AppScreen.home:
        return HomeScreen(
          accountModes: _kAccountModes,
          role: _role,
          serviceActive: _service != null,
          serviceLabel: _service?.label ?? 'Service',
          onPickRole: (r) => setState(() {
            _role = r;
            _screen = _AppScreen.home;
          }),
          onPriseService: () =>
              setState(() => _screen = _AppScreen.priseService),
          onGuidage: () => setState(() => _screen = _AppScreen.guidage),
          onActivateRadar: () => setState(() => _screen = _AppScreen.radar),
        );
      case _AppScreen.priseService:
        return PriseServiceScreen(
          repository: widget.repository,
          onBack: () => setState(() => _screen = _AppScreen.home),
          onStart: (line, direction, journey) => setState(() {
            _service = ActiveService(
              line: line,
              direction: direction,
              startedAt: DateTime.now(),
              journey: journey,
            );
            _screen = _AppScreen.guidage;
          }),
        );
      case _AppScreen.guidage:
        final service = _service;
        if (service == null) {
          return HomeScreen(
            accountModes: _kAccountModes,
            role: _role,
            serviceActive: false,
            serviceLabel: 'Service',
            onPickRole: (r) => setState(() {
              _role = r;
              _screen = _AppScreen.home;
            }),
            onPriseService: () =>
                setState(() => _screen = _AppScreen.priseService),
            onGuidage: () => setState(() => _screen = _AppScreen.guidage),
            onActivateRadar: () => setState(() => _screen = _AppScreen.radar),
          );
        }
        return GuidageScreen(
          service: service,
          onHome: () => setState(() => _screen = _AppScreen.home),
          onEnd: () => setState(() {
            _service = null;
            _screen = _AppScreen.home;
          }),
        );
      case _AppScreen.radar:
        return RadarScreen(
          repository: widget.repository,
          onBack: () => setState(() => _screen = _AppScreen.home),
        );
    }
  }
}
