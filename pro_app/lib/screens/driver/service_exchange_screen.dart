import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/driver_onboarding_data.dart';
import '../../models/driver/service_exchange_filters.dart';
import '../../models/driver/service_exchange_post.dart';
import '../../services/driver/driver_onboarding_service.dart';
import '../../services/driver/service_exchange_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../utils/service_exchange_actions.dart';
import '../../utils/service_exchange_share.dart';
import '../../widgets/driver/driver_filter_chip.dart';
import '../../widgets/driver/service_exchange_card.dart';
import '../../widgets/driver/service_exchange_profile_sheet.dart';
import 'service_exchange_create_screen.dart';
import 'service_exchange_detail_screen.dart';

/// Bourse d'échanges de service.
class ServiceExchangeScreen extends StatefulWidget {
  const ServiceExchangeScreen({super.key});

  @override
  State<ServiceExchangeScreen> createState() => _ServiceExchangeScreenState();
}

class _ServiceExchangeScreenState extends State<ServiceExchangeScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  ServiceExchangeTab _tab = ServiceExchangeTab.available;
  ServiceExchangeMineFilter _mineFilter = ServiceExchangeMineFilter.active;
  ServiceExchangeFilters _filters = const ServiceExchangeFilters();

  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  void _init() {
    final onboarding = context.read<DriverOnboardingService>();
    final service = context.read<ServiceExchangeService>();
    service.configure(
      habilitations: _habilitationsToDb(onboarding.savedData.habilitations),
      networkCode: 'naolib',
    );
    service.fetchStats();
    _reloadCurrent();
  }

  List<String> _habilitationsToDb(Set<DriverHabilitation> habs) {
    if (habs.isEmpty) return const ['conduite'];
    return habs.map((h) => h.name).toList();
  }

  Future<void> _reloadCurrent() async {
    final service = context.read<ServiceExchangeService>();
    switch (_tab) {
      case ServiceExchangeTab.available:
        await service.fetchAvailable(filters: _filters);
        break;
      case ServiceExchangeTab.mine:
        await service.fetchMine(filter: _mineFilter);
        break;
      case ServiceExchangeTab.receivedContacts:
        await service.fetchReceivedContacts();
        break;
    }
  }

  void _switchTab(ServiceExchangeTab tab) {
    setState(() => _tab = tab);
    _reloadCurrent();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ServiceExchangeCreateScreen()),
    );
    if (created == true && mounted) {
      context.read<ServiceExchangeService>().fetchStats();
      _reloadCurrent();
    }
  }

  void _openDetail(ServiceExchangePost post) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ServiceExchangeDetailScreen(postId: post.id),
    )).then((_) {
      if (mounted) _reloadCurrent();
    });
  }

  Future<void> _contact(ServiceExchangePost post) async {
    await ServiceExchangeActions.contactAuthor(context, post);
    if (!mounted) return;
    _reloadCurrent();
  }

  Future<void> _toggleFavorite(ServiceExchangePost post) async {
    await context.read<ServiceExchangeService>().toggleFavorite(post.id);
    _reloadCurrent();
  }

  Future<void> _like(ServiceExchangePost post) async {
    await context
        .read<ServiceExchangeService>()
        .toggleReaction(post.id, ServiceExchangeReaction.like);
  }

  void _applySearch(String value) {
    setState(() => _filters = _filters.copyWith(search: value));
    if (_tab == ServiceExchangeTab.available) {
      context.read<ServiceExchangeService>().fetchAvailable(filters: _filters);
    }
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ServiceExchangeService>();
    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      floatingActionButton: _fab(),
      body: RefreshIndicator(
        onRefresh: _reloadCurrent,
        color: DriverHomePalette.primary,
        edgeOffset: 120,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _hero(service)),
            SliverToBoxAdapter(child: _tabBar()),
            if (_tab == ServiceExchangeTab.available)
              SliverToBoxAdapter(child: _searchBar()),
            if (_tab == ServiceExchangeTab.available)
              SliverToBoxAdapter(child: _filterChips()),
            if (_tab == ServiceExchangeTab.mine)
              SliverToBoxAdapter(child: _mineFilters()),
            ..._buildBody(service),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _fab() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
            color: DriverHomePalette.primary.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _create,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 20, color: Colors.white),
                SizedBox(width: 8),
                Text('Annonce',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  Widget _hero(ServiceExchangeService service) {
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
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
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
              Positioned(bottom: -50, left: -20, child: _glow(140, 0.08)),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _glassButton(
                            LucideIcons.arrowLeft,
                            () => Navigator.of(context).maybePop(),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Échanges de service',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Trouvez ou proposez un échange avec vos collègues',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _statsRow(service),
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

  Widget _statsRow(ServiceExchangeService service) {
    final stats = service.stats;
    return Row(
      children: [
        Expanded(
          child: _statCard('${stats.activeCount}', 'Actives',
              LucideIcons.layoutGrid),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard('${stats.agreedTodayCount}', 'Résolues',
              LucideIcons.circleCheck),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              _statCard('${stats.urgentCount}', 'Urgentes', LucideIcons.zap),
        ),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1,
              )),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11.5,
            ),
          ),
        ],
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

  Widget _glassButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 19, color: Colors.white),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Onglets (segmented control)
  // ---------------------------------------------------------------------------

  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: DriverHomePalette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DriverHomePalette.border),
          boxShadow: const [
            BoxShadow(
              color: DriverHomePalette.cardShadow,
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: ServiceExchangeTab.values.map((tab) {
            final selected = _tab == tab;
            return Expanded(
              child: GestureDetector(
                onTap: () => _switchTab(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: selected
                        ? DriverHomePalette.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: DriverHomePalette.primary
                                  .withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tab.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : DriverHomePalette.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: TextField(
        controller: _searchController,
        onSubmitted: _applySearch,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Rechercher (ligne, service, mot-clé)…',
          prefixIcon: const Icon(LucideIcons.search,
              size: 18, color: DriverHomePalette.textSecondary),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(LucideIcons.x, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    _applySearch('');
                  },
                ),
          filled: true,
          fillColor: DriverHomePalette.card,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: DriverHomePalette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: DriverHomePalette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: DriverHomePalette.primary, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        children: [
          DriverFilterChip(
            label: 'Tous',
            selected: !_filters.hasActiveFilters ||
                (_filters.serviceType == null && _filters.postKind == null),
            onTap: () {
              setState(() => _filters = ServiceExchangeFilters(
                    search: _filters.search,
                  ));
              context
                  .read<ServiceExchangeService>()
                  .fetchAvailable(filters: _filters);
            },
          ),
          const SizedBox(width: 8),
          ...ServiceExchangePostKind.values.map((k) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DriverFilterChip(
                  label: '${k.emoji} ${k.label}',
                  selected: _filters.postKind == k,
                  onTap: () => _toggleKind(k),
                ),
              )),
          ...ServiceExchangeServiceType.values.map((t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DriverFilterChip(
                  label: t.label,
                  selected: _filters.serviceType == t,
                  onTap: () => _toggleType(t),
                ),
              )),
        ],
      ),
    );
  }

  void _toggleKind(ServiceExchangePostKind k) {
    setState(() {
      _filters = _filters.postKind == k
          ? _filters.copyWith(clearPostKind: true)
          : _filters.copyWith(postKind: k);
    });
    context.read<ServiceExchangeService>().fetchAvailable(filters: _filters);
  }

  void _toggleType(ServiceExchangeServiceType t) {
    setState(() {
      _filters = _filters.serviceType == t
          ? _filters.copyWith(clearServiceType: true)
          : _filters.copyWith(serviceType: t);
    });
    context.read<ServiceExchangeService>().fetchAvailable(filters: _filters);
  }

  Widget _mineFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: ServiceExchangeMineFilter.values.map((f) {
          final selected = _mineFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DriverFilterChip(
              label: f.label,
              selected: selected,
              onTap: () {
                setState(() => _mineFilter = f);
                context
                    .read<ServiceExchangeService>()
                    .fetchMine(filter: _mineFilter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Corps
  // ---------------------------------------------------------------------------

  List<Widget> _buildBody(ServiceExchangeService service) {
    if (service.loading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverList.separated(
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, _) => _skeletonCard(),
          ),
        ),
      ];
    }

    final List<ServiceExchangePost> posts = switch (_tab) {
      ServiceExchangeTab.available => service.available,
      ServiceExchangeTab.mine => service.mine,
      ServiceExchangeTab.receivedContacts => service.receivedContacts,
    };

    if (posts.isEmpty) {
      return [SliverToBoxAdapter(child: _emptyState())];
    }

    if (_tab == ServiceExchangeTab.available) {
      return _availableSections(service);
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        sliver: SliverList.separated(
          itemCount: posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _card(posts[i]),
        ),
      ),
    ];
  }

  List<Widget> _availableSections(ServiceExchangeService service) {
    final slivers = <Widget>[];
    final newPosts = service.newPosts;
    final expiring = service.expiringPosts;
    final all = service.available;

    if (newPosts.isNotEmpty) {
      slivers.add(_sectionHeader('Nouvelles annonces', LucideIcons.sparkles,
          DriverHomePalette.primary));
      slivers.add(_sectionList(newPosts));
    }
    if (expiring.isNotEmpty) {
      slivers.add(_sectionHeader(
          'Bientôt expirées', LucideIcons.clock, DriverHomePalette.danger));
      slivers.add(_sectionList(expiring));
    }
    slivers.add(_sectionHeader(
        'Toutes les annonces', LucideIcons.layoutGrid, DriverHomePalette.textDark));
    slivers.add(_sectionList(all));
    return slivers;
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 7),
            Text(
              title,
              style: const TextStyle(
                color: DriverHomePalette.textDark,
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionList(List<ServiceExchangePost> posts) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.separated(
        itemCount: posts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _card(posts[i]),
      ),
    );
  }

  Widget _card(ServiceExchangePost post) {
    return ServiceExchangeCard(
      post: post,
      onTap: () => _openDetail(post),
      onContact: post.isMine ? null : () => _contact(post),
      onFavorite: post.isMine ? null : () => _toggleFavorite(post),
      onShare: () => ServiceExchangeShare.share(post),
      onLike: post.isMine ? null : () => _like(post),
      onAuthorTap: () => showServiceExchangeProfileSheet(context, post.authorId),
    );
  }

  Widget _skeletonCard() {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skel(110, 22, r: 999),
          const SizedBox(height: 14),
          Row(
            children: [
              _skel(46, 46, r: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _skel(double.infinity, 14, r: 7),
                    const SizedBox(height: 8),
                    _skel(140, 12, r: 6),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          _skel(double.infinity, 1, r: 0),
          const SizedBox(height: 12),
          Row(
            children: [
              _skel(90, 14, r: 7),
              const Spacer(),
              _skel(60, 14, r: 7),
            ],
          ),
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

  Widget _emptyState() {
    final (icon, message, cta) = switch (_tab) {
      ServiceExchangeTab.available => (
          LucideIcons.inbox,
          'Aucune annonce compatible pour le moment.\nRevenez plus tard ou publiez la vôtre.',
          true,
        ),
      ServiceExchangeTab.mine => (
          LucideIcons.fileText,
          'Vous n\'avez aucune annonce dans cette catégorie.',
          true,
        ),
      ServiceExchangeTab.receivedContacts => (
          LucideIcons.messageCircle,
          'Personne ne vous a encore contacté.',
          false,
        ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 54, 40, 40),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: DriverHomePalette.lightGreen,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(icon, size: 36, color: DriverHomePalette.primary),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DriverHomePalette.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (cta) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _create,
              style: OutlinedButton.styleFrom(
                foregroundColor: DriverHomePalette.primary,
                side: const BorderSide(color: DriverHomePalette.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(LucideIcons.plus, size: 17),
              label: const Text('Publier une annonce',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}
