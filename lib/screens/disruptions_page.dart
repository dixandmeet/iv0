import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/report.dart';
import '../services/disruption_service.dart';
import '../theme/aule_theme.dart';
import '../widgets/nearby_stops/line_badge.dart';

/// Alertes & perturbations du réseau (retards, travaux, déviations,
/// interruptions). Source : info-trafic officielle Naolib via [DisruptionService].
class DisruptionsPage extends StatefulWidget {
  const DisruptionsPage({super.key});

  @override
  State<DisruptionsPage> createState() => _DisruptionsPageState();
}

class _DisruptionsPageState extends State<DisruptionsPage> {
  /// null = toutes les lignes ; sinon le code de la ligne sélectionnée.
  String? _lineFilter;

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
    final all = service.cached;

    // Codes de lignes impactées, triés : structurantes d'abord, puis alpha.
    final lineCodes = service.impactedLineCodes.toList()
      ..sort((a, b) {
        final aStruct = _isStructurant(a) ? 0 : 1;
        final bStruct = _isStructurant(b) ? 0 : 1;
        if (aStruct != bStruct) return aStruct - bStruct;
        return a.compareTo(b);
      });

    // Filtre par ligne sélectionnée.
    final items = _lineFilter == null
        ? all
        : all.where((r) => r.routeId.toUpperCase() == _lineFilter).toList();

    // Perturbations « Réseau » (sans ligne précise) — toujours visibles.
    final networkWide =
        _lineFilter != null ? all.where((r) => r.routeId == 'Réseau').toList() : <Report>[];
    final combined = [...items, ...networkWide];

    return AuleTheme(
      colors: c,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                colors: c,
                linesImpacted: lineCodes.length,
              ),
              if (lineCodes.length > 1)
                _LineFilterRow(
                  selected: _lineFilter,
                  lineCodes: lineCodes,
                  colors: c,
                  onChanged: (code) => setState(() => _lineFilter = code),
                ),
              Expanded(
                child: service.isLoading && all.isEmpty
                    ? Center(child: CircularProgressIndicator(color: c.brand))
                    : RefreshIndicator(
                        onRefresh: () =>
                            context.read<DisruptionService>().load(force: true),
                        color: c.brand,
                        backgroundColor: c.surface,
                        child: combined.isEmpty
                            ? _EmptyState(colors: c)
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: combined.length,
                                itemBuilder: (_, i) => _DisruptionCard(
                                    report: combined[i], colors: c),
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

  static bool _isStructurant(String code) {
    final c = code.toUpperCase();
    return c.startsWith('C') || c.startsWith('E') || int.tryParse(c) != null && int.parse(c) <= 3;
  }
}

class _Header extends StatelessWidget {
  final AuleColors colors;
  final int linesImpacted;
  const _Header({required this.colors, required this.linesImpacted});

  @override
  Widget build(BuildContext context) {
    final sub = linesImpacted > 0
        ? '$linesImpacted ligne${linesImpacted > 1 ? 's' : ''} impactée${linesImpacted > 1 ? 's' : ''}'
        : 'Réseau Naolib · info-trafic';

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
                  style: hankenGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: colors.text,
                  ),
                ),
                Text(
                  sub,
                  style: hankenGrotesk(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: linesImpacted > 0 ? colors.warn : colors.muted,
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

/// Rangée horizontale de badges de lignes impactées. Chaque badge reprend la
/// couleur officielle de la ligne ; la sélection inverse le remplissage.
class _LineFilterRow extends StatelessWidget {
  final String? selected;
  final List<String> lineCodes;
  final AuleColors colors;
  final ValueChanged<String?> onChanged;

  const _LineFilterRow({
    required this.selected,
    required this.lineCodes,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: lineCodes.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _allChip();
          }
          final code = lineCodes[i - 1];
          return _lineBadge(code);
        },
      ),
    );
  }

  Widget _allChip() {
    final isSelected = selected == null;
    return GestureDetector(
      onTap: () => onChanged(null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.brand : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.brand : colors.line,
          ),
        ),
        child: Text(
          'Toutes',
          style: hankenGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : colors.muted,
          ),
        ),
      ),
    );
  }

  Widget _lineBadge(String code) {
    final isSelected = selected == code;
    final lineColor = LineBadge.colorFor(code);

    return GestureDetector(
      onTap: () => onChanged(isSelected ? null : code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minWidth: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? lineColor : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? lineColor : lineColor.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: lineColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          code,
          style: hankenGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : lineColor,
          ),
        ),
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
          style: hankenGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Le réseau circule normalement.',
          textAlign: TextAlign.center,
          style: hankenGrotesk(
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: v.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(v.icon, size: 20, color: v.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _LineChip(label: line, colors: colors),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report.typeLabel,
                        style: hankenGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: v.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (report.isOfficial) ...[
                      const SizedBox(width: 6),
                      Icon(LucideIcons.badgeCheck,
                          size: 14, color: colors.muted),
                    ],
                  ],
                ),
                if (report.description != null &&
                    report.description!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    report.description!,
                    style: hankenGrotesk(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.55,
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
    final lineColor = LineBadge.colorFor(label);
    final isNetwork = label == 'Réseau';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isNetwork
            ? colors.brandWeak
            : lineColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: hankenGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isNetwork ? colors.brand : lineColor,
        ),
      ),
    );
  }
}
