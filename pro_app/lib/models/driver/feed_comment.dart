/// Commentaire sur un post du fil d'actualité (table `feed_post_comments`).
///
/// Comme pour [FeedPost], l'auteur (nom + avatar) est dénormalisé à la
/// publication : la RLS de `drivers` interdit la lecture des autres fiches.
class FeedComment {
  final String id;
  final String postId;
  final String authorDriverId;
  final String? authorName;
  final String? authorAvatarUrl;
  final String body;
  final DateTime createdAt;

  const FeedComment({
    required this.id,
    required this.postId,
    required this.authorDriverId,
    this.authorName,
    this.authorAvatarUrl,
    required this.body,
    required this.createdAt,
  });

  bool isMine(String? driverId) =>
      driverId != null && driverId == authorDriverId;

  String get authorLabel {
    final name = authorName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'Aule Pro';
  }

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

  factory FeedComment.fromJson(Map<String, dynamic> json) {
    return FeedComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorDriverId: json['author_driver_id'] as String,
      authorName: json['author_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}
