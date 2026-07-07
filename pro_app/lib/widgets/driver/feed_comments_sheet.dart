import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/feed_comment.dart';
import '../../models/driver/feed_post.dart';
import '../../services/driver/driver_service.dart';
import '../../services/driver/feed_service.dart';
import '../../theme/driver_home_palette.dart';
import 'driver_avatar.dart';

/// Ouvre la feuille de commentaires d'un post en bottom sheet.
Future<void> openFeedComments(BuildContext context, FeedPost post) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FeedCommentsSheet(post: post),
  );
}

class _FeedCommentsSheet extends StatefulWidget {
  final FeedPost post;

  const _FeedCommentsSheet({required this.post});

  @override
  State<_FeedCommentsSheet> createState() => _FeedCommentsSheetState();
}

class _FeedCommentsSheetState extends State<_FeedCommentsSheet> {
  final _controller = TextEditingController();
  late Future<List<FeedComment>> _future;
  List<FeedComment> _comments = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<FeedComment>> _load() async {
    final comments =
        await context.read<FeedService>().fetchComments(widget.post.id);
    if (mounted) setState(() => _comments = comments);
    return comments;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final driver = context.read<DriverService>().driver;
    if (driver == null) return;

    setState(() => _sending = true);
    final comment = await context.read<FeedService>().addComment(
          postId: widget.post.id,
          driverId: driver.id,
          authorName: driver.fullName,
          authorAvatarUrl: driver.avatarUrl,
          body: text,
        );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (comment != null) {
        _comments.add(comment);
        _controller.clear();
      }
    });
  }

  Future<void> _delete(FeedComment comment) async {
    final ok = await context.read<FeedService>().deleteComment(comment);
    if (ok && mounted) {
      setState(() => _comments.removeWhere((c) => c.id == comment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverId = context.watch<DriverService>().driver?.id;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: DriverHomePalette.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DriverHomePalette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
                  child: Row(
                    children: [
                      Text(
                        'Commentaires',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: DriverHomePalette.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: DriverHomePalette.border),
                Expanded(
                  child: FutureBuilder<List<FeedComment>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: DriverHomePalette.primary,
                          ),
                        );
                      }
                      if (_comments.isEmpty) {
                        return ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(24),
                          children: const [
                            SizedBox(height: 30),
                            Center(
                              child: Text(
                                'Aucun commentaire pour l\'instant',
                                style: TextStyle(
                                  color: DriverHomePalette.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: _comments.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          final comment = _comments[i];
                          return _CommentTile(
                            comment: comment,
                            canDelete: comment.isMine(driverId),
                            onDelete: () => _delete(comment),
                          );
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: DriverHomePalette.border),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 500,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Ajouter un commentaire…',
                              counterText: '',
                              filled: true,
                              fillColor: DriverHomePalette.background,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _sending ? null : _send,
                          style: IconButton.styleFrom(
                            backgroundColor: DriverHomePalette.primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(LucideIcons.send, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final FeedComment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DriverAvatarCompact(
          initials: comment.authorInitials,
          imageUrl: comment.authorAvatarUrl,
          size: 32,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      comment.authorLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: DriverHomePalette.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _relativeTime(comment.createdAt),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: DriverHomePalette.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                comment.body,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: DriverHomePalette.textDark,
                ),
              ),
            ],
          ),
        ),
        if (canDelete)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(LucideIcons.trash2, size: 16),
            color: DriverHomePalette.textSecondary,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
      ],
    );
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'À l\'instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} j';
    return DateFormat('d MMM', 'fr_FR').format(date);
  }
}
