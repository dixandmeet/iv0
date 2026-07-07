import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/feed_post.dart';
import '../../services/driver/driver_service.dart';
import '../../services/driver/feed_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../widgets/driver/feed_post_card.dart';
import 'driver_feed_composer_screen.dart';

/// Demande confirmation puis supprime un post. Mutualisé entre l'accueil et
/// l'écran complet du fil.
Future<void> confirmAndDeleteFeedPost(
  BuildContext context,
  FeedPost post,
) async {
  final feed = context.read<FeedService>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Supprimer la publication ?'),
      content: const Text('Cette action est définitive.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: DriverHomePalette.danger,
          ),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final ok = await feed.deletePost(post);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(feed.errorMessage ?? 'Échec de la suppression')),
      );
  }
}

/// Ouvre le composer puis rafraîchit le fil au retour.
Future<void> openFeedComposer(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const DriverFeedComposerScreen()),
  );
}

/// Écran complet du fil d'actualité communautaire.
class DriverFeedScreen extends StatefulWidget {
  const DriverFeedScreen({super.key});

  @override
  State<DriverFeedScreen> createState() => _DriverFeedScreenState();
}

class _DriverFeedScreenState extends State<DriverFeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final driverId = context.read<DriverService>().driver?.id;
      context.read<FeedService>().fetchFeed(driverId: driverId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedService>();
    final driverId = context.watch<DriverService>().driver?.id;
    final posts = feed.posts;

    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      floatingActionButton: _GradientFab(
        icon: LucideIcons.penLine,
        label: 'Publier',
        onTap: () => openFeedComposer(context),
      ),
      body: Column(
        children: [
          _hero(context, count: posts.length),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  feed.fetchFeed(driverId: driverId, silent: true),
              color: DriverHomePalette.primary,
              child: feed.loading && posts.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: DriverHomePalette.primary,
                      ),
                    )
                  : posts.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            _FeedEmptyState(),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 96),
                          itemCount: posts.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, i) {
                            final post = posts[i];
                            return FeedPostCard(
                              post: post,
                              canDelete: post.isMine(driverId),
                              onDelete: () =>
                                  confirmAndDeleteFeedPost(context, post),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, {required int count}) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DriverHomePalette.gradientStart,
              DriverHomePalette.gradientEnd,
            ],
          ),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: DriverHomePalette.darkGreen.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28)),
          child: Stack(
            children: [
              Positioned(top: -40, right: -30, child: _glow(150, 0.12)),
              Positioned(bottom: -40, left: -20, child: _glow(130, 0.08)),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _GlassIconButton(
                            icon: LucideIcons.arrowLeft,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              LucideIcons.messagesSquare,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fil d\'actualité',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  count > 0
                                      ? '$count publication${count > 1 ? 's' : ''} de la communauté'
                                      : 'Partagez avec la communauté',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glow(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

/// Bouton circulaire « en verre » pour le hero.
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

/// FAB dégradé cohérent avec la direction artistique premium.
class _GradientFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GradientFab({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DriverHomePalette.gradientStart,
            DriverHomePalette.gradientEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: DriverHomePalette.gradientEnd.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: DriverHomePalette.lightGreen,
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(
              LucideIcons.messagesSquare,
              size: 38,
              color: DriverHomePalette.primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Aucune publication',
            style: TextStyle(
              color: DriverHomePalette.textDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Soyez le premier à partager une info\nou une photo du terrain !',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: DriverHomePalette.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
