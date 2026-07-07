import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/service_exchange_post.dart';
import '../../services/driver/service_exchange_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../utils/service_exchange_actions.dart';
import '../../utils/service_exchange_share.dart';
import '../../widgets/driver/driver_avatar.dart';
import '../../widgets/driver/service_exchange_card.dart';
import '../../widgets/driver/service_exchange_profile_sheet.dart';
import 'service_exchange_create_screen.dart';

/// Détail d'une annonce d'échange + annonces similaires.
class ServiceExchangeDetailScreen extends StatefulWidget {
  final String postId;

  const ServiceExchangeDetailScreen({super.key, required this.postId});

  @override
  State<ServiceExchangeDetailScreen> createState() =>
      _ServiceExchangeDetailScreenState();
}

class _ServiceExchangeDetailScreenState
    extends State<ServiceExchangeDetailScreen>
    with TickerProviderStateMixin {
  ServiceExchangePost? _post;
  List<ServiceExchangePost> _similar = const [];
  bool _loading = true;

  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = context.read<ServiceExchangeService>();
    await service.recordView(widget.postId);
    final post = await service.fetchPostDetail(widget.postId);
    final similar = await service.fetchSimilar(widget.postId);
    if (mounted) {
      setState(() {
        _post = post;
        _similar = similar;
        _loading = false;
      });
      _entrance.forward();
    }
  }

  Future<void> _reload() async {
    final post =
        await context.read<ServiceExchangeService>().fetchPostDetail(widget.postId);
    if (mounted && post != null) setState(() => _post = post);
  }

  Future<void> _contact() async {
    final post = _post;
    if (post == null) return;
    await ServiceExchangeActions.contactAuthor(context, post);
    await _reload();
  }

  Future<void> _toggleFavorite() async {
    final post = _post;
    if (post == null) return;
    await context.read<ServiceExchangeService>().toggleFavorite(post.id);
    await _reload();
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null) return;
    await context
        .read<ServiceExchangeService>()
        .toggleReaction(post.id, ServiceExchangeReaction.like);
    await _reload();
  }

  Future<void> _edit() async {
    final post = _post;
    if (post == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ServiceExchangeCreateScreen(editPost: post),
      ),
    );
    if (changed == true) await _reload();
  }

  Future<void> _relance() async {
    final post = _post;
    if (post == null) return;
    final service = context.read<ServiceExchangeService>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await service.relancePost(post.id);
    if (!mounted) return;
    if (result != null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Annonce relancée')));
      await _reload();
    } else {
      messenger.showSnackBar(
          SnackBar(content: Text(service.error ?? 'Relance impossible')));
    }
  }

  Future<void> _markResolved() async {
    final post = _post;
    if (post == null) return;
    final notify = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marquer comme résolue'),
        content: const Text(
            'Souhaitez-vous prévenir les personnes qui vous ont contacté que '
            'l\'annonce est clôturée ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non, juste résoudre'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Oui, prévenir'),
          ),
        ],
      ),
    );
    if (notify == null || !mounted) return;
    await context
        .read<ServiceExchangeService>()
        .markResolved(post.id, notifyContacts: notify);
    await _reload();
  }

  Future<void> _cancel() async {
    final post = _post;
    if (post == null) return;
    await context
        .read<ServiceExchangeService>()
        .updateStatus(post.id, 'cancelled');
    await _reload();
  }

  Future<void> _delete() async {
    final post = _post;
    if (post == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'annonce'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: DriverHomePalette.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok =
        await context.read<ServiceExchangeService>().deletePost(post.id);
    if (mounted && ok) Navigator.of(context).pop(true);
  }

  // --- Helpers visuels ---

  Color _darken(Color color, [double amount = 0.2]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _skeletonScaffold();
    final post = _post;
    if (post == null) return _notFoundScaffold();
    return _loadedScaffold(post);
  }

  // ---------------------------------------------------------------------------
  // États
  // ---------------------------------------------------------------------------

  Scaffold _notFoundScaffold() {
    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      appBar: AppBar(
        backgroundColor: DriverHomePalette.card,
        surfaceTintColor: Colors.transparent,
        title: const Text('Annonce',
            style: TextStyle(
                color: DriverHomePalette.textDark,
                fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: DriverHomePalette.lightGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(LucideIcons.fileX2,
                  size: 30, color: DriverHomePalette.primary),
            ),
            const SizedBox(height: 16),
            const Text('Annonce introuvable',
                style: TextStyle(
                  color: DriverHomePalette.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 4),
            const Text('Elle a peut-être été supprimée ou clôturée.',
                style: TextStyle(
                    color: DriverHomePalette.textSecondary, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }

  Scaffold _skeletonScaffold() {
    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(LucideIcons.arrowLeft,
              color: DriverHomePalette.textDark),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _skel(double.infinity, 132, r: 24),
          const SizedBox(height: 20),
          Row(
            children: [
              _skel(120, 30, r: 999),
              const SizedBox(width: 8),
              _skel(86, 30, r: 999),
            ],
          ),
          const SizedBox(height: 20),
          _skel(double.infinity, 168, r: 20),
          const SizedBox(height: 14),
          _skel(double.infinity, 96, r: 20),
          const SizedBox(height: 14),
          _skel(double.infinity, 72, r: 20),
        ],
      ),
    );
  }

  Widget _skel(double w, double h, {double r = 12}) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, _) {
        final color = Color.lerp(
          const Color(0xFFEDF2EF),
          const Color(0xFFDCE7E1),
          _shimmer.value,
        )!;
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(r),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Écran chargé
  // ---------------------------------------------------------------------------

  Widget _loadedScaffold(ServiceExchangePost post) {
    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: DriverHomePalette.primary,
        child: CustomScrollView(
          slivers: [
            _heroAppBar(post),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: _content(post),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(post),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero (en-tête dégradé collapsible)
  // ---------------------------------------------------------------------------

  Widget _heroAppBar(ServiceExchangePost post) {
    final accent = post.serviceType.color;
    final top = _darken(accent, 0.04);
    final bottom = _darken(accent, 0.26);

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 280,
      backgroundColor: bottom,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leadingWidth: 60,
      leading: _glassButton(
        LucideIcons.arrowLeft,
        () => Navigator.of(context).maybePop(),
      ),
      actions: [
        _glassButton(
          LucideIcons.share2,
          () => ServiceExchangeShare.share(post),
        ),
        if (!post.isMine)
          _glassButton(
            post.isFavorited ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
            _toggleFavorite,
            highlighted: post.isFavorited,
          ),
        const SizedBox(width: 6),
      ],
      flexibleSpace: _heroFlexible(post, top, bottom),
    );
  }

  Widget _heroFlexible(ServiceExchangePost post, Color top, Color bottom) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final settings =
            context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
        final statusBar = MediaQuery.paddingOf(context).top;
        final maxExtent = settings?.maxExtent ?? 280;
        final minExtent = settings?.minExtent ?? (kToolbarHeight + statusBar);
        final current = settings?.currentExtent ?? maxExtent;
        final range = (maxExtent - minExtent);
        final t = range <= 0
            ? 0.0
            : ((maxExtent - current) / range).clamp(0.0, 1.0);
        final expandedOpacity = (1 - t * 1.6).clamp(0.0, 1.0);
        final collapsedOpacity = ((t - 0.55) / 0.45).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [top, bottom],
                ),
              ),
            ),
            Positioned(top: -50, right: -40, child: _glow(170, 0.16)),
            Positioned(bottom: -60, left: -30, child: _glow(150, 0.10)),
            // Contenu déplié (masqué une fois replié pour éviter un layout inutile)
            if (expandedOpacity > 0)
              Opacity(
                opacity: expandedOpacity,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: SizedBox(
                          width: constraints.maxWidth - 40,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.28)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(post.serviceType.emoji,
                                        style: const TextStyle(fontSize: 28)),
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: _heroPill(
                                      '${post.postKind.emoji}  ${post.postKind.label}',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  _heroChip(
                                      post.statusIcon, post.statusLabel),
                                  if (post.isUrgent)
                                    _heroChip(LucideIcons.zap, 'Urgent'),
                                  if (post.isNew)
                                    _heroChip(
                                        LucideIcons.sparkles, 'Nouvelle'),
                                  if (post.isExpiringSoon)
                                    _heroChip(
                                        LucideIcons.clock, 'Bientôt expirée'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                post.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.18,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Titre compact (visible une fois replié)
            Positioned(
              top: statusBar,
              left: 56,
              right: 56,
              height: kToolbarHeight,
              child: IgnorePointer(
                child: Opacity(
                  opacity: collapsedOpacity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _glow(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }

  Widget _glassButton(IconData icon, VoidCallback onTap,
      {bool highlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Material(
        color: Colors.white.withValues(alpha: highlighted ? 0.95 : 0.18),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(
              icon,
              size: 19,
              color: highlighted ? DriverHomePalette.primary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Contenu
  // ---------------------------------------------------------------------------

  Widget _content(ServiceExchangePost post) {
    final ref = post.serviceRefLabel;
    final hasMessage =
        post.message != null && post.message!.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 24 + (post.isMine ? MediaQuery.paddingOf(context).bottom : 0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoCard(post, ref),
          if (hasMessage) ...[
            const SizedBox(height: 14),
            _messageCard(post.message!.trim()),
          ],
          const SizedBox(height: 14),
          _statsCard(post),
          const SizedBox(height: 14),
          _authorTile(post),
          if (post.isMine) ...[
            const SizedBox(height: 22),
            _ownerActions(post),
          ],
          if (_similar.isNotEmpty) ...[
            const SizedBox(height: 26),
            const Text(
              'Annonces similaires',
              style: TextStyle(
                color: DriverHomePalette.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            ..._similar.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ServiceExchangeCard(
                    post: p,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ServiceExchangeDetailScreen(postId: p.id),
                      ),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DriverHomePalette.border),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      );

  Widget _infoCard(ServiceExchangePost post, String? ref) {
    final rows = <Widget>[
      _infoRow(LucideIcons.calendarDays, 'Date', post.serviceDateLabel,
          DriverHomePalette.primary),
      _infoRow(LucideIcons.clock, 'Horaires', post.periodLabel,
          DriverHomePalette.blue),
      if (ref != null)
        _infoRow(LucideIcons.bus, 'Service', ref, DriverHomePalette.purple),
      if (post.depotName != null)
        _infoRow(LucideIcons.mapPin, 'Dépôt', post.depotName!,
            DriverHomePalette.warning),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i != 0) const SizedBox(height: 14),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: DriverHomePalette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: DriverHomePalette.textDark,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _messageCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.quote,
                  size: 15, color: DriverHomePalette.primary),
              const SizedBox(width: 7),
              Text(
                'Message',
                style: TextStyle(
                  color: DriverHomePalette.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: DriverHomePalette.primary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: DriverHomePalette.textDark,
                      fontSize: 14.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard(ServiceExchangePost post) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statItem(
                    LucideIcons.eye, '${post.viewCount}', 'Vues'),
              ),
              _statDivider(),
              Expanded(
                child: _statItem(LucideIcons.messageCircle,
                    '${post.contactCount}', 'Propositions'),
              ),
              _statDivider(),
              Expanded(
                child: _statItem(
                    LucideIcons.thumbsUp, '${post.reactionLikes}', 'J\'aime'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: DriverHomePalette.border),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.clock4,
                  size: 13, color: DriverHomePalette.textSecondary),
              const SizedBox(width: 6),
              Text(
                post.relativePublishedLabel,
                style: const TextStyle(
                  color: DriverHomePalette.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: DriverHomePalette.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: DriverHomePalette.textDark,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: DriverHomePalette.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 34,
        color: DriverHomePalette.border,
      );

  Widget _authorTile(ServiceExchangePost post) {
    return Material(
      color: DriverHomePalette.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => showServiceExchangeProfileSheet(context, post.authorId),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DriverHomePalette.border),
            boxShadow: const [
              BoxShadow(
                color: DriverHomePalette.cardShadow,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              DriverAvatarCompact(
                initials: post.authorInitials,
                imageUrl: post.authorAvatarUrl,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorLabel,
                        style: const TextStyle(
                          color: DriverHomePalette.textDark,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 2),
                    const Text('Membre du réseau · Voir le profil',
                        style: TextStyle(
                          color: DriverHomePalette.textSecondary,
                          fontSize: 12.5,
                        )),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: DriverHomePalette.lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.chevronRight,
                    size: 18, color: DriverHomePalette.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerActions(ServiceExchangePost post) {
    final canClose = post.status == ServiceExchangeStatus.active ||
        post.status == ServiceExchangeStatus.inDiscussion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _outlinedAction(
                  LucideIcons.pencil, 'Modifier', _edit),
            ),
            if (post.canRelance) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _outlinedAction(
                    LucideIcons.megaphone, 'Relancer', _relance),
              ),
            ],
          ],
        ),
        if (canClose) ...[
          const SizedBox(height: 10),
          _gradientButton(
            label: 'Marquer comme résolue',
            icon: LucideIcons.circleCheck,
            onTap: _markResolved,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _cancel,
            child: const Text('Annuler l\'annonce',
                style: TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _delete,
          icon: const Icon(LucideIcons.trash2,
              size: 16, color: DriverHomePalette.danger),
          label: const Text('Supprimer l\'annonce',
              style: TextStyle(
                  color: DriverHomePalette.danger,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _outlinedAction(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: DriverHomePalette.textDark,
        side: const BorderSide(color: DriverHomePalette.border),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    double height = 54,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DriverHomePalette.gradientStart,
            DriverHomePalette.gradientEnd,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: DriverHomePalette.primary.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Barre d'action basse
  // ---------------------------------------------------------------------------

  Widget? _bottomBar(ServiceExchangePost post) {
    if (post.isMine || !post.canExpressInterest) return null;
    final liked = post.myReaction == ServiceExchangeReaction.like;
    return Container(
      decoration: const BoxDecoration(
        color: DriverHomePalette.card,
        border: Border(top: BorderSide(color: DriverHomePalette.border)),
        boxShadow: [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Material(
                color: liked
                    ? DriverHomePalette.lightGreen
                    : DriverHomePalette.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: liked
                        ? DriverHomePalette.primary.withValues(alpha: 0.4)
                        : DriverHomePalette.border,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _toggleLike,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Icon(
                      LucideIcons.thumbsUp,
                      size: 20,
                      color: liked
                          ? DriverHomePalette.primary
                          : DriverHomePalette.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _gradientButton(
                  label: 'Contacter',
                  icon: LucideIcons.send,
                  onTap: _contact,
                  height: 54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
