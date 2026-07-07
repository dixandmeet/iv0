import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared/shared.dart';

import '../../models/driver/driver_workspace_mode.dart';
import '../../models/driver/terrain_display_mode.dart';
import '../../models/driver/terrain_map_layers.dart';
import '../../models/driver/terrain_marker.dart';
import '../../models/driver/terrain_sheet_level.dart';
import '../../widgets/driver/driver_map_marker.dart';
import 'terrain_search_service.dart';

/// Orchestrateur central de la page Terrain.
///
/// La carte, le radar sheet et la recherche écoutent ce contrôleur au lieu de
/// communiquer directement entre eux.
class TerrainSelectionController extends ChangeNotifier {
  TerrainSelectionController({
    AppUserRole role = AppUserRole.driver,
    DriverWorkspaceMode workspace = DriverWorkspaceMode.conduite,
    bool isRegulator = false,
  }) {
    _displayMode = TerrainDisplayModeX.resolve(
      role: role,
      workspace: workspace,
      isRegulator: isRegulator,
    );
    _layers = _displayMode.defaultLayers;
    _activeFilterLabel = _displayMode.defaultFilterLabel;
    sheetController.addListener(_onSheetDrag);
  }

  final DraggableScrollableController sheetController =
      DraggableScrollableController();

  TerrainMarker? _selectedMarker;
  String? _selectedLineId;
  String? _selectedClusterId;
  TerrainSheetLevel _sheetLevel = TerrainSheetLevel.summary;
  LatLng? _cameraTarget;
  double? _cameraZoom;
  String _activeFilterLabel = 'Tous';
  late TerrainDisplayMode _displayMode;
  late TerrainMapLayers _layers;
  bool _liveEnabled = true;
  String _searchQuery = '';
  double _mapZoom = 14.6;

  TerrainMarker? get selectedMarker => _selectedMarker;
  String? get selectedLineId => _selectedLineId;
  String? get selectedClusterId => _selectedClusterId;
  TerrainSheetLevel get sheetLevel => _sheetLevel;
  LatLng? get cameraTarget => _cameraTarget;
  double? get cameraZoom => _cameraZoom;
  String get activeFilterLabel => _activeFilterLabel;
  TerrainMarkerType? get activeFilterType =>
      terrainFilterTypes[_activeFilterLabel];
  TerrainDisplayMode get displayMode => _displayMode;
  TerrainMapLayers get layers => _layers;
  bool get liveEnabled => _liveEnabled;
  String get searchQuery => _searchQuery;
  double get mapZoom => _mapZoom;

  void _onSheetDrag() {
    if (!sheetController.isAttached) return;
    final size = sheetController.size;
    final next = size <= 0.14
        ? TerrainSheetLevel.summary
        : size <= 0.45
            ? TerrainSheetLevel.list
            : TerrainSheetLevel.detail;
    if (next != _sheetLevel) {
      _sheetLevel = next;
      notifyListeners();
    }
  }

  void setMapZoom(double zoom) {
    if ((_mapZoom - zoom).abs() < 0.05) return;
    _mapZoom = zoom;
    notifyListeners();
  }

  void syncWorkspace({
    required AppUserRole role,
    required DriverWorkspaceMode workspace,
    bool isRegulator = false,
    bool forcePreset = false,
  }) {
    final resolved = TerrainDisplayModeX.resolve(
      role: role,
      workspace: workspace,
      isRegulator: isRegulator,
    );
    if (_displayMode == resolved && !forcePreset) return;
    _displayMode = resolved;
    _layers = resolved.defaultLayers;
    final visible = resolved.visibleFilterLabels;
    if (!visible.contains(_activeFilterLabel)) {
      _activeFilterLabel = resolved.defaultFilterLabel;
    }
    notifyListeners();
  }

  void setDisplayMode(TerrainDisplayMode mode) {
    if (_displayMode == mode) return;
    _displayMode = mode;
    _layers = mode.defaultLayers;
    final visible = mode.visibleFilterLabels;
    if (!visible.contains(_activeFilterLabel)) {
      _activeFilterLabel = mode.defaultFilterLabel;
    }
    notifyListeners();
  }

