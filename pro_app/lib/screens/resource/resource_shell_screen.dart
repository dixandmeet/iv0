import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../../core/panel_registry.dart';
import '../../services/platform/resource_service.dart';
import '../../theme/driver_home_palette.dart';
import '../../widgets/resource_panels/context_banner.dart';
import '../../widgets/resource_panels/discussion_panel.dart';
import '../../widgets/resource_panels/documents_panel.dart';
import '../../widgets/resource_panels/map_panel.dart';
import '../../widgets/resource_panels/members_panel.dart';
import '../../widgets/resource_panels/tasks_panel.dart';
import '../../widgets/resource_panels/timeline_panel.dart';

/// Fiche ressource composée de panels (Resource-first).
class ResourceShellScreen extends StatefulWidget {
  final String resourceId;

  const ResourceShellScreen({super.key, required this.resourceId});

  @override
  State<ResourceShellScreen> createState() => _ResourceShellScreenState();
}

class _ResourceShellScreenState extends State<ResourceShellScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _tabLength = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ResourceService>().loadShell(widget.resourceId);
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  TabController _ensureTabController(int length) {
    if (_tabController != null && _tabLength == length) {
      return _tabController!;
    }
    _tabController?.dispose();
    _tabLength = length;
    _tabController = TabController(length: length, vsync: this)
      ..addListener(_onTabChanged);
    return _tabController!;
  }

  void _clearTabController() {
    if (_tabController == null) return;
    _tabController!.removeListener(_onTabChanged);
    _tabController!.dispose();
    _tabController = null;
    _tabLength = 0;
  }

  void _onTabChanged() {
    if (_tabController?.indexIsChanging ?? true) return;
    setState(() {});
  }

  Future<void> _toggleWatch(ResourceService service, bool isWatching) async {
    final messenger = ScaffoldMessenger.of(context);
    if (isWatching) {
      await service.unwatchResource(widget.resourceId);
    } else {
      await service.watchResource(widget.resourceId);
    }
    await service.loadShell(widget.resourceId);
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isWatching
                ? 'Vous ne suivez plus cette ressource'
                : 'Vous suivez désormais cette ressource',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ResourceService>();
    final shell = service.shell;

    if (service.loading && shell == null) {
      return Scaffold(
        backgroundColor: DriverHomePalette.background,
        appBar: _gradientAppBar(context, title: 'Chargement…'),
        body: const Center(
          child: CircularProgressIndicator(color: DriverHomePalette.primary),
        ),
      );
    }

    if (shell == null) {
      return Scaffold(
        backgroundColor: DriverHomePalette.background,
        appBar: _gradientAppBar(context, title: 'Ressource'),
        body: Center(
          child: Text(
            service.error ?? 'Ressource introuvable',
            style: const TextStyle(color: DriverHomePalette.textSecondary),
          ),
        ),
      );
    }

    var panels = PanelRegistry.resolve(shell: shell);
    if (panels.isEmpty) {
      panels = PanelRegistry.fallbackForType(shell.resource.type);
    }

    final tabPanels = panels.where((p) => p.panel != 'context').toList();
    final tabController =
        tabPanels.length > 1 ? _ensureTabController(tabPanels.length) : null;
    if (tabPanels.length <= 1) {
      _clearTabController();
    }

    final isWatching = shell.watcher != null;

    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      appBar: _gradientAppBar(
        context,
        title: shell.resource.name,
        actions: [
          IconButton(
            icon: Icon(isWatching ? LucideIcons.bellOff : LucideIcons.bell),
            color: Colors.white,
            onPressed: () => _toggleWatch(service, isWatching),
            tooltip: isWatching ? 'Ne plus suivre' : 'Suivre',
          ),
        ],
        bottom: tabController != null
            ? TabBar(
                controller: tabController,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: tabPanels
                    .map((p) => Tab(text: _labelForPanel(p.panel)))
                    .toList(),
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContextBanner(resource: shell.resource, graph: service.graph),
          Expanded(
            child: tabPanels.isEmpty
                ? DiscussionPanel(
                    resourceId: widget.resourceId,
                    channelId: shell.channelId,
                  )
                : _buildPanel(
                    tabPanels[
                        (tabController?.index ?? 0).clamp(0, tabPanels.length - 1)],
                    shell,
                  ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _gradientAppBar(
    BuildContext context, {
    required String title,
    List<Widget>? actions,
    TabBar? bottom,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: actions,
      bottom: bottom,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              DriverHomePalette.gradientStart,
              DriverHomePalette.gradientEnd,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(PanelLayoutEntry entry, ResourceShellData shell) {
    switch (entry.panel) {
      case 'discussion':
        return DiscussionPanel(
          resourceId: widget.resourceId,
          channelId: shell.channelId,
        );
      case 'timeline':
        return TimelinePanel(resourceId: widget.resourceId);
      case 'map':
        return MapPanel(resource: shell.resource);
      case 'tasks':
        return TasksPanel(channelId: shell.channelId);
      case 'documents':
        return DocumentsPanel(channelId: shell.channelId);
      case 'members':
        return MembersPanel(channelId: shell.channelId);
      default:
        return DiscussionPanel(
          resourceId: widget.resourceId,
          channelId: shell.channelId,
        );
    }
  }

  String _labelForPanel(String panel) {
    switch (panel) {
      case 'discussion':
        return 'Discussion';
      case 'timeline':
        return 'Chronologie';
      case 'map':
        return 'Carte';
      case 'tasks':
        return 'Tâches';
      case 'documents':
        return 'Documents';
      case 'members':
        return 'Membres';
      default:
        return panel;
    }
  }
}
