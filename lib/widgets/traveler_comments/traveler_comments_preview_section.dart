import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/gtfs.dart';
import '../../models/traveler_comment.dart';
import '../../screens/traveler_comments_page.dart';
import '../../services/gtfs_service.dart';
import '../../services/traveler_comment_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/aule_theme.dart';
import 'traveler_comment_card.dart';

class TravelerCommentsPreviewSection extends StatelessWidget {
  final GtfsRoute route;
  final String headsign;
  final NearbyStation station;
  final List<GtfsStop> stops;
  final Color lineColor;
  final TravelerCommentAccessState accessState;

  const TravelerCommentsPreviewSection({
    super.key,
    required this.route,
    required this.headsign,
    required this.station,
    required this.stops,
    required this.lineColor,
    this.accessState = TravelerCommentAccessState.certified,
  });

  void _openComments(BuildContext context, List<TravelerComment> comments) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuleTheme(
          colors: AuleTheme.of(context),
          child: TravelerCommentsPage(
            route: route,
            headsign: headsign,
            station: station,
            stops: stops,
            comments: comments,
            lineColor: lineColor,
            accessState: accessState,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    final lineName = route.routeShortName ?? route.routeId;
    final vehicleName = '${route.transportTypeLabel} $lineName';
    final contextKey = TravelerCommentService.contextKey(
      routeId: route.routeId,
      stopId: station.stop.stopId,
    );
    final service = _maybeCommentService(context);
    final comments = service?.activeComments(
          contextKey: contextKey,
          lineName: lineName,
          stopName: station.stop.stopName,
          vehicleName: vehicleName,
        ) ??
        TravelerComment.demo(
          lineName: lineName,
          stopName: station.stop.stopName,
          vehicleName: vehicleName,
        );
    final preview = comments.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.line),
          boxShadow: AuleTokens.cardShadow(colors.shadow),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.brandWeak,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.messageSquareText,
                    size: 21,
                    color: colors.brand,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commentaires voyageurs',
                        style: hankenGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${comments.length} commentaires actifs',
                        style: hankenGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                _CountBadge(count: comments.length),
              ],
            ),
            const SizedBox(height: 14),
            for (final comment in preview) ...[
              TravelerCommentCard(
                comment: comment,
                compact: true,
                hasReacted: service?.hasReacted(comment.id) ?? false,
                onReact: service == null
                    ? null
                    : () => service.toggleReaction(contextKey, comment.id),
                onReport: service == null
                    ? () => _showReportSnack(context)
                    : () {
                        service.reportComment(contextKey, comment.id);
                        _showReportSnack(context);
                      },
              ),
              if (comment != preview.last) const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _openComments(context, comments),
                icon: const Icon(LucideIcons.messagesSquare, size: 18),
                label: Text(
                  'Voir tous les commentaires',
                  style: hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: lineColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportSnack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signalement pris en compte.')),
    );
  }
}

TravelerCommentService? _maybeCommentService(BuildContext context) {
  try {
    return Provider.of<TravelerCommentService>(context);
  } on ProviderNotFoundException {
    return null;
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.brand,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: hankenGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

extension on GtfsRoute {
  String get transportTypeLabel {
    switch (transportType.toLowerCase()) {
      case 'tram':
        return 'Tram';
      case 'navibus':
        return 'Navibus';
      case 'busway':
        return 'Chronobus';
      default:
        return 'Bus';
    }
  }
}