  void setLayers(TerrainMapLayers layers) {
    if (_layers == layers) return;
    _layers = layers;
    notifyListeners();
  }

  void toggleLayer(String key, bool value) {
    final next = _layers.copyWith(
      vehicles: key == 'vehicles' ? value : _layers.vehicles,
      stations: key == 'stations' ? value : _layers.stations,
      incidents: key == 'incidents' ? value : _layers.incidents,
      lines: key == 'lines' ? value : _layers.lines,
      releves: key == 'releves' ? value : _layers.releves,
      controle: key == 'controle' ? value : _layers.controle,
      msr: key == 'msr' ? value : _layers.msr,
      zones: key == 'zones' ? value : _layers.zones,
    );
    setLayers(next);
  }

  void setFilterLabel(String label) {
    if (_activeFilterLabel == label) return;
    _activeFilterLabel = label;
    notifyListeners();
  }

  void setLiveEnabled(bool enabled) {
    if (_liveEnabled == enabled) return;
    _liveEnabled = enabled;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void selectMarker(
    TerrainMarker marker, {
    TerrainSheetLevel? expandTo,
  }) {
    _selectedMarker = marker;
    _selectedClusterId = null;
    if (marker.line != null) {
      _selectedLineId = marker.line;
    }
    _cameraTarget = marker.position;
    _cameraZoom ??= 15.4;
    final level = expandTo ?? TerrainSheetLevel.detail;
    setSheetLevel(level, animate: true);
    notifyListeners();
  }

  void selectLine(String? routeId) {
    _selectedLineId = routeId;
    notifyListeners();
  }

  void expandCluster(String clusterId, LatLng center, {double? zoom}) {
    _selectedClusterId = clusterId;
    _cameraTarget = center;
    _cameraZoom = zoom ?? (_mapZoom + 2).clamp(11.0, 18.0);
    notifyListeners();
  }

  void centerOn(LatLng position, {double? zoom}) {
    _cameraTarget = position;
    _cameraZoom = zoom ?? _cameraZoom ?? 15.4;
    notifyListeners();
  }

  void clearCameraRequest() {
    _cameraTarget = null;
    _cameraZoom = null;
  }

  void setSheetLevel(TerrainSheetLevel level, {bool animate = false}) {
    _sheetLevel = level;
    notifyListeners();
    if (!sheetController.isAttached) return;
    final target = level == TerrainSheetLevel.detail
        ? level.maxSnapSize
        : level.snapSize;
    if (animate) {
      sheetController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      sheetController.jumpTo(target);
    }
  }

  void applySearchResult(TerrainSearchResult result) {
    switch (result.kind) {
      case TerrainSearchResultKind.vehicle:
      case TerrainSearchResultKind.agent:
        if (result.marker != null) {
          selectMarker(result.marker!, expandTo: TerrainSheetLevel.detail);
        }
      case TerrainSearchResultKind.line:
        selectLine(result.lineId);
        if (result.position != null) {
          centerOn(result.position!, zoom: 14.0);
        }
      case TerrainSearchResultKind.station:
      case TerrainSearchResultKind.stop:
        if (result.marker != null) {
          selectMarker(result.marker!, expandTo: TerrainSheetLevel.list);
        } else if (result.position != null) {
          centerOn(result.position!, zoom: 15.0);
          setSheetLevel(TerrainSheetLevel.list, animate: true);
        }
    }
    _searchQuery = '';
    notifyListeners();
  }

  void clearSelection() {
    _selectedMarker = null;
    _selectedClusterId = null;
    setSheetLevel(TerrainSheetLevel.summary, animate: true);
    notifyListeners();
  }

  void updateSelectedMarker(TerrainMarker? marker) {
    if (marker?.id == _selectedMarker?.id) {
      _selectedMarker = marker;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    sheetController.removeListener(_onSheetDrag);
    sheetController.dispose();
    super.dispose();
  }
}
