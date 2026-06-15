import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/aule_theme.dart';

/// Carte « État du réseau » avec barre de progression.
class NetworkStatus extends StatelessWidget {
  final int percent;
  final int disruptions;

  const NetworkStatus({
    super.key,
    required this.percent,
    required this.disruptions,
  });

  @override
  Widget build(BuildContext context) {
    final c = AuleTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(AuleTokens.rCard),
        boxShadow: AuleTokens.cardShadow(c.shadow),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: c.ok,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: c.okBg,
                          blurRadius: 0,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    'Réseau fluide',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: c.text,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$percent',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        height: 1,
                        color: c.ok,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    TextSpan(
                      text: '%',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.ok,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: c.surface2,
              valueColor: AlwaysStoppedAnimation(c.ok),
            ),
          ),
          const SizedBox(height: 11),
          RichText(
            text: TextSpan(
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.muted,
              ),
              children: [
                const TextSpan(
                    text: 'des lignes circulent normalement · '),
                TextSpan(
                  text: '$disruptions perturbations',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.warn,
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
