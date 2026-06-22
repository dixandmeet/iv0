import 'package:flutter/material.dart';

enum TravelerCommentCategory {
  incident,
  delay,
  crowding,
  cleanliness,
  accessibility,
  safety,
  comfort,
  driver,
  other,
}

extension TravelerCommentCategoryLabel on TravelerCommentCategory {
  String get label {
    switch (this) {
      case TravelerCommentCategory.incident:
        return 'Incident';
      case TravelerCommentCategory.delay:
        return 'Retard';
      case TravelerCommentCategory.crowding:
        return 'Affluence';
      case TravelerCommentCategory.cleanliness:
        return 'Propreté';
      case TravelerCommentCategory.accessibility:
        return 'Accessibilité';
      case TravelerCommentCategory.safety:
        return 'Sécurité';
      case TravelerCommentCategory.comfort:
        return 'Confort';
      case TravelerCommentCategory.driver:
        return 'Conducteur';
      case TravelerCommentCategory.other:
        return 'Autre';
    }
  }

  Color get color {
    switch (this) {
      case TravelerCommentCategory.incident:
        return const Color(0xFFEF4444);
      case TravelerCommentCategory.delay:
        return const Color(0xFFF59E0B);
      case TravelerCommentCategory.crowding:
        return const Color(0xFF7C3AED);
      case TravelerCommentCategory.cleanliness:
        return const Color(0xFF16A34A);
      case TravelerCommentCategory.accessibility:
        return const Color(0xFF2563EB);
      case TravelerCommentCategory.safety:
        return const Color(0xFFDC2626);
      case TravelerCommentCategory.comfort:
        return const Color(0xFF0EA5A4);
      case TravelerCommentCategory.driver:
        return const Color(0xFF0891B2);
      case TravelerCommentCategory.other:
        return const Color(0xFF64748B);
    }
  }
}

enum TravelerCommentFilter {
  all,
  incidents,
  delays,
  crowding,
  cleanliness,
  accessibility,
  safety,
  other,
}

extension TravelerCommentFilterLabel on TravelerCommentFilter {
  String get label {
    switch (this) {
      case TravelerCommentFilter.all:
        return 'Tous';
      case TravelerCommentFilter.incidents:
        return 'Incidents';
      case TravelerCommentFilter.delays:
        return 'Retards';
      case TravelerCommentFilter.crowding:
        return 'Affluence';
      case TravelerCommentFilter.cleanliness:
        return 'Propreté';
      case TravelerCommentFilter.accessibility:
        return 'Accessibilité';
      case TravelerCommentFilter.safety:
        return 'Sécurité';
      case TravelerCommentFilter.other:
        return 'Autres';
    }
  }

  bool accepts(TravelerComment comment) {
    switch (this) {
      case TravelerCommentFilter.all:
        return true;
      case TravelerCommentFilter.incidents:
        return comment.category == TravelerCommentCategory.incident;
      case TravelerCommentFilter.delays:
        return comment.category == TravelerCommentCategory.delay;
      case TravelerCommentFilter.crowding:
        return comment.category == TravelerCommentCategory.crowding;
      case TravelerCommentFilter.cleanliness:
        return comment.category == TravelerCommentCategory.cleanliness;
      case TravelerCommentFilter.accessibility:
        return comment.category == TravelerCommentCategory.accessibility;
      case TravelerCommentFilter.safety:
        return comment.category == TravelerCommentCategory.safety;
      case TravelerCommentFilter.other:
        return comment.category == TravelerCommentCategory.other ||
            comment.category == TravelerCommentCategory.comfort ||
            comment.category == TravelerCommentCategory.driver;
    }
  }
}

enum TravelerCommentAccessState { certified, anonymous, nonCertified }

class TravelerComment {
  static const int moderationReportThreshold = 3;

  final String id;
  final String authorName;
  final String lineName;
  final String vehicleName;
  final String stopName;
  final DateTime createdAt;
  final TravelerCommentCategory category;
  final String message;
  final int reactionCount;
  final int reportCount;
  final bool authorCertified;

  const TravelerComment({
    required this.id,
    required this.authorName,
    required this.lineName,
    required this.vehicleName,
    required this.stopName,
    required this.createdAt,
    required this.category,
    required this.message,
    required this.reactionCount,
    this.reportCount = 0,
    this.authorCertified = true,
  });

