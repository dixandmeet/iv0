import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AgentRole { conducteur, controle }

enum AccountModes { mixte, conducteur, controle }

class HomeScreen extends StatelessWidget {
  final AccountModes accountModes;
  final AgentRole role;
  final bool serviceActive;
  final String serviceLabel;
  final ValueChanged<AgentRole> onPickRole;
  final VoidCallback onPriseService;
  final VoidCallback onGuidage;
  final VoidCallback onActivateRadar;

  const HomeScreen({
    super.key,
    required this.accountModes,
    required this.role,
    required this.serviceActive,
    required this.serviceLabel,
    required this.onPickRole,
    required this.onPriseService,
    required this.onGuidage,
    required this.onActivateRadar,
  });

  bool get _isMixte => accountModes == AccountModes.mixte;
  bool get _isCond => _isMixte
      ? role == AgentRole.conducteur
      : accountModes == AccountModes.conducteur;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.08),
            radius: 0.78,
            colors: [AppColors.bgGlow, AppColors.bg],
            stops: [0, 0.72],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bonjour,',
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Agent Naolib',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 18),
                if (_isMixte)
                  _RoleSwitch(cond: _isCond, onPickRole: onPickRole),
                if (!_isMixte)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.09),
                      ),
                    ),
                    child: Text(
                      accountModes == AccountModes.conducteur
                          ? 'Espace Conducteur'
                          : 'Espace MSR',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                if (_isCond && !serviceActive)
                  _HomeCard(
                    icon: Icons.directions_bus_filled_rounded,
                    title: 'Aucun service en cours',
                    subtitle:
                        'Choisissez votre ligne et votre sens pour démarrer.',
                    ctaLabel: 'Prendre mon service',
                    onTap: onPriseService,
                  ),
                if (_isCond && serviceActive)
                  _HomeCard(
                    icon: Icons.directions_bus_filled_rounded,
                    eyebrow: 'Service en cours',
                    title: serviceLabel,
                    subtitle: 'Position transmise en continu',
                    ctaLabel: 'Ouvrir le guidage',
                    onTap: onGuidage,
                  ),
                if (!_isCond)
                  _HomeCard(
                    icon: Icons.radar_rounded,
                    title: 'Radar désactivé',
                    subtitle:
                        "Bus, trams et Navibus réels à proximité, avec leur temps d'arrivée.",
                    ctaLabel: 'Activer le Radar',
                    onTap: onActivateRadar,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSwitch extends StatelessWidget {
  final bool cond;
  final ValueChanged<AgentRole> onPickRole;
  const _RoleSwitch({required this.cond, required this.onPickRole});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RolePill(
              icon: Icons.directions_bus_filled_rounded,
              label: 'Conducteur',
              active: cond,
              onTap: () => onPickRole(AgentRole.conducteur),
            ),
          ),
          Expanded(
            child: _RolePill(
              icon: Icons.shield_rounded,
              label: 'MSR',
              active: !cond,
              onTap: () => onPickRole(AgentRole.controle),
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RolePill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: active ? AppColors.accentDark : Colors.white60,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.accentDark : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String? eyebrow;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2620), Color(0xFF0A1A16)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Row(
              children: [
                const _PulseDot(),
                const SizedBox(width: 6),
                Text(
                  eyebrow!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.white60),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(icon, size: 26, color: AppColors.accent),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white60,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.accentDark,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                elevation: 0,
              ),
              child: Text(
                ctaLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final ringOpacity = t < 0.7 ? (1 - t / 0.7) * 0.5 : 0.0;
        final ringScale = 1 + (t.clamp(0, 0.7) / 0.7) * 2.2;
        return SizedBox(
          width: 16,
          height: 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: ringOpacity),
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
