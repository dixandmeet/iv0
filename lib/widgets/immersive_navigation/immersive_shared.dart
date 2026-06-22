import 'dart:ui';

import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/premium_navigation_theme.dart';

/// Barre flottante supérieure : retour, badge ligne, direction, favori.
class ImmersiveTopBar extends StatelessWidget {
  final String lineCode;
  final Color lineColor;
  final String direction;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onFavorite;
  final bool lightIcons;

  const ImmersiveTopBar({
    super.key,
    required this.lineCode,
    required this.lineColor,
    required this.direction,
    required this.isFavorite,
    required this.onBack,
    required this.onFavorite,
    this.lightIcons = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _CircleBtn(
            icon: LucideIcons.arrowLeft,
            onTap: onBack,
            light: lightIcons,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: PremiumNavTheme.surface.withValues(alpha: 0.94),
                    boxShadow: PremiumNavTheme.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: lineColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.tramFront,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lineCode,
                              style: hankenGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          direction,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: PremiumNavTheme.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CircleBtn(
            icon: LucideIcons.star,
            onTap: onFavorite,
            filled: isFavorite,
            light: lightIcons,
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final bool light;

  const _CircleBtn({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: light
          ? Colors.black.withValues(alpha: 0.25)
          : PremiumNavTheme.surface.withValues(alpha: 0.94),
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 20,
            color: filled
                ? const Color(0xFFF59E0B)
                : light
                    ? Colors.white
                    : PremiumNavTheme.text,
            fill: filled ? 1.0 : 0.0,
          ),
        ),
      ),
    );
  }
}

/// Carte flottante ETA « En approche · 55 s ».
class ImmersiveEtaCard extends StatelessWidget {
  final int remainingSeconds;
  final bool isApproaching;

