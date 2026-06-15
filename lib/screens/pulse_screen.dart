import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/vehicle_detection_service.dart';
import '../services/report_service.dart';
import '../models/community_vehicle.dart';
import '../models/report.dart';
import '../theme/flow_theme.dart';
import '../widgets/flow_widgets.dart';

class PulseScreen extends StatelessWidget {
  const PulseScreen({super.key});

  int _punctuality(List<CommunityVehicle> vehicles, String mode, int fallback) {
    final list = vehicles.where((v) => v.transportType.toLowerCase() == mode).toList();
    if (list.isEmpty) return fallback;
    final onTime = list.where((v) => (v.estimatedDelaySeconds ?? 0) <= 30).length;
    return ((onTime / list.length) * 100).round();
  }

  Color _ringColor(int pct) => pct >= 90 ? FlowColors.green : (pct >= 75 ? FlowColors.orange : FlowColors.red);

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
    final detection = Provider.of<VehicleDetectionService>(context);
    final reportService = Provider.of<ReportService>(context);
    final vehicles = detection.detectedVehicles;
    final reports = reportService.activeReports;

    final bus = _punctuality(vehicles, 'bus', 92);
    final busway = _punctuality(vehicles, 'busway', 90);
    final tram = _punctuality(vehicles, 'tram', 96);
    final navibus = _punctuality(vehicles, 'navibus', 88);

    // Affluence globale agrégée
    final crowdLevel = reports.length > 4 || vehicles.length > 6
        ? CrowdLevel.high
        : (reports.length > 1 || vehicles.length > 3 ? CrowdLevel.mid : CrowdLevel.low);

    return Scaffold(
      backgroundColor: FlowColors.white,
      appBar: AppBar(
        backgroundColor: FlowColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: FlowColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            // En-tête
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pulse', style: FlowText.title),
                      SizedBox(height: 2),
                      Text('Santé du réseau · maintenant', style: FlowText.rowSub),
                    ],
                  ),
                ),
                SoftBadge(text: 'Live', color: FlowColors.green, background: FlowColors.greenSoft, dot: true),
              ],
            ),
            const SizedBox(height: 18),

            // 3 anneaux
            Row(
              children: [
                Expanded(child: _RingTile(value: (bus + busway) ~/ 2, label: 'Bus', sub: 'à l\'heure', color: _ringColor((bus + busway) ~/ 2))),
                const SizedBox(width: 10),
                Expanded(child: _RingTile(value: tram, label: 'Tram', sub: 'à l\'heure', color: _ringColor(tram))),
                const SizedBox(width: 10),
                Expanded(child: _RingTile(value: navibus, label: 'Navibus', sub: 'à l\'heure', color: _ringColor(navibus))),
              ],
            ),
            const SizedBox(height: 16),

            // Affluence globale
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionLabel('Affluence globale'),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      _GaugeSeg(label: 'Faible', active: crowdLevel == CrowdLevel.low, color: FlowColors.green, soft: FlowColors.greenSoft),
                      const SizedBox(width: 6),
                      _GaugeSeg(label: 'Moyenne', active: crowdLevel == CrowdLevel.mid, color: FlowColors.orange, soft: FlowColors.orangeSoft),
                      const SizedBox(width: 6),
                      _GaugeSeg(label: 'Élevée', active: crowdLevel == CrowdLevel.high, color: FlowColors.red, soft: FlowColors.redSoft),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Incidents en cours
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionLabel('Incidents en cours'),
                      Text('${reports.length}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: reports.isEmpty ? FlowColors.green : FlowColors.red)),
                    ],
                  ),
                  const SizedBox(height: 11),
                  if (reports.isEmpty)
                    _EmptyIncidents()
                  else
                    ...reports.take(5).toList().asMap().entries.map((e) {
                      final Report r = e.value;
                      final isLast = e.key == (reports.length > 5 ? 4 : reports.length - 1);
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          border: isLast ? null : const Border(bottom: BorderSide(color: FlowColors.line)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 9, height: 9,
                              decoration: BoxDecoration(color: _reportColor(r.reportType), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            LineBadge(code: r.routeId, transportType: 'bus'),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('${r.typeLabel} · il y a ${DateTime.now().difference(r.timestamp).inMinutes} min',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4F4D47)),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlowColors.white,
        borderRadius: BorderRadius.circular(FlowTokens.rCard),
        border: Border.all(color: FlowColors.line),
        boxShadow: FlowTokens.soft,
      ),
      child: child,
    );
  }
}

class _RingTile extends StatelessWidget {
  final int value;
  final String label;
  final String sub;
  final Color color;
  const _RingTile({required this.value, required this.label, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 11),
      decoration: BoxDecoration(
        color: FlowColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlowColors.line),
        boxShadow: FlowTokens.soft,
      ),
      child: Column(
        children: [
          SizedBox(
            width: 70, height: 70,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value / 100),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) {
                return CustomPaint(
                  painter: _RingPainter(progress: v, color: color),
                  child: Center(
                    child: Text('${(v * 100).round()}%',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 1),
          Text(sub, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: FlowColors.g2)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;
    final bg = Paint()
      ..color = FlowColors.fill2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

class _GaugeSeg extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final Color soft;
  const _GaugeSeg({required this.label, required this.active, required this.color, required this.soft});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? soft : FlowColors.fill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: active ? color : FlowColors.g2)),
      ),
    );
  }
}

class _EmptyIncidents extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: FlowColors.greenSoft, borderRadius: BorderRadius.circular(14)),
            child: const Icon(LucideIcons.check, color: FlowColors.green, size: 22),
          ),
          const SizedBox(width: 13),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Réseau fluide', style: FlowText.rowTitle),
              SizedBox(height: 1),
              Text('Aucun incident signalé en ce moment.', style: FlowText.rowSub),
            ],
          ),
        ],
      ),
    );
  }
}
