import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/driver/driver_persona_icon.dart';
import '../../models/driver/terrain_user_marker_style.dart';
import '../../theme/driver_home_palette.dart';

/// Types d'objets localisables sur la carte Terrain.
enum TerrainMarkerType { bus, tram, controle, msr, incident, assistance, arret }

extension TerrainMarkerTypeX on TerrainMarkerType {
  Color get color => switch (this) {
    TerrainMarkerType.bus => DriverHomePalette.primary,
    TerrainMarkerType.tram => DriverHomePalette.purple,
    TerrainMarkerType.controle => DriverHomePalette.blue,
    TerrainMarkerType.msr => DriverHomePalette.warning,
    TerrainMarkerType.incident => DriverHomePalette.danger,
    TerrainMarkerType.assistance => const Color(0xFF94A3B8),
    TerrainMarkerType.arret => DriverHomePalette.textSecondary,
  };

  IconData get icon => switch (this) {
    TerrainMarkerType.bus => LucideIcons.bus,
    TerrainMarkerType.tram => LucideIcons.trainFront,
    TerrainMarkerType.controle => LucideIcons.shieldCheck,
    TerrainMarkerType.msr => LucideIcons.users,
    TerrainMarkerType.incident => LucideIcons.triangleAlert,
    TerrainMarkerType.assistance => LucideIcons.lifeBuoy,
    TerrainMarkerType.arret => LucideIcons.mapPin,
  };

  String get label => switch (this) {
    TerrainMarkerType.bus => 'Bus',
    TerrainMarkerType.tram => 'Tram',
    TerrainMarkerType.controle => 'Contrôle',
    TerrainMarkerType.msr => 'MSR',
    TerrainMarkerType.incident => 'Incident',
    TerrainMarkerType.assistance => 'Assistance',
    TerrainMarkerType.arret => 'Arrêt',
  };

  bool get isLight => this == TerrainMarkerType.assistance;
}

/// Marqueur Terrain : bus/tram dessiné vu du dessus et orienté selon le cap
/// (avec badge ligne), pastille ronde pour les agents et incidents.
class TerrainMapMarker extends StatefulWidget {
  final TerrainMarkerType type;
  final bool selected;
  final bool stale;
  final bool outOfService;
  final double headingDeg;
  final String? lineLabel;
  final double liveOpacity;
  final VoidCallback? onTap;

  const TerrainMapMarker({
    super.key,
    required this.type,
    this.selected = false,
    this.stale = false,
    this.outOfService = false,
    this.headingDeg = 0,
    this.lineLabel,
    this.liveOpacity = 1,
    this.onTap,
  });

  @override
  State<TerrainMapMarker> createState() => _TerrainMapMarkerState();
}

class _TerrainMapMarkerState extends State<TerrainMapMarker>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _micro;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    _micro = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    if (widget.selected) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant TerrainMapMarker old) {
    super.didUpdateWidget(old);
    if (widget.selected && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!widget.selected && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _micro.dispose();
    super.dispose();
  }

  static const _greyscale = <double>[
    0.33,
    0.33,
    0.33,
    0,
    0,
    0.33,
    0.33,
    0.33,
    0,
    0,
    0.33,
    0.33,
    0.33,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  bool get _usesTopDownAsset =>
      widget.type == TerrainMarkerType.bus ||
      widget.type == TerrainMarkerType.tram ||
      widget.type == TerrainMarkerType.controle;

  @override
  Widget build(BuildContext context) {
    final accent = widget.type.color;
    final scale = widget.selected ? 1.18 : 1.0;

    Widget marker = AnimatedBuilder(
      animation: _micro,
      builder: (_, child) {
        final micro = 1 + _micro.value * 0.035;
        return Transform.scale(scale: scale * micro, child: child);
      },
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (widget.selected) _selectionPulse(accent),
          _usesTopDownAsset ? _topDownCore(accent) : _agentBubble(accent),
        ],
      ),
    );

