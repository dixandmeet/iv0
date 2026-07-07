import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import '../services/driver/driver_service.dart';
import 'driver/driver_pending_screen.dart';
import 'driver/driver_shell.dart';
import 'msr/msr_shell.dart';
import 'pro_login_screen.dart';

/// Racine de l'app Pro : gère la connexion puis route selon le rôle.
///
/// - non connecté → [ProLoginScreen]
/// - conducteur (présent dans `drivers`) → [DriverShell]
/// - agent MSR → espace MSR (scaffold, lot suivant)
/// - autre → accès refusé (compte non professionnel)
///
/// Les changements d'état (connexion / inscription réussie → accueil) sont
/// animés par un [AnimatedSwitcher] : fondu + léger glissé, avec un écran de
/// redirection « Accès autorisé » le temps de charger l'espace conducteur.
class ProRoot extends StatelessWidget {
  const ProRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    Widget keyed(String k, Widget child) =>
        KeyedSubtree(key: ValueKey(k), child: child);

    Widget destination;
    if (auth.loading) {
      destination = keyed('boot', const _ProSplash());
    } else if (!auth.isSignedIn) {
      destination = keyed('login', const ProLoginScreen());
    } else {
      final driver = context.watch<DriverService>();
      if (driver.loading) {
        // Connexion / inscription validée : on charge l'espace conducteur.
        destination = keyed(
          'redirect',
          const _ProSplash(message: 'Accès autorisé', success: true),
        );
      } else if (driver.isDriver) {
        destination = keyed('driver', const DriverShell());
      } else if (driver.hasPendingAccess) {
        destination = keyed('pending', const DriverPendingScreen());
      } else {
        switch (auth.role) {
          case AppUserRole.msrAgent:
            destination = keyed('msr', const MsrShell());
            break;
          default:
            destination = keyed(
              'denied',
              const _ProPlaceholder(
                title: 'Accès refusé',
                message: 'Ce compte n\'est pas autorisé sur Aule Pro.',
                showSignOut: true,
              ),
            );
        }
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 480),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: destination,
    );
  }
}

/// Écran de démarrage / redirection animé (logo Aule Pro pulsé).
///
/// Sert à la fois pour le boot initial et pour la bascule « connexion réussie
/// → accueil », afin que la redirection paraisse intentionnelle plutôt qu'un
/// simple clignotement.
class _ProSplash extends StatefulWidget {
  final String? message;
  final bool success;

  const _ProSplash({this.message, this.success = false});

  @override
  State<_ProSplash> createState() => _ProSplashState();
}

class _ProSplashState extends State<_ProSplash>
    with TickerProviderStateMixin {
  static const _sage = Color(0xFF9FC8A9);
  static const _forest = Color(0xFF5E8B7E);
  static const _ink = Color(0xFF14241C);

  late final AnimationController _pulse;
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2EC),
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _intro, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: _intro, curve: Curves.easeOutBack),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final t = Curves.easeInOut.transform(_pulse.value);
                    return Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_sage, _forest],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: _forest.withValues(alpha: 0.28 + 0.26 * t),
                            blurRadius: 20 + 20 * t,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.success
                            ? LucideIcons.circleCheck
                            : LucideIcons.busFront,
                        color: Colors.white,
                        size: 38,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Aule Pro',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: _forest,
                  ),
                ),
                if (widget.message != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    widget.message!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _forest,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProPlaceholder extends StatelessWidget {
  final String title;
  final String message;
  final bool showSignOut;

  const _ProPlaceholder({
    required this.title,
    required this.message,
    this.showSignOut = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(message, textAlign: TextAlign.center),
            ),
            if (showSignOut)
              TextButton(
                onPressed: () => context.read<AuthService>().signOut(),
                child: const Text('Se déconnecter'),
              ),
          ],
        ),
      ),
    );
  }
}