  const ImmersiveEtaCard({
    super.key,
    required this.remainingSeconds,
    required this.isApproaching,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PremiumNavTheme.radiusSm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: PremiumNavTheme.surface.withValues(alpha: 0.95),
            boxShadow: PremiumNavTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isApproaching)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PremiumNavTheme.warnBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'En approche',
                    style: hankenGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: PremiumNavTheme.warn,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    remainingSeconds <= 0 ? '0' : '$remainingSeconds',
                    style: hankenGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: PremiumNavTheme.text,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    's',
                    style: hankenGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PremiumNavTheme.muted,
                    ),
                  ),
                ],
              ),
              Text(
                'Arrive dans',
                style: hankenGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: PremiumNavTheme.faint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau de manœuvre style GPS : prochain arrêt + distance restante.
class ImmersiveManeuverCard extends StatelessWidget {
  final String stopName;
  final int distanceMeters;

  const ImmersiveManeuverCard({
    super.key,
    required this.stopName,
    required this.distanceMeters,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PremiumNavTheme.radiusSm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PremiumNavTheme.surface.withValues(alpha: 0.95),
            boxShadow: PremiumNavTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PremiumNavTheme.brand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.mapPin,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Arrêt $stopName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: hankenGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: PremiumNavTheme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dans $distanceMeters m',
                      style: hankenGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: PremiumNavTheme.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panneau inférieur blanc avec infos, toggle alertes et CTA.
class ImmersiveBottomPanel extends StatelessWidget {
  final String nextStop;
  final String estimatedArrival;
  final String destinationInfo;
  final bool alertsEnabled;
  final bool isArrived;
  final int waitMinutes;
  final VoidCallback onToggleAlerts;
  final VoidCallback onBoard;
  final String? primaryLabel;
  final String? primarySubtitle;

  const ImmersiveBottomPanel({
    super.key,
    required this.nextStop,
    required this.estimatedArrival,
    required this.destinationInfo,
    required this.alertsEnabled,
    required this.isArrived,
    required this.waitMinutes,
    required this.onToggleAlerts,
    required this.onBoard,
    this.primaryLabel,
    this.primarySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(PremiumNavTheme.radiusLg),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12 + bottom),
          decoration: BoxDecoration(
            color: PremiumNavTheme.surface.withValues(alpha: 0.97),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoRow(label: 'Prochain arrêt', value: nextStop),
              _InfoRow(label: 'Arrivée estimée', value: estimatedArrival),
              _InfoRow(label: 'Destination', value: destinationInfo),
              const SizedBox(height: 8),
              _AlertToggle(enabled: alertsEnabled, onChanged: onToggleAlerts),
              const SizedBox(height: 12),
              _PrimaryButton(
                label: primaryLabel ??
                    (isArrived ? 'Montez maintenant' : 'Je monte dans ce tram'),
                subtitle: primarySubtitle ??
                    (isArrived
                        ? null
                        : 'Disponible dans ~${waitMinutes.clamp(1, 99)} min'),
                onTap: onBoard,
                pulse: isArrived,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: hankenGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PremiumNavTheme.muted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: hankenGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: PremiumNavTheme.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onChanged;

  const _AlertToggle({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? PremiumNavTheme.brandLight : PremiumNavTheme.bg,
        borderRadius: BorderRadius.circular(PremiumNavTheme.radiusSm),
        border: Border.all(
          color: enabled
              ? PremiumNavTheme.brand.withValues(alpha: 0.3)
              : const Color(0xFFE7EAF0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? LucideIcons.bellRing : LucideIcons.bell,
            size: 18,
            color: enabled ? PremiumNavTheme.brand : PremiumNavTheme.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Alertes d\'approche',
              style: hankenGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: PremiumNavTheme.text,
              ),
            ),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: (_) => onChanged(),
            activeTrackColor: PremiumNavTheme.brand.withValues(alpha: 0.45),
            activeThumbColor: PremiumNavTheme.brand,
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool pulse;

  const _PrimaryButton({
    required this.label,
    this.subtitle,
    required this.onTap,
    this.pulse = false,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _sync();
  }

  @override
  void didUpdateWidget(_PrimaryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.pulse) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final scale = widget.pulse ? 1.0 + _ctrl.value * 0.02 : 1.0;
        return Transform.scale(
          scale: scale,
          child: Material(
            color: PremiumNavTheme.brand,
            elevation: 6,
            shadowColor: PremiumNavTheme.brand.withValues(
              alpha: 0.3 + _ctrl.value * 0.15,
            ),
            borderRadius: BorderRadius.circular(PremiumNavTheme.radiusMd),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(PremiumNavTheme.radiusMd),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: hankenGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: hankenGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compteur grand format pour l'arrivée imminente.
class ImmersiveArrivalCountdown extends StatelessWidget {
  final int seconds;

  const ImmersiveArrivalCountdown({super.key, required this.seconds});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            color: PremiumNavTheme.surface.withValues(alpha: 0.95),
            boxShadow: PremiumNavTheme.cardShadow,
          ),
          child: Column(
            children: [
              Text(
                '${seconds.clamp(0, 99)}',
                style: hankenGrotesk(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: PremiumNavTheme.brand,
                  height: 1,
                ),
              ),
              Text(
                'Arrive dans',
                style: hankenGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PremiumNavTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte d'alerte « Préparez-vous à monter ».
class ImmersivePrepareCard extends StatelessWidget {
  const ImmersivePrepareCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: PremiumNavTheme.warnBg,
        borderRadius: BorderRadius.circular(PremiumNavTheme.radiusSm),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Text(
        'Préparez-vous à monter',
        textAlign: TextAlign.center,
        style: hankenGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: PremiumNavTheme.warn,
        ),
      ),
    );
  }
}

/// Overlay alerte de descente (écran 6).
class DisembarkAlertOverlay extends StatelessWidget {
  final VoidCallback onDisembark;

  const DisembarkAlertOverlay({super.key, required this.onDisembark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PremiumNavTheme.overlay,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: PremiumNavTheme.brand,
                    shape: BoxShape.circle,
                    boxShadow: PremiumNavTheme.brandGlow,
                  ),
                  child: const Icon(
                    LucideIcons.bell,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Descente dans 1 arrêt',
                  textAlign: TextAlign.center,
                  style: hankenGrotesk(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Préparez-vous à descendre',
                  style: hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: PremiumNavTheme.brand,
                    borderRadius:
                        BorderRadius.circular(PremiumNavTheme.radiusMd),
                    elevation: 8,
                    shadowColor: PremiumNavTheme.brand.withValues(alpha: 0.4),
                    child: InkWell(
                      onTap: onDisembark,
                      borderRadius:
                          BorderRadius.circular(PremiumNavTheme.radiusMd),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Je suis descendu',
                          textAlign: TextAlign.center,
                          style: hankenGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre de progression des arrêts pendant le trajet.
class TripProgressBar extends StatelessWidget {
  final int currentIndex;
  final int totalStops;

  const TripProgressBar({
    super.key,
    required this.currentIndex,
    required this.totalStops,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalStops, (i) {
        final done = i <= currentIndex;
        final current = i == currentIndex;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 6,
            decoration: BoxDecoration(
              color: done ? PremiumNavTheme.brand : const Color(0xFFE7EAF0),
              borderRadius: BorderRadius.circular(3),
              boxShadow: current
                  ? [
                      BoxShadow(
                        color: PremiumNavTheme.brand.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

/// Liste des arrêts suivants pendant le trajet.
class TripStopsList extends StatelessWidget {
  final List<(String name, String time)> stops;

  const TripStopsList({super.key, required this.stops});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: PremiumNavTheme.surface,
        borderRadius: BorderRadius.circular(PremiumNavTheme.radiusLg),
        boxShadow: PremiumNavTheme.cardShadow,
      ),
      child: Column(
        children: stops.map((s) {
          final isNext = stops.indexOf(s) == 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isNext
                        ? PremiumNavTheme.brand
                        : PremiumNavTheme.faint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.$1,
                    style: hankenGrotesk(
                      fontSize: 14,
                      fontWeight:
                          isNext ? FontWeight.w800 : FontWeight.w600,
                      color: isNext
                          ? PremiumNavTheme.text
                          : PremiumNavTheme.muted,
                    ),
                  ),
                ),
                Text(
                  s.$2,
                  style: hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PremiumNavTheme.faint,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
