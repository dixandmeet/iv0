import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/home_aggregator.dart';
import '../../../services/map_service.dart';
import '../../../theme/flow_theme.dart';
import '../../../widgets/flow_widgets.dart';
import '../../../widgets/home/home_section_header.dart';

class SmartSuggestionsSection extends StatelessWidget {
  final SmartSuggestion? suggestion;

  const SmartSuggestionsSection({super.key, this.suggestion});

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    if (s == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(emoji: '✨', title: 'Suggestions'),
        switch (s) {
          RushHourSuggestion rush => _RushCard(suggestion: rush),
          DisruptionSuggestion disruption => _DisruptionCard(suggestion: disruption),
        },
      ],
    );
  }
}

class _RushCard extends StatelessWidget {
  final RushHourSuggestion suggestion;
  const _RushCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final mapHelper = Provider.of<MapService>(context, listen: false);
    final color = mapHelper.getTransportColor(
      suggestion.route.transportType,
      routeColorHex: suggestion.route.routeColor,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlowColors.blueSoft,
        borderRadius: BorderRadius.circular(FlowTokens.rCardXl),
        boxShadow: FlowTokens.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Il est ${suggestion.timeLabel}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: FlowColors.g2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              LineBadge(
                code: suggestion.route.routeShortName ?? suggestion.route.routeId,
                transportType: suggestion.route.transportType,
                background: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Votre Ligne ${suggestion.route.routeShortName ?? suggestion.route.routeId} habituelle\nvers ${suggestion.headsign}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: FlowColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            suggestion.waitMinutes <= 1
                ? 'Arrive maintenant'
                : 'Arrive dans ${suggestion.waitMinutes} min',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: flowWaitColor(suggestion.waitMinutes),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisruptionCard extends StatelessWidget {
  final DisruptionSuggestion suggestion;
  const _DisruptionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlowColors.orangeSoft,
        borderRadius: BorderRadius.circular(FlowTokens.rCardXl),
        border: Border.all(color: FlowColors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Perturbation détectée sur votre trajet habituel',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: FlowColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${suggestion.report.typeLabel} · Ligne ${suggestion.lineLabel}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: FlowColors.g2,
            ),
          ),
        ],
      ),
    );
  }
}
