import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Panneau d'actions en bas de l'écran véhicule.
class VehicleActionButtons extends StatelessWidget {
  final Color lineColor;
  final bool notificationsEnabled;
  final bool isArrived;
  final bool isBoarded;
  final int waitMinutes;
  final VoidCallback onToggleNotifications;
  final VoidCallback onBoard;
  final VoidCallback onShare;

  const VehicleActionButtons({
    super.key,
    required this.lineColor,
    required this.notificationsEnabled,
    this.isArrived = false,
    this.isBoarded = false,
    this.waitMinutes = 0,
    required this.onToggleNotifications,
    required this.onBoard,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 28,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00F6F7FB), Color(0xFFF6F7FB)],
            ),
          ),
        ),
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                border: Border(
                  top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isBoarded && !isArrived)
                    _NotificationRow(
                      enabled: notificationsEnabled,
                      onChanged: (_) => onToggleNotifications(),
                    ),
                  if (!isBoarded) ...[
                    const SizedBox(height: 10),
                    _PrimaryBoardButton(
                      lineColor: lineColor,
                      isArrived: isArrived,
                      waitMinutes: waitMinutes,
                      onTap: onBoard,
                    ),
                  ],
                  if (!isBoarded && !isArrived) ...[
                    const SizedBox(height: 10),
                    _ShareButton(onTap: onShare),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _NotificationRow({
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? const Color(0xFF16A34A).withValues(alpha: 0.08)
            : const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled
              ? const Color(0xFF16A34A).withValues(alpha: 0.25)
              : const Color(0xFFE7EAF0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled ? LucideIcons.bellRing : LucideIcons.bell,
            size: 18,
            color: enabled
                ? const Color(0xFF16A34A)
                : const Color(0xFF5B6677),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled
                      ? 'Alertes d\'approche actives'
                      : 'Alertes d\'approche',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0B1220),
                  ),
                ),
                Text(
                  enabled
                      ? 'Prévenu à moins d\'1 min'
                      : 'Soyez prévenu avant l\'arrivée',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF9AA4B2),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF16A34A).withValues(alpha: 0.45),
            activeThumbColor: const Color(0xFF16A34A),
          ),
        ],
      ),
    );
  }
}

class _PrimaryBoardButton extends StatefulWidget {
  final Color lineColor;
  final bool isArrived;
  final int waitMinutes;
  final VoidCallback onTap;

  const _PrimaryBoardButton({
    required this.lineColor,
    required this.isArrived,
    required this.waitMinutes,
    required this.onTap,
  });

  @override
  State<_PrimaryBoardButton> createState() => _PrimaryBoardButtonState();
}

class _PrimaryBoardButtonState extends State<_PrimaryBoardButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(_PrimaryBoardButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isArrived != widget.isArrived) _syncPulse();
  }

  void _syncPulse() {
    if (widget.isArrived) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isArrived
        ? 'Montez maintenant'
        : 'Je monte dans ce tram';
    final subtitle = widget.isArrived
        ? null
        : 'Disponible dans ~${widget.waitMinutes} min';

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final scale = widget.isArrived ? 1.0 + _pulse.value * 0.025 : 1.0;
        final glow = widget.isArrived ? 0.25 + _pulse.value * 0.2 : 0.18;

        return Transform.scale(
          scale: scale,
          child: Material(
            color: widget.lineColor,
            elevation: 8,
            shadowColor: widget.lineColor.withValues(alpha: glow),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.hankenGrotesk(
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

class _ShareButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ShareButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F5F8),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.share2,
                size: 16,
                color: Color(0xFF5B6677),
              ),
              const SizedBox(width: 8),
              Text(
                'Partager mon trajet',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5B6677),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
