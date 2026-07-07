import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import '../../../models/driver/terrain_display_mode.dart';
import '../../../models/driver/control_plan_context.dart';
import '../../../models/driver/terrain_marker.dart';
import '../../../models/driver/terrain_sheet_level.dart';
import '../../../models/driver/terrain_user_marker_style.dart';
import '../../../models/gtfs.dart';
import '../../../services/driver/driver_onboarding_service.dart';
import '../../../services/driver/control_plan_service.dart';
import '../../../services/driver/driver_workspace_service.dart';
import '../../../services/driver/terrain_feed.dart';
import '../../../services/driver/terrain_nearby_service.dart';
import '../../../services/driver/terrain_search_service.dart';
import '../../../services/driver/terrain_selection_controller.dart';
import '../../../services/gtfs_service.dart';
import '../../../services/location_service.dart';
import '../../../services/msr/msr_mission_service.dart';
import '../../../services/supabase_service.dart';
import '../../../utils/terrain_stop_utils.dart';
import '../../../widgets/driver/terrain/terrain_fab_buttons.dart';
import '../../../widgets/driver/terrain/terrain_filter_bar.dart';
import '../../../widgets/driver/terrain/terrain_header.dart';
import '../../../widgets/driver/terrain/terrain_layers_panel.dart';
import '../../../widgets/driver/terrain/terrain_search_field.dart';
import '../../../widgets/driver/terrain/terrain_search_overlay.dart';
import '../../../widgets/driver/terrain/terrain_stats_banner.dart';
import 'terrain_map.dart';
import 'terrain_radar_sheet.dart';

/// Onglet « Terrain » — centre de commandement temps réel.
class DriverTerrainScreen extends StatefulWidget {
  final bool isActive;

  const DriverTerrainScreen({super.key, this.isActive = true});

  @override
  State<DriverTerrainScreen> createState() => _DriverTerrainScreenState();
}

class _DriverTerrainScreenState extends State<DriverTerrainScreen> {
  late final TerrainSelectionController _controller;
  final _mapKey = GlobalKey<TerrainMapState>();

