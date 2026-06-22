import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../models/traveler_comment.dart';
import '../services/gtfs_service.dart';
import '../services/traveler_comment_service.dart';
import '../theme/app_fonts.dart';
import '../theme/aule_theme.dart';
import '../widgets/traveler_comments/traveler_comment_card.dart';
import 'new_traveler_comment_page.dart';

class TravelerCommentsPage extends StatefulWidget {
  final GtfsRoute route;
  final String headsign;
  final NearbyStation station;
  final List<GtfsStop> stops;
  final List<TravelerComment> comments;
  final Color lineColor;
  final TravelerCommentAccessState accessState;

  const TravelerCommentsPage({
    super.key,
    required this.route,
    required this.headsign,
    required this.station,
    required this.stops,
    required this.comments,
    required this.lineColor,
    this.accessState = TravelerCommentAccessState.certified,
  });

  @override
  State<TravelerCommentsPage> createState() => _TravelerCommentsPageState();
}

class _TravelerCommentsPageState extends State<TravelerCommentsPage> {
  TravelerCommentFilter _selectedFilter = TravelerCommentFilter.all;
  late List<TravelerComment> _localComments;
  final Set<String> _localReactedIds = {};

  @override
  void initState() {
    super.initState();
    _localComments = List.of(widget.comments);
  }

  Future<void> _openNewComment(
      [TravelerCommentAccessState? accessState]) async {
    final result = await Navigator.push<TravelerComment>(
      context,
      MaterialPageRoute(
        builder: (_) => AuleTheme(
          colors: AuleTheme.of(context),
          child: NewTravelerCommentPage(
            route: widget.route,
            station: widget.station,
            stops: widget.stops,
            lineColor: widget.lineColor,
            accessState: accessState ?? widget.accessState,
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _localComments.insert(0, result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    final lineName = widget.route.routeShortName ?? widget.route.routeId;
    final vehicleName = _vehicleName(widget.route, lineName);
    final contextKey = TravelerCommentService.contextKey(
      routeId: widget.route.routeId,
      stopId: widget.station.stop.stopId,
    );
    final service = _maybeCommentService(context);
    final comments = service?.activeComments(
          contextKey: contextKey,
          lineName: lineName,
          stopName: widget.station.stop.stopName,
          vehicleName: vehicleName,
        ) ??
        _localComments;
    final filtered =
        comments.where((comment) => _selectedFilter.accepts(comment)).toList();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              count: comments.length,
              onBack: () => Navigator.pop(context),
            ),
            _FilterBar(
              selected: _selectedFilter,
              onSelected: (filter) => setState(() {
                _selectedFilter = filter;
              }),
            ),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: filtered.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _TrustInfoCard(
                      lineColor: widget.lineColor,
                      onAnonymousPreview: () => _openNewComment(
                        TravelerCommentAccessState.anonymous,
                      ),
                      onNonCertifiedPreview: () => _openNewComment(
                        TravelerCommentAccessState.nonCertified,
                      ),
                    );
                  }
                  final comment = filtered[index - 1];
                  return TravelerCommentCard(
                    comment: comment,
                    hasReacted: service?.hasReacted(comment.id) ??
                        _localReactedIds.contains(comment.id),
                    onReact: service == null
                        ? () => _toggleLocalReaction(comment.id)
                        : () => service.toggleReaction(contextKey, comment.id),
                    onReport: service == null
                        ? () => _reportLocalComment(comment.id)
                        : () {
                            service.reportComment(contextKey, comment.id);
                            _showReportSnack(context);
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: _openNewComment,
            icon: const Icon(LucideIcons.squarePen, size: 19),
            label: Text(
              'Laisser un commentaire',
              style: hankenGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: widget.lineColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 10,
              shadowColor: widget.lineColor.withValues(alpha: 0.34),
            ),
          ),
        ),
      ),
    );
  }

  void _showReportSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signalement pris en compte.')),
    );
  }

  void _toggleLocalReaction(String commentId) {
    setState(() {
      final index =
          _localComments.indexWhere((comment) => comment.id == commentId);
      if (index < 0) return;
      final comment = _localComments[index];
      final alreadyReacted = _localReactedIds.contains(commentId);
      if (alreadyReacted) {
        _localReactedIds.remove(commentId);
      } else {
        _localReactedIds.add(commentId);
      }
      _localComments[index] = comment.copyWith(
        reactionCount: alreadyReacted
            ? (comment.reactionCount - 1).clamp(0, 99999).toInt()
            : comment.reactionCount + 1,
      );
    });
  }

  void _reportLocalComment(String commentId) {
    setState(() {
      final index =
          _localComments.indexWhere((comment) => comment.id == commentId);
      if (index < 0) return;
      final comment = _localComments[index];
      _localComments[index] = comment.copyWith(
        reportCount: comment.reportCount + 1,
      );
    });
    _showReportSnack(context);
  }

  String _vehicleName(GtfsRoute route, String lineName) {
    switch (route.transportType.toLowerCase()) {
      case 'tram':
        return 'Tram $lineName';
      case 'navibus':
        return 'Navibus $lineName';
      case 'busway':
        return 'Chronobus $lineName';
      default:
        return 'Bus $lineName';
    }
  }
}

TravelerCommentService? _maybeCommentService(BuildContext context) {
  try {
    return Provider.of<TravelerCommentService>(context);
  } on ProviderNotFoundException {
    return null;
  }
}

class _Header extends StatelessWidget {
  final int count;
  final VoidCallback onBack;

  const _Header({
    required this.count,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(LucideIcons.arrowLeft, color: colors.text),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commentaires voyageurs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: hankenGrotesk(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count commentaires actifs',
                  style: hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class _FilterBar extends StatelessWidget {
  final TravelerCommentFilter selected;
  final ValueChanged<TravelerCommentFilter> onSelected;

  const _FilterBar({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: TravelerCommentFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = TravelerCommentFilter.values[index];
          final isSelected = filter == selected;
          return Material(
            color: isSelected ? colors.brand : colors.surface,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onSelected(filter),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? colors.brand : colors.line,
                  ),
                ),
                child: Text(
                  filter.label,
                  style: hankenGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : colors.muted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrustInfoCard extends StatelessWidget {
  final Color lineColor;
  final VoidCallback onAnonymousPreview;
  final VoidCallback onNonCertifiedPreview;

  const _TrustInfoCard({
    required this.lineColor,
    required this.onAnonymousPreview,
    required this.onNonCertifiedPreview,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.brandWeak,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.brandLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.shieldCheck, size: 22, color: lineColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Partagez votre expérience pour informer les autres voyageurs.',
                  style: hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: colors.text,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Seuls les voyageurs certifiés peuvent publier. Les commentaires expirent après 24 heures.',
                  style: hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PreviewButton(
                      label: 'État anonyme',
                      onTap: onAnonymousPreview,
                    ),
                    _PreviewButton(
                      label: 'État non certifié',
                      onTap: onNonCertifiedPreview,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PreviewButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.line),
        ),
        child: Text(
          label,
          style: hankenGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: colors.muted,
          ),
        ),
      ),
    );
  }
}