    if (widget.stale || widget.outOfService) {
      marker = Opacity(
        opacity: widget.outOfService ? 0.5 : 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(_greyscale),
          child: marker,
        ),
      );
    }

    if (widget.stale) {
      marker = Stack(
        clipBehavior: Clip.none,
        children: [
          marker,
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0.5, -0.5),
              child: Icon(
                LucideIcons.signalZero,
                size: 14,
                color: DriverHomePalette.warning,
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: widget.liveOpacity),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (context, t, child) {
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
          );
        },
        child: RepaintBoundary(child: marker),
      ),
    );
  }

  static const _busAsset = 'assets/images/bus_top.png';
  static const _tramAsset = 'assets/images/tram_top.png';
  static const _controleAsset = 'assets/images/controle_top.png';

  String get _topDownAsset => switch (widget.type) {
        TerrainMarkerType.tram => _tramAsset,
        TerrainMarkerType.controle => _controleAsset,
        _ => _busAsset,
      };

  // Le tram est ~2× plus long que le bus ; contrôle légèrement plus compact.
  double get _topDownHeight => switch (widget.type) {
        TerrainMarkerType.tram => 148.0,
        TerrainMarkerType.controle => 68.0,
        _ => 74.0,
      };

  double get _topDownHaloD => switch (widget.type) {
        TerrainMarkerType.tram => 100.0,
        TerrainMarkerType.controle => 58.0,
        _ => 64.0,
      };

  /// Anneau de sélection qui pulse, à la couleur du type.
  Widget _selectionPulse(Color accent) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) {
        final t = _pulse.value;
        return Container(
          width: 60 + 42 * t,
          height: 60 + 42 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.26 * (1 - t)),
          ),
        );
      },
    );
  }

  /// Bus/tram/contrôle (image vue du dessus) orienté selon le cap (avant = haut au cap 0),
  /// posé sur un halo coloré + ombre portée, avec badge ligne attaché.
  Widget _topDownCore(Color accent) {
    final angle = widget.headingDeg * math.pi / 180;
    final h = _topDownHeight;
    final haloD = _topDownHaloD;

    Image img({Color? tint, BlendMode? mode}) => Image.asset(
      _topDownAsset,
      height: _topDownHeight,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      color: tint,
      colorBlendMode: mode,
      errorBuilder: (_, _, _) => _agentBubble(accent),
    );

    final shadow = Transform.translate(
      offset: const Offset(0, 3.5),
      child: Transform.rotate(
        angle: angle,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 2.6, sigmaY: 2.6),
          child: img(
            tint: Colors.black.withValues(alpha: 0.45),
            mode: BlendMode.srcIn,
          ),
        ),
      ),
    );

    final vehicle = Transform.rotate(angle: angle, child: img());

    final halo = AnimatedBuilder(
      animation: _micro,
      builder: (_, _) {
        final s = 1 + _micro.value * 0.06;
        return Container(
          width: haloD * s,
          height: haloD * s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                accent.withValues(alpha: 0.42),
                accent.withValues(alpha: 0.16),
                accent.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );

    final label = widget.lineLabel;
    final side = h + 24;

    return SizedBox(
      width: side,
      height: side + 6,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Center(child: halo),
          Center(child: shadow),
          Center(child: vehicle),
          if (label != null && label.isNotEmpty)
            Positioned(bottom: 4, child: _lineBadge(accent, label)),
        ],
      ),
    );
  }

  String get _lineBadgePrefix => switch (widget.type) {
        TerrainMarkerType.tram => 'T',
        TerrainMarkerType.controle => 'C',
        _ => 'B',
      };

  Widget _lineBadge(Color accent, String label) {
    final selected = widget.selected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: selected ? accent : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: selected ? 0.45 : 0.25),
            blurRadius: selected ? 9 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$_lineBadgePrefix $label',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? Colors.white : accent,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          height: 1.0,
        ),
      ),
    );
  }

  /// Pastille ronde pour les marqueurs non-véhicule (agents, incidents…).
  Widget _agentBubble(Color accent) {
    final light = widget.type.isLight;
    final size = widget.selected ? 40.0 : 36.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: light ? Colors.white : accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        widget.type.icon,
        size: size * 0.48,
        color: light ? accent : Colors.white,
      ),
    );
  }
}

