import 'package:flutter/material.dart';

import '../../../models/report.dart';
import '../../../theme/flow_theme.dart';
import '../../../widgets/flow_widgets.dart';
import '../../../widgets/home/home_section_header.dart';

class TrafficAlertsSection extends StatelessWidget {
  final List<Report> reports;

  const TrafficAlertsSection({super.key, required this.reports});

  Color _reportColor(String type) {
    switch (type) {
      case 'breakdown':
      case 'accident':
      case 'safety':
        return FlowColors.red;
      case 'control':
        return FlowColors.blue;
      default:
        return FlowColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(emoji: '⚠', title: 'Informations trafic'),
        ...reports.take(5).map((report) {
          final color = _reportColor(report.reportType);
          final ago = DateTime.now().difference(report.timestamp).inMinutes;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FlowColors.white,
                borderRadius: BorderRadius.circular(FlowTokens.rCard),
                border: Border.all(color: color.withValues(alpha: 0.2)),
                boxShadow: FlowTokens.soft,
              ),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  LineBadge(code: report.routeId, transportType: 'bus'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${report.typeLabel} · il y a $ago min',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F4D47),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