  TravelerComment copyWith({
    String? id,
    String? authorName,
    String? lineName,
    String? vehicleName,
    String? stopName,
    DateTime? createdAt,
    TravelerCommentCategory? category,
    String? message,
    int? reactionCount,
    int? reportCount,
    bool? authorCertified,
  }) {
    return TravelerComment(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      lineName: lineName ?? this.lineName,
      vehicleName: vehicleName ?? this.vehicleName,
      stopName: stopName ?? this.stopName,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      message: message ?? this.message,
      reactionCount: reactionCount ?? this.reactionCount,
      reportCount: reportCount ?? this.reportCount,
      authorCertified: authorCertified ?? this.authorCertified,
    );
  }

  bool get isActive =>
      DateTime.now().difference(createdAt) < const Duration(hours: 24);

  bool get isHiddenByModeration => reportCount >= moderationReportThreshold;

  String get elapsedLabel {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'à l’instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'expiré';
  }

  String get initials {
    final compact = authorName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (compact.isEmpty) return '?';
    return compact.substring(0, compact.length >= 2 ? 2 : 1).toUpperCase();
  }

  static List<TravelerComment> demo({
    required String lineName,
    required String stopName,
    String vehicleName = 'Véhicule 4218',
  }) {
    final now = DateTime.now();
    final comments = [
      TravelerComment(
        id: 'nadia-delay',
        authorName: 'Nadia_44',
        lineName: lineName,
        vehicleName: vehicleName,
        stopName: stopName,
        createdAt: now.subtract(const Duration(minutes: 4)),
        category: TravelerCommentCategory.delay,
        message: 'Bus en retard d’environ 10 minutes.',
        reactionCount: 5,
      ),
      TravelerComment(
        id: 'yannick-crowding',
        authorName: 'YannickL',
        lineName: lineName,
        vehicleName: vehicleName,
        stopName: 'Les Salles',
        createdAt: now.subtract(const Duration(minutes: 12)),
        category: TravelerCommentCategory.crowding,
        message: 'Le bus est assez bondé en heure de pointe.',
        reactionCount: 3,
      ),
      TravelerComment(
        id: 'sarah-driver',
        authorName: 'SarahB',
        lineName: lineName,
        vehicleName: vehicleName,
        stopName: stopName,
        createdAt: now.subtract(const Duration(minutes: 25)),
        category: TravelerCommentCategory.driver,
        message: 'Conducteur très sympa, conduite au top !',
        reactionCount: 2,
      ),
      TravelerComment(
        id: 'tom-clean',
        authorName: 'Tom_85',
        lineName: lineName,
        vehicleName: vehicleName,
        stopName: 'Haluchère - Batignolles',
        createdAt: now.subtract(const Duration(minutes: 40)),
        category: TravelerCommentCategory.cleanliness,
        message: 'Bus propre et bien entretenu.',
        reactionCount: 1,
      ),
      TravelerComment(
        id: 'lea-access',
        authorName: 'LeaPMR',
        lineName: lineName,
        vehicleName: vehicleName,
        stopName: stopName,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 7)),
        category: TravelerCommentCategory.accessibility,
        message: 'Rampe disponible, montée possible sans difficulté.',
        reactionCount: 6,
      ),
      TravelerComment(
        id: 'moderated',
        authorName: 'Voyageur32',
        lineName: lineName,
        vehicleName: vehicleName,
        stopName: 'Koufra',
        createdAt: now.subtract(const Duration(hours: 2)),
        category: TravelerCommentCategory.other,
        message: 'Message masqué après plusieurs signalements.',
        reactionCount: 0,
        reportCount: 3,
      ),
      TravelerComment(
        id: 'expired',
        authorName: 'OldTrip',
        lineName: lineName,
        vehicleName: vehicleName,
        stopName: stopName,
        createdAt: now.subtract(const Duration(hours: 25)),
        category: TravelerCommentCategory.safety,
        message: 'Commentaire expiré automatiquement.',
        reactionCount: 1,
      ),
    ];

    return comments.where((comment) => comment.isActive).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
