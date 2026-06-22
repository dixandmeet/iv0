import 'package:flutter/foundation.dart';

import '../models/traveler_comment.dart';

class TravelerCommentService extends ChangeNotifier {
  final Map<String, List<TravelerComment>> _commentsByContext = {};
  final Set<String> _reactedCommentIds = {};
  final Set<String> _reportedCommentIds = {};

  static String contextKey({
    required String routeId,
    required String stopId,
  }) {
    return '$routeId::$stopId';
  }

  List<TravelerComment> activeComments({
    required String contextKey,
    required String lineName,
    required String stopName,
    required String vehicleName,
  }) {
    _seedIfNeeded(
      contextKey: contextKey,
      lineName: lineName,
      stopName: stopName,
      vehicleName: vehicleName,
    );

    final comments = (_commentsByContext[contextKey] ?? const [])
        .where((comment) => comment.isActive)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(comments);
  }

  bool hasReacted(String commentId) => _reactedCommentIds.contains(commentId);

  TravelerComment addComment({
    required String contextKey,
    required String lineName,
    required String vehicleName,
    required String stopName,
    required TravelerCommentCategory category,
    required String message,
    String authorName = 'Vous',
  }) {
    final comment = TravelerComment(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      authorName: authorName,
      lineName: lineName,
      vehicleName: vehicleName,
      stopName: stopName,
      createdAt: DateTime.now(),
      category: category,
      message: message.trim(),
      reactionCount: 0,
    );

    final existing = _commentsByContext.putIfAbsent(contextKey, () => []);
    existing.insert(0, comment);
    notifyListeners();
    return comment;
  }

  void toggleReaction(String contextKey, String commentId) {
    _updateComment(contextKey, commentId, (comment) {
      final alreadyReacted = _reactedCommentIds.contains(commentId);
      if (alreadyReacted) {
        _reactedCommentIds.remove(commentId);
      } else {
        _reactedCommentIds.add(commentId);
      }

      final nextCount = alreadyReacted
          ? (comment.reactionCount - 1).clamp(0, 99999).toInt()
          : comment.reactionCount + 1;
      return comment.copyWith(reactionCount: nextCount);
    });
  }

  void reportComment(String contextKey, String commentId) {
    if (_reportedCommentIds.contains(commentId)) return;
    _reportedCommentIds.add(commentId);
    _updateComment(
      contextKey,
      commentId,
      (comment) => comment.copyWith(reportCount: comment.reportCount + 1),
    );
  }

  void _seedIfNeeded({
    required String contextKey,
    required String lineName,
    required String stopName,
    required String vehicleName,
  }) {
    _commentsByContext.putIfAbsent(
      contextKey,
      () => TravelerComment.demo(
        lineName: lineName,
        stopName: stopName,
        vehicleName: vehicleName,
      ),
    );
  }

  void _updateComment(
    String contextKey,
    String commentId,
    TravelerComment Function(TravelerComment comment) update,
  ) {
    final comments = _commentsByContext[contextKey];
    if (comments == null) return;

    final index = comments.indexWhere((comment) => comment.id == commentId);
    if (index < 0) return;

    comments[index] = update(comments[index]);
    notifyListeners();
  }
}
