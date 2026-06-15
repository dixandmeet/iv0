import 'package:flutter/material.dart';

/// Icône barres de signal temps réel (style maquette).
class RealtimeSignal extends StatelessWidget {
  final Color color;
  final bool muted;

  const RealtimeSignal({
    super.key,
    required this.color,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = muted ? color.withValues(alpha: 0.35) : color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(4, c),
        const SizedBox(width: 1.5),
        _bar(7, c),
        const SizedBox(width: 1.5),
        _bar(10, c),
      ],
    );
  }

  Widget _bar(double h, Color c) => Container(
        width: 2,
        height: h,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(1),
        ),
      );
}
