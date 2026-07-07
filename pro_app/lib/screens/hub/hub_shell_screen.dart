import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../../services/auth_service.dart';
import '../../services/platform/hub_engine.dart';
import '../../theme/driver_home_palette.dart';
import '../resource/resource_shell_screen.dart';
import 'channel_discussion_screen.dart';

/// Shell Hub — vues Activité / Discussions / Notifications.
class HubShellScreen extends StatefulWidget {
  const HubShellScreen({super.key, this.initialView});

  /// Vue ouverte à l'arrivée (par défaut : Activité). Permet d'ouvrir
  /// directement les Notifications depuis le tap d'une bannière.
  final HubView? initialView;

  @override
  State<HubShellScreen> createState() => _HubShellScreenState();
}

class _HubShellScreenState extends State<HubShellScreen> {
  // Tâches/Documents sont retirés tant qu'aucun flux ne permet d'en créer
  // (onglets garantis vides — cf. audit).
  static const _views = [
    HubView.activity,
    HubView.discussions,
    HubView.notifications,
  ];

  TabController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final hub = context.read<HubEngine>();
    final auth = context.read<AuthService>();
    final userId = auth.profile?.id;
    if (userId != null) hub.subscribeRealtime(userId);
    final initial = widget.initialView;
    if (initial != null && initial != hub.view) {
      await hub.setView(initial);
    } else {
      await hub.refresh();
    }
    await hub.refreshCounts();
  }

  // Synchronise le moteur Hub avec les changements d'onglet (tap ET swipe).
  void _bind(TabController controller) {
    if (identical(_controller, controller)) return;
    _controller = controller;
    controller.addListener(() {
      if (controller.indexIsChanging) return;
      if (!mounted) return;
      context.read<HubEngine>().setView(_views[controller.index]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubEngine>();

    return DefaultTabController(
      length: _views.length,
      initialIndex: _views.indexOf(widget.initialView ?? HubView.activity),
      child: Scaffold(
        backgroundColor: DriverHomePalette.background,
        body: Builder(
          builder: (context) {
            final controller = DefaultTabController.of(context);
            _bind(controller);
            return Column(
              children: [
                _hero(context, controller, hub),
                Expanded(
                  child: TabBarView(
                    controller: controller,
                    children: [
                      _ActivityTab(
                        events: hub.activity,
                        loading:
                            hub.loading && !hub.hasLoaded(HubView.activity),
                        error: hub.error,
                      ),
                      _DiscussionsTab(
                        items: hub.discussions,
                        loading:
                            hub.loading && !hub.hasLoaded(HubView.discussions),
                      ),
                      _NotificationsTab(
                        items: hub.notifications,
                        loading: hub.loading &&
                            !hub.hasLoaded(HubView.notifications),
                        onRead: hub.markNotificationRead,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  Widget _hero(BuildContext context, TabController controller, HubEngine hub) {
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
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
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
                          const Expanded(
                            child: Text(
                              'Activité',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: controller,
                            builder: (context, _) {
                              final onNotifs = controller.index == 2;
                              if (!onNotifs ||
                                  hub.unreadNotificationCount == 0) {
                                return const SizedBox.shrink();
                              }
                              return _GlassPillButton(
                                label: 'Tout lire',
                                onTap: hub.markAllNotificationsRead,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Row(
                              children: [
                                _heroTab(controller, 0, 'Activité'),
                                _heroTab(controller, 1, 'Discussions',
                                    count: hub.unreadDiscussionCount),
                                _heroTab(controller, 2, 'Notifications',
                                    count: hub.unreadNotificationCount),
                              ],
                            ),
                          );
                        },
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

  Widget _heroTab(
    TabController controller,
    int index,
    String label, {
    int count = 0,
  }) {
    final selected = controller.index == index;
    return GestureDetector(
      onTap: () {
        controller.animateTo(index);
        context.read<HubEngine>().setView(_views[index]);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0 : 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? DriverHomePalette.primary : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 7),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: selected
                      ? DriverHomePalette.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : DriverHomePalette.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
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

// ---------------------------------------------------------------------------
// Helpers partagés
// ---------------------------------------------------------------------------

String _timeAgo(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inSeconds < 60) return 'à l\'instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  return DateFormat('d MMM', 'fr_FR').format(date);
}

BoxDecoration _hubCard({Color? color}) => BoxDecoration(
      color: color ?? DriverHomePalette.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: DriverHomePalette.border),
      boxShadow: const [
        BoxShadow(
          color: DriverHomePalette.cardShadow,
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    );

/// Bouton circulaire « en verre » pour le hero (retour, etc.).
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

/// Bouton-texte « en verre » (ex : « Tout lire »).
class _GlassPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GlassPillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    // ListView pour conserver le pull-to-refresh même quand c'est vide.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.16),
        Center(
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: DriverHomePalette.lightGreen,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 34, color: DriverHomePalette.primary),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Indicateur de chargement centré, discret.
class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: DriverHomePalette.primary),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglet Activité
// ---------------------------------------------------------------------------

class _ActivityTab extends StatelessWidget {
  final List<PlatformResourceEvent> events;
  final bool loading;
  final String? error;

  const _ActivityTab({
    required this.events,
    required this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Loader();
    return RefreshIndicator(
      color: DriverHomePalette.primary,
      onRefresh: () =>
          context.read<HubEngine>().refresh(viewOverride: HubView.activity),
      child: error != null
          ? _EmptyState(icon: LucideIcons.triangleAlert, message: error!)
          : events.isEmpty
              ? const _EmptyState(
                  icon: LucideIcons.activity,
                  message: 'Aucune activité récente',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ActivityTile(event: events[i]),
                ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final PlatformResourceEvent event;

  const _ActivityTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final label = _labelForEvent(event.eventType);
    final isMessage = event.eventType == 'message';
    final critical =
        event.priority == 'high' || event.priority == 'critical';

    return Container(
      decoration: _hubCard(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: event.resourceId.isNotEmpty
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ResourceShellScreen(resourceId: event.resourceId),
                    ),
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: critical
                        ? DriverHomePalette.danger.withValues(alpha: 0.12)
                        : DriverHomePalette.lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconForEvent(event.eventType),
                    size: 21,
                    color: critical
                        ? DriverHomePalette.danger
                        : DriverHomePalette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.resourceName ?? label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: DriverHomePalette.textDark,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isMessage ? event.preview : label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: DriverHomePalette.textSecondary,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _timeAgo(event.createdAt),
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForEvent(String type) {
    switch (type) {
      case 'message':
        return LucideIcons.messageCircle;
      case 'task_created':
        return LucideIcons.listChecks;
      case 'team_synced':
        return LucideIcons.users;
      case 'member_joined':
        return LucideIcons.userPlus;
      case 'resource_created':
        return LucideIcons.sparkles;
      default:
        return LucideIcons.activity;
    }
  }

  String _labelForEvent(String type) {
    switch (type) {
      case 'message':
        return 'Nouveau message';
      case 'task_created':
        return 'Nouvelle tâche';
      case 'team_synced':
        return 'Équipe mise à jour';
      case 'member_joined':
        return 'Nouveau membre';
      case 'resource_created':
        return 'Nouvel espace';
      default:
        return 'Activité';
    }
  }
}

// ---------------------------------------------------------------------------
// Onglet Discussions
// ---------------------------------------------------------------------------

class _DiscussionsTab extends StatelessWidget {
  final List<HubDiscussion> items;
  final bool loading;

  const _DiscussionsTab({required this.items, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Loader();
    return RefreshIndicator(
      color: DriverHomePalette.primary,
      onRefresh: () =>
          context.read<HubEngine>().refresh(viewOverride: HubView.discussions),
      child: items.isEmpty
          ? const _EmptyState(
              icon: LucideIcons.messagesSquare,
              message: 'Aucune discussion',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) =>
                  _DiscussionTile(discussion: items[i]),
            ),
    );
  }
}

class _DiscussionTile extends StatelessWidget {
  final HubDiscussion discussion;

  const _DiscussionTile({required this.discussion});

  void _open(BuildContext context) {
    final hub = context.read<HubEngine>();
    final resourceId = discussion.resourceId;
    final route = resourceId != null
        ? MaterialPageRoute(
            builder: (_) => ResourceShellScreen(resourceId: resourceId),
          )
        : MaterialPageRoute(
            builder: (_) => ChannelDiscussionScreen(
              channelId: discussion.channelId,
              title: discussion.name,
            ),
          );
    Navigator.of(context).push(route).then((_) {
      // Au retour, les compteurs ont pu changer (lecture).
      hub.refreshCounts();
      hub.refresh(viewOverride: HubView.discussions);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = discussion.hasUnread;
    return Container(
      decoration: _hubCard(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: DriverHomePalette.softGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconForType(discussion.type),
                    size: 22,
                    color: DriverHomePalette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        discussion.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600,
                          color: DriverHomePalette.textDark,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        discussion.lastBody?.trim().isNotEmpty == true
                            ? discussion.lastBody!
                            : 'Aucun message',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread
                              ? DriverHomePalette.textDark
                              : DriverHomePalette.textSecondary,
                          fontSize: 13.5,
                          fontWeight:
                              unread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (discussion.lastAt != null)
                      Text(
                        _timeAgo(discussion.lastAt!),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: unread
                              ? DriverHomePalette.primary
                              : DriverHomePalette.textSecondary,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (unread)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: DriverHomePalette.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          discussion.unreadCount > 99
                              ? '99+'
                              : '${discussion.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'team':
        return LucideIcons.users;
      case 'mission':
        return LucideIcons.target;
      case 'support':
        return LucideIcons.headphones;
      case 'network':
        return LucideIcons.radio;
      case 'direct':
        return LucideIcons.user;
      case 'vehicle':
        return LucideIcons.bus;
      case 'control_plan':
        return LucideIcons.clipboardList;
      default:
        return LucideIcons.messageCircle;
    }
  }
}

// ---------------------------------------------------------------------------
// Onglet Notifications
// ---------------------------------------------------------------------------

class _NotificationsTab extends StatelessWidget {
  final List<PlatformNotification> items;
  final bool loading;
  final Future<void> Function(String id) onRead;

  const _NotificationsTab({
    required this.items,
    required this.loading,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _Loader();
    return RefreshIndicator(
      color: DriverHomePalette.primary,
      onRefresh: () => context
          .read<HubEngine>()
          .refresh(viewOverride: HubView.notifications),
      child: items.isEmpty
          ? const _EmptyState(
              icon: LucideIcons.bell,
              message: 'Aucune notification',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = items[i];
                final critical =
                    n.priority == 'high' || n.priority == 'critical';
                return Container(
                  decoration: _hubCard(
                    color: n.isUnread ? DriverHomePalette.lightGreen : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await onRead(n.id);
                        if (n.resourceId != null && context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ResourceShellScreen(
                                resourceId: n.resourceId!,
                              ),
                            ),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: critical
                                    ? DriverHomePalette.danger
                                        .withValues(alpha: 0.12)
                                    : DriverHomePalette.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: DriverHomePalette.border,
                                ),
                              ),
                              child: Icon(
                                _iconForCategory(n.category, critical),
                                size: 20,
                                color: critical
                                    ? DriverHomePalette.danger
                                    : DriverHomePalette.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: TextStyle(
                                      fontWeight: n.isUnread
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: DriverHomePalette.textDark,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (n.body != null &&
                                      n.body!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      n.body!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color:
                                            DriverHomePalette.textSecondary,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    _timeAgo(n.createdAt),
                                    style: const TextStyle(
                                      color: DriverHomePalette.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (n.isUnread)
                              Container(
                                margin: const EdgeInsets.only(top: 4, left: 6),
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: DriverHomePalette.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  IconData _iconForCategory(NotificationCategory category, bool critical) {
    if (critical) return LucideIcons.triangleAlert;
    switch (category) {
      case NotificationCategory.message:
        return LucideIcons.messageCircle;
      case NotificationCategory.alert:
        return LucideIcons.triangleAlert;
      case NotificationCategory.activity:
      case NotificationCategory.unknown:
        return LucideIcons.activity;
    }
  }
}

// Onglets Tâches/Documents retirés (cf. audit — jamais alimentés, aucun flux
// de création de tâche/upload de fichier n'existe côté app).