/// Cluster premium avec icône + compteur ou ligne dominante.
class TerrainClusterMarker extends StatelessWidget {
  final int count;
  final TerrainMarkerType? type;
  final String? lineLabel;
  final VoidCallback? onTap;
  final double zoomTier;

  const TerrainClusterMarker({
    super.key,
    required this.count,
    this.type,
    this.lineLabel,
    this.onTap,
    this.zoomTier = 0,
  });

  @override
  Widget build(BuildContext context) {
    final accent = type?.color ?? DriverHomePalette.primary;
    final showLine = lineLabel != null && lineLabel!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A101A14),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: showLine
              ? Text(
                  lineLabel!.length > 6
                      ? lineLabel!.substring(0, 6)
                      : lineLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                )
              : Text(
                  _clusterLabel(type, count),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
        ),
      ),
    );
  }

  static String _clusterLabel(TerrainMarkerType? type, int count) {
    final n = count > 99 ? '99+' : '$count';
    return switch (type) {
      TerrainMarkerType.bus => 'B·$n',
      TerrainMarkerType.tram => 'T·$n',
      TerrainMarkerType.controle => 'C·$n',
      TerrainMarkerType.msr => 'M·$n',
      _ => n,
    };
  }
}

enum TerrainStopKind { bus, tram, both }

class TerrainStopDot extends StatelessWidget {
  final TerrainStopKind kind;
  final bool selected;

  const TerrainStopDot({
    super.key,
    this.kind = TerrainStopKind.bus,
    this.selected = false,
  });

  Color get _accent => switch (kind) {
    TerrainStopKind.bus => DriverHomePalette.primary,
    TerrainStopKind.tram => DriverHomePalette.blue,
    TerrainStopKind.both => DriverHomePalette.purple,
  };

  @override
  Widget build(BuildContext context) {
    final size = selected ? 16.0 : 12.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _accent, width: selected ? 2.4 : 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        kind == TerrainStopKind.tram
            ? LucideIcons.trainFront
            : LucideIcons.mapPin,
        size: size * 0.55,
        color: _accent,
      ),
    );
  }
}

class TerrainStopCluster extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const TerrainStopCluster({super.key, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: DriverHomePalette.textSecondary.withValues(alpha: 0.45),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A101A14),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: DriverHomePalette.textDark,
          ),
        ),
      ),
    );
  }
}

/// Position utilisateur style Google Maps.
class TerrainUserDot extends StatefulWidget {
  final double? accuracyMeters;

  const TerrainUserDot({super.key, this.accuracyMeters});

  @override
  State<TerrainUserDot> createState() => _TerrainUserDotState();
}

class _TerrainUserDotState extends State<TerrainUserDot>
    with TickerProviderStateMixin {
  late final AnimationController _pulse1;
  late final AnimationController _pulse2;

  @override
  void initState() {
    super.initState();
    _pulse1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _pulse2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse1.dispose();
    _pulse2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = widget.accuracyMeters ?? 40;
    final radius = (accuracy / 8).clamp(18.0, 48.0);

    return RepaintBoundary(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DriverHomePalette.blue.withValues(alpha: 0.12),
              ),
            ),
            _halo(_pulse1, 0.28),
            _halo(_pulse2, 0.18),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: DriverHomePalette.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: DriverHomePalette.blue.withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _halo(AnimationController ctrl, double maxAlpha) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, _) {
        final t = ctrl.value;
        return Container(
          width: 20 + 28 * t,
          height: 20 + 28 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DriverHomePalette.blue.withValues(alpha: maxAlpha * (1 - t)),
          ),
        );
      },
    );
  }
}

/// Icône contrôleur vu du dessus, orientée selon le cap GPS.
class TerrainControllerIcon extends StatefulWidget {
  static const controllerHommeAsset = DriverPersonaIcon.controleurHomme;
  static const controllerFemmeAsset = DriverPersonaIcon.controleurFemme;
  static const driverHommeAsset = DriverPersonaIcon.conducteurHomme;