  List<GtfsStation> _stations = const [];
  List<GtfsRoute> _highlightRoutes = const [];
  Map<String, List<LatLng>> _routePaths = const {};
  List<LatLng>? _walkingRoute;
  bool _searchExpanded = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = TerrainSelectionController();
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshLocation();
        _loadStations();
        _syncWorkspace();
      });
    }
  }

  @override
  void didUpdateWidget(covariant DriverTerrainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _refreshLocation();
      _loadStations();
      _syncWorkspace();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWorkspace();
  }

  void _syncWorkspace() {
    final workspace = context.read<DriverWorkspaceService>().currentMode;
    _controller.syncWorkspace(role: AppUserRole.driver, workspace: workspace);
  }

  Future<void> _loadStations() async {
    if (!mounted) return;
    final gtfs = context.read<GtfsService>();
    if (gtfs.cachedStations.isEmpty) await gtfs.fetchStops();
    if (gtfs.cachedRoutes.isEmpty) await gtfs.fetchRoutes();
    if (!mounted) return;
    setState(() {
      _stations = gtfs.cachedStations;
      _routePaths = _buildRoutePaths(gtfs);
    });
  }

  /// Tracé GTFS (plus long tronçon) de chaque ligne simulée, indexé par son
  /// libellé (qui correspond désormais au libellé GTFS réel).
  Map<String, List<LatLng>> _buildRoutePaths(GtfsService gtfs) {
    final out = <String, List<LatLng>>{};
    for (final line in kTerrainSimLines) {
      GtfsRoute? route;
      for (final r in gtfs.cachedRoutes) {
        if (r.routeShortName == line || r.routeId == line) {
          route = r;
          break;
        }
      }
      if (route == null) continue;
      List<LatLng>? longest;
      for (final seg in route.shapes) {
        if (seg.length < 2) continue;
        if (longest == null || seg.length > longest.length) longest = seg;
      }
      if (longest != null && longest.length >= 2) out[line] = longest;
    }
    return out;
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;
    await context.read<LocationService>().refreshIfPermitted();
  }

  Future<void> _recenterOnUser() async {
    final loc = context.read<LocationService>();
    final granted = await loc.requestForegroundPermission();
    if (!mounted) return;
    if (!granted) {
      _snack('Autorisation de localisation requise');
      return;
    }
    final pos = await loc.updateCurrentPosition() ?? loc.currentPosition;
    if (!mounted || pos == null) {
      _snack('Impossible d\'obtenir votre position');
      return;
    }
    _mapKey.currentState?.recenterOnUser(LatLng(pos.latitude, pos.longitude));
  }

  Future<void> _requestAssistance() async {
    final st = _mapKey.currentState;
    if (st == null) return;
    if (!st.hasUserPosition) {
      _snack('Position GPS requise pour demander de l\'aide');
      return;
    }
    final ok = await st.sendAssistance();
    if (!mounted) return;
    _snack(
      ok ? 'Demande d\'assistance envoyée' : 'Échec de l\'envoi de la demande',
    );
  }

  void _onMarkerTapped(TerrainMarker m) {
    _controller.selectMarker(m, expandTo: TerrainSheetLevel.detail);
    if (m.line != null) {
      final gtfs = context.read<GtfsService>();
      for (final r in gtfs.cachedRoutes) {
        if (r.routeShortName == m.line || r.routeId == m.line) {
          setState(() => _highlightRoutes = [r]);
          _controller.selectLine(r.routeId);
          break;
        }
      }
    }
  }

  void _onDetailAction(TerrainDetailAction action) {
    switch (action) {
      case TerrainDetailAction.viewLine:
        final m = _controller.selectedMarker;
        if (m?.line != null) {
          final gtfs = context.read<GtfsService>();
          for (final r in gtfs.cachedRoutes) {
            if (r.routeShortName == m!.line || r.routeId == m.line) {
              setState(() {
                _highlightRoutes = [r];
                _controller.selectLine(r.routeId);
                _controller.toggleLayer('lines', true);
              });
              break;
            }
          }
        }
      case TerrainDetailAction.follow:
      case TerrainDetailAction.join:
      case TerrainDetailAction.contact:
      case TerrainDetailAction.share:
      case TerrainDetailAction.alert:
      case TerrainDetailAction.comments:
      case TerrainDetailAction.history:
      case TerrainDetailAction.route:
        _snack('${action.label} — bientôt disponible');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  List<TerrainSearchCategory> _searchCategories(LatLng? userPos) {
    final markers = _mapKey.currentState?.snapshotNow() ?? const [];
    return TerrainSearchService.search(
      query: _searchQuery,
      markers: markers,
      gtfs: context.read<GtfsService>(),
      from: userPos,
      mode: _controller.displayMode,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationService>();
    final workspace = context.watch<DriverWorkspaceService>();
    _controller.syncWorkspace(
      role: AppUserRole.driver,
      workspace: workspace.currentMode,
    );

    final pos = loc.currentPosition;
    final userPos = pos == null ? null : LatLng(pos.latitude, pos.longitude);
    final accuracy = pos?.accuracy;
    final userHeading = resolveUserHeadingDeg(pos?.heading);
    final onboarding = context.watch<DriverOnboardingService>();
    final msrMissions = context.watch<MsrMissionService>();
    final controlMission = context.watch<ControlPlanService>().currentMission;
    final userMarkerStyle = resolveUserMarkerStyle(
      workspace: workspace.currentMode,
      gender: onboarding.savedData.gender,
      hasActiveMission:
          msrMissions.hasActiveMissionForCurrentUser ||
          controlMission?.status == ControlMissionStatus.inProgress,
    );
    final client = context.read<SupabaseService>().client;
    final gtfs = context.watch<GtfsService>();

    final linePolylines =
        _highlightRoutes.isNotEmpty && _controller.layers.lines
        ? transitLinePolylines(gtfs, _highlightRoutes)
        : const <Polyline>[];

    final markers = _mapKey.currentState?.snapshotNow() ?? const [];
    final stats = TerrainNearbyService.computeStats(
      markers: markers,
      userPosition: userPos,
    );

    final topInset = MediaQuery.paddingOf(context).top;
    const summarySnapSize = 0.11;

    return ChangeNotifierProvider<TerrainSelectionController>.value(
      value: _controller,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bodyH = constraints.maxHeight;
          return SizedBox(
            width: constraints.maxWidth,
            height: bodyH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: TerrainMap(
                    key: _mapKey,
                    userPosition: userPos,
                    userAccuracyMeters: accuracy,
                    userMarkerStyle: userMarkerStyle,
                    userHeadingDeg: userHeading,
                    controller: _controller,
                    supabaseClient: client,
                    stations: _stations,
                    linePolylines: linePolylines,
                    walkingRoute: _walkingRoute,
                    routePaths: _routePaths,
                    onMarkerTapped: _onMarkerTapped,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: topInset + 130,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xF2F7FAF8), Color(0x00F7FAF8)],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TerrainHeader(
                            onFilters: () =>
                                TerrainLayersPanel.show(context, _controller),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: TerrainSearchField(
                              query: _searchQuery,
                              expanded: _searchExpanded,
                              onChanged: (q) => setState(() {
                                _searchQuery = q;
                                _searchExpanded = q.isNotEmpty;
                              }),
                              onClear: () => setState(() {
                                _searchQuery = '';
                                _searchExpanded = false;
                              }),
                            ),
                          ),
                          if (_searchExpanded && _searchQuery.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                              child: TerrainSearchOverlay(
                                categories: _searchCategories(userPos),
                                onResultTap: (r) {
                                  setState(() {
                                    _searchExpanded = false;
                                    _searchQuery = '';
                                  });
                                  _controller.applySearchResult(r);
                                },
                                onClose: () => setState(() {
                                  _searchExpanded = false;
                                }),
                              ),
                            ),
                          const SizedBox(height: 10),
                          ListenableBuilder(
                            listenable: _controller,
                            builder: (_, _) => TerrainFilterBar(
                              filters:
                                  _controller.displayMode.visibleFilterLabels,
                              selected: _controller.activeFilterLabel,
                              onSelected: _controller.setFilterLabel,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListenableBuilder(
                            listenable: _controller,
                            builder: (_, _) => TerrainStatsBanner(
                              stats: stats,
                              displayMode: _controller.displayMode,
                              mapZoom: _controller.mapZoom,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: _controller.sheetController,
                  builder: (context, _) {
                    final ext = _controller.sheetController.isAttached
                        ? _controller.sheetController.size
                        : summarySnapSize;
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: bodyH * ext + 12,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: TerrainHelpFab(onTap: _requestAssistance),
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: TerrainLocateButton(
                                onTap: _recenterOnUser,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                DraggableScrollableSheet(
                  controller: _controller.sheetController,
                  initialChildSize: summarySnapSize,
                  minChildSize: summarySnapSize,
                  maxChildSize: TerrainSheetLevel.detail.maxSnapSize,
                  snap: true,
                  snapSizes: const [0.11, 0.35, 0.65, 0.92],
                  builder: (context, scrollController) {
                    return ListenableBuilder(
                      listenable: _controller,
                      builder: (_, _) => TerrainRadarSheet(
                        controller: _controller,
                        markers:
                            _mapKey.currentState?.snapshotNow() ?? const [],
                        userPosition: userPos,
                        scrollController: scrollController,
                        onDetailAction: _onDetailAction,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
