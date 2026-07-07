import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../models/driver/driver_onboarding_data.dart';
import '../../../../theme/driver_home_palette.dart';

/// Dernier écran — Confirmation. Récapitulatif complet et adaptatif selon le
/// profil choisi.
class ConfirmationStep extends StatelessWidget {
  final DriverOnboardingData data;

  const ConfirmationStep({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: DriverHomePalette.lightGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: DriverHomePalette.primary.withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.circleCheck,
                color: DriverHomePalette.primary,
                size: 54,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Votre profil est prêt !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: DriverHomePalette.textDark,
              height: 1.2,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vérifiez votre configuration avant de commencer.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: DriverHomePalette.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ..._rows(),
        ],
      ),
    );
  }

  List<Widget> _rows() {
    final rows = <Widget>[];

    void add(Widget card) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 12));
      rows.add(card);
    }

    if (data.profile != null) {
      add(_SummaryCard(
        label: 'Activité',
        value: data.profile!.label,
        emoji: data.profile!.emoji,
      ));
    }

    switch (data.profile) {
      case ProProfile.reseau:
        if (data.network != null) {
          add(_SummaryCard(
            label: 'Réseau',
            value: data.network!.label,
            emoji: '🚌',
          ));
        }
        if (data.depot != null) {
          add(_SummaryCard(
            label: 'Dépôt',
            value: data.depot!.label,
            emoji: '🏠',
          ));
        }
        if (data.gender != null) {
          add(_SummaryCard(
            label: 'Genre',
            value: data.gender!.label,
            emoji: data.gender!.emoji,
          ));
        }
        if (data.habilitations.isNotEmpty) {
          add(_MultiSummaryCard(
            label: 'Habilitations',
            emoji: '🏷️',
            values: [
              for (final h in DriverHabilitation.values)
                if (data.habilitations.contains(h)) h.label,
            ],
          ));
        }
      case ProProfile.vtc:
        if (data.gender != null) {
          add(_SummaryCard(
            label: 'Genre',
            value: data.gender!.label,
            emoji: data.gender!.emoji,
          ));
        }
        if (data.vtcActivity != null) {
          add(_SummaryCard(
            label: "Type d'activité",
            value: data.vtcActivity!.label,
            emoji: data.vtcActivity!.emoji,
          ));
        }
        if (data.zone != null) {
          add(_SummaryCard(
            label: "Zone d'activité",
            value: data.zone!.label,
            emoji: '📍',
          ));
        }
      case ProProfile.commercant:
        if (data.merchantType != null) {
          add(_SummaryCard(
            label: 'Type de commerce',
            value: data.merchantType!.label,
            emoji: data.merchantType!.emoji,
          ));
        }
        if (data.merchantName.trim().isNotEmpty) {
          add(_SummaryCard(
            label: 'Établissement',
            value: data.merchantName.trim(),
            emoji: '🏪',
          ));
        }
        if (data.merchantAddress.trim().isNotEmpty) {
          add(_SummaryCard(
            label: 'Adresse',
            value: data.merchantAddress.trim(),
            emoji: '📍',
          ));
        }
        if (data.merchantPhone.trim().isNotEmpty) {
          add(_SummaryCard(
            label: 'Téléphone',
            value: data.merchantPhone.trim(),
            emoji: '📞',
          ));
        }
      case null:
        break;
    }

    return rows;
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _IconBox(emoji: emoji),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(label),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: DriverHomePalette.textDark,
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

class _MultiSummaryCard extends StatelessWidget {
  final String label;
  final String emoji;
  final List<String> values;

  const _MultiSummaryCard({
    required this.label,
    required this.emoji,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(emoji: emoji),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(label),
                const SizedBox(height: 6),
                for (final v in values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.check,
                          size: 14,
                          color: DriverHomePalette.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          v,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: DriverHomePalette.textDark,
                          ),
                        ),
                      ],
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

class _IconBox extends StatelessWidget {
  final String emoji;

  const _IconBox({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: DriverHomePalette.softGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: DriverHomePalette.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}