  final String asset;
  final double headingDeg;

  const TerrainControllerIcon({
    super.key,
    required this.asset,
    this.headingDeg = 0,
  });

  static const _height = 56.0;
  static const _haloD = 56.0;
  static const markerWidth = 72.0;
  static const markerHeight = 84.0;

  @override
  State<TerrainControllerIcon> createState() => _TerrainControllerIconState();
}

class _TerrainControllerIconState extends State<TerrainControllerIcon>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _haloPulse;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _haloPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _breath.dispose();
    _haloPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final angle = widget.headingDeg * math.pi / 180;
    final accent = DriverHomePalette.blue;

    Image img({Color? tint, BlendMode? mode}) => Image.asset(
      widget.asset,
      height: TerrainControllerIcon._height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      color: tint,
      colorBlendMode: mode,
      errorBuilder: (_, _, _) => const TerrainUserDot(),
    );

    final character = Transform.rotate(angle: angle, child: img());

    final shadow = Transform.translate(
      offset: const Offset(0, 2.5),
      child: Transform.rotate(
        angle: angle,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
          child: img(
            tint: Colors.black.withValues(alpha: 0.35),
            mode: BlendMode.srcIn,
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: SizedBox(
        width: TerrainControllerIcon.markerWidth,
        height: TerrainControllerIcon.markerHeight,
        child: AnimatedBuilder(
          animation: Listenable.merge([_breath, _haloPulse]),
          builder: (_, _) {
            final breath = 1 + _breath.value * 0.04;
            final haloScale = 1 + _breath.value * 0.08;
            final pulseT = _haloPulse.value;

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Transform.scale(
                  scale: haloScale,
                  child: Container(
                    width: TerrainControllerIcon._haloD,
                    height: TerrainControllerIcon._haloD,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: 0.34),
                          accent.withValues(alpha: 0.13),
                          accent.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                _haloRing(pulseT, 0.24),
                _haloRing((pulseT + 0.45) % 1.0, 0.16),
                Transform.scale(
                  scale: breath,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [shadow, character],
                  ),
                ),
                Positioned(bottom: 0, child: _selfLegendBadge(accent)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _selfLegendBadge(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'Vous',
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          height: 1.0,
        ),
      ),
    );
  }

  Widget _haloRing(double t, double maxAlpha) {
    final accent = DriverHomePalette.blue;
    return Container(
      width: 18 + 30 * t,
      height: 18 + 30 * t,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: maxAlpha * (1 - t)),
      ),
    );
  }
}

/// Marqueur de position utilisateur : point bleu ou icône contrôleur selon le contexte.
class TerrainUserMarker extends StatelessWidget {
  final TerrainUserMarkerStyle style;
  final double? accuracyMeters;
  final double headingDeg;

  const TerrainUserMarker({
    super.key,
    required this.style,
    this.accuracyMeters,
    this.headingDeg = 0,
  });

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      TerrainUserMarkerStyle.driverHomme => TerrainControllerIcon(
        asset: TerrainControllerIcon.driverHommeAsset,
        headingDeg: headingDeg,
      ),
      TerrainUserMarkerStyle.controllerHomme => TerrainControllerIcon(
        asset: TerrainControllerIcon.controllerHommeAsset,
        headingDeg: headingDeg,
      ),
      TerrainUserMarkerStyle.controllerFemme => TerrainControllerIcon(
        asset: TerrainControllerIcon.controllerFemmeAsset,
        headingDeg: headingDeg,
      ),
      _ => TerrainUserDot(accuracyMeters: accuracyMeters),
    };
  }
}

/// Pastille station voyageur importante.
class TerrainStationMarker extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;

  const TerrainStationMarker({super.key, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: selected ? 22 : 18,
        height: selected ? 22 : 18,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: DriverHomePalette.blue,
            width: selected ? 2.6 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(
          LucideIcons.trainFront,
          size: 10,
          color: DriverHomePalette.blue,
        ),
      ),
    );
  }
}
