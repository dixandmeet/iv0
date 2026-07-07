/// Type de média attaché à un post du fil d'actualité (valeur DB).
enum FeedMediaType {
  none('none'),
  image('image'),
  video('video');

  final String dbValue;

  const FeedMediaType(this.dbValue);

  static FeedMediaType fromDb(String? value) => FeedMediaType.values.firstWhere(
        (t) => t.dbValue == value,
        orElse: () => FeedMediaType.none,
      );
}

/// Post du fil d'actualité communautaire Aule Pro (table `feed_posts`).
///
/// L'auteur (nom + avatar) est dénormalisé à la publication : la RLS de
/// `drivers` interdit la lecture des autres fiches conducteur.
class FeedPost {
  final String id;
  final String authorDriverId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String? body;
  final String? mediaUrl;
  final String? mediaThumbnailUrl;
  final FeedMediaType mediaType;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;

  const FeedPost({
    required this.id,
    required this.authorDriverId,
    this.authorName,
    this.authorAvatarUrl,
    this.body,
    this.mediaUrl,
    this.mediaThumbnailUrl,
    this.mediaType = FeedMediaType.none,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedByMe = false,
  });

  /// Copie avec mise à jour ponctuelle (like optimiste, compteurs...).
  FeedPost copyWith({
    int? likesCount,
    int? commentsCount,
    bool? likedByMe,
  }) {
    return FeedPost(
      id: id,
      authorDriverId: authorDriverId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      body: body,
      mediaUrl: mediaUrl,
      mediaThumbnailUrl: mediaThumbnailUrl,
      mediaType: mediaType,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }

  /// `true` si le post appartient au conducteur courant.
  bool isMine(String? driverId) =>
      driverId != null && driverId == authorDriverId;

  bool get hasImage =>
      mediaType == FeedMediaType.image &&
      mediaUrl != null &&
      mediaUrl!.trim().isNotEmpty;

  bool get hasVideo =>
      mediaType == FeedMediaType.video &&
      mediaUrl != null &&
      mediaUrl!.trim().isNotEmpty;

  bool get hasBody => body != null && body!.trim().isNotEmpty;

  /// Nom affiché, avec repli neutre si non renseigné.
  String get authorLabel {
    final name = authorName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'Aule Pro';
  }

  /// Initiales pour l'avatar de repli.
  String get authorInitials {
    final parts = authorLabel
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'] as String,
      authorDriverId: json['author_driver_id'] as String,
      authorName: json['author_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      body: json['body'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaThumbnailUrl: json['media_thumbnail_url'] as String?,
      mediaType: FeedMediaType.fromDb(json['media_type'] as String?),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
    );
  }
}
