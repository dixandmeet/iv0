import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/report.dart';
import '../services/disruption_service.dart';
import '../theme/aule_theme.dart';

/// Alertes & perturbations du réseau (retards, travaux, déviations,
/// interruptions). Source : info-trafic officielle Naolib via [DisruptionService].
class DisruptionsPage extends StatefulWidget {
  const DisruptionsPage({super.key});

  @override
  State<DisruptionsPage> createState() => _DisruptionsPageState();
}

class _DisruptionsPageState extends State<DisruptionsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DisruptionService>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? AuleColors.dark : AuleColors.light;

    final service = context.watch<DisruptionService>();
    final items = service.cached;

    return AuleTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(colors: c),
              Expanded(
                child: service.isLoading && items.isEmpty
                    ? Center(child: CircularProgressIndicator(color: c.brand))
                    : RefreshIndicator(
                        onRefresh: () =>
                            context.read<DisruptionService>().load(force: true),
                        color: c.brand,
                        backgroundColor: c.surface,
                        child: items.isEmpty
                            ? _EmptyState(colors: c)
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: items.length,
                                itemBuilder: (_, i) => _DisruptionCard(
                                    report: items[i], colors: c),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AuleColors colors;
  const _Header({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.line),
              ),
              child: Icon(LucideIcons.arrowLeft, size: 20, color: colors.text),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alertes & perturbations',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: colors.text,
                  ),
                ),
                Text(
                  'Réseau Naolib · info-trafic',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.muted,
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

class _EmptyState extends StatelessWidget {
  final AuleColors colors;
  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(LucideIcons.circleCheck, size: 44, color: colors.ok),
        const SizedBox(height: 16),
        Text(
          'Aucune perturbation en cours',
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Le réseau circule normalement.',
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.muted,
          ),
        ),
      ],
    );
  }
}

class _DisruptionCard extends StatelessWidget {
  final Report report;
  final AuleColors colors;
  const _DisruptionCard({required this.report, required this.colors});

  ({IconData icon, Color color}) get _visuals {
    switch (report.reportType) {
      case 'works':
        return (icon: LucideIcons.construction, color: colors.warn);
      case 'delay':
        return (icon: LucideIcons.clock3, color: colors.warn);
      case 'accident':
        return (icon: LucideIcons.triangleAlert, color: _red);
      case 'breakdown':
        return (icon: LucideIcons.wrench, color: _red);
      case 'safety':
        return (icon: LucideIcons.shieldAlert, color: _red);
      case 'control':
        return (icon: LucideIcons.shieldCheck, color: colors.brand);
      case 'crowded':
        return (icon: LucideIcons.users, color: colors.warn);
      default:
        return (icon: LucideIcons.triangleAlert, color: colors.warn);
    }
  }

  Color get _red =>
      colors.isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final v = _visuals;
    final line = report.routeId;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: v.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(v.icon, size: 20, color: v.color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _LineChip(label: line, colors: colors),
                    const SizedBox(width: 8),
                    Text(
                      report.typeLabel,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: v.color,
                      ),
                    ),
                    if (report.isOfficial) ...[
                      const SizedBox(width: 8),
                      Icon(LucideIcons.badgeCheck,
                          size: 14, color: colors.muted),
                    ],
                  ],
                ),
                if (report.description != null &&
                    report.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    report.description!,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: colors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChip extends StatelessWidget {
  final String label;
  final AuleColors colors;
  const _LineChip({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.brandWeak,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: colors.brand,
        ),
      ),
    );
  }
}
