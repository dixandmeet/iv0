import 'package:aule_pro/models/driver/driver_workspace_mode.dart';
import 'package:aule_pro/models/driver/terrain_display_mode.dart';
import 'package:aule_pro/models/driver/terrain_marker.dart';
import 'package:aule_pro/models/driver/terrain_sheet_level.dart';
import 'package:aule_pro/services/driver/terrain_cluster_engine.dart';
import 'package:aule_pro/services/driver/terrain_feed.dart';
import 'package:aule_pro/services/driver/terrain_nearby_service.dart';
import 'package:aule_pro/services/driver/terrain_search_service.dart';
import 'package:aule_pro/services/driver/terrain_selection_controller.dart';
import 'package:aule_pro/services/gtfs_service.dart';
import 'package:aule_pro/services/supabase_service.dart';
import 'package:aule_pro/widgets/driver/driver_map_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared/shared.dart';

void main() {
  group('TerrainDisplayMode', () {
    test('resolve conducteur pour driver en conduite', () {
      expect(
        TerrainDisplayModeX.resolve(
          role: AppUserRole.driver,
          workspace: DriverWorkspaceMode.conduite,
        ),
        TerrainDisplayMode.conducteur,
      );
    });

    test('preset conducteur inclut Assistance dans les filtres', () {
      final mode = TerrainDisplayMode.conducteur;
      expect(mode.visibleFilterLabels, contains('Assistance'));
      expect(mode.defaultLayers.vehicles, isTrue);
    });
  });

  group('TerrainSearchService', () {
    test('score exact match véhicule en premier', () {
      final gtfs = GtfsService(supabaseService: SupabaseService());
      final markers = [
        TerrainMarker(
          id: 'b1',
          type: TerrainMarkerType.bus,
          position: const LatLng(47.22, -1.55),
          updatedAt: DateTime.now(),
          code: 'Bus 54',
          line: '54',
        ),
        TerrainMarker(
          id: 'b2',
          type: TerrainMarkerType.bus,
          position: const LatLng(47.23, -1.56),
          updatedAt: DateTime.now(),
          code: 'Bus 26',
          line: '26',
        ),
      ];

      final categories = TerrainSearchService.search(
        query: '54',
        markers: markers,
        gtfs: gtfs,
        mode: TerrainDisplayMode.conducteur,
      );

      expect(categories, isNotEmpty);
      expect(categories.first.label, 'Véhicules');
      expect(categories.first.results.first.title, contains('54'));
    });
  });

  group('TerrainClusterEngine', () {
    test('tier individual au zoom élevé', () {
      expect(
        TerrainClusterEngine.tierForZoom(16),
        TerrainClusterTier.individual,
      );
    });

    test('cluster global regroupe les marqueurs proches', () {
      final markers = List.generate(
        5,
        (i) => TerrainMarker(
          id: 'm$i',
          type: TerrainMarkerType.bus,
          position: LatLng(47.217 + i * 0.0001, -1.553),
          updatedAt: DateTime.now(),
          line: 'C6',
        ),
      );

      final items = TerrainClusterEngine.cluster(
        markers: markers,
        zoom: 12,
        viewport: null,
      );

      expect(items.length, 1);
      expect(items.first.count, 5);
    });
  });

  group('TerrainNearbyService.statusLabel', () {
    final now = DateTime(2026, 6, 27, 12);

    test('véhicule frais = En service', () {
      final m = TerrainMarker(
        id: 'v',
        type: TerrainMarkerType.bus,
        position: const LatLng(47.22, -1.55),
        updatedAt: now,
        speedKmh: 28,
      );
      expect(TerrainNearbyService.statusLabel(m, now), 'En service');
      expect(TerrainNearbyService.statusDot(m, now), '🟢');
    });

    test('véhicule GPS vieillissant = GPS perdu', () {
      final m = TerrainMarker(
        id: 'v',
        type: TerrainMarkerType.bus,
        position: const LatLng(47.22, -1.55),
        updatedAt: now.subtract(const Duration(minutes: 2)),
      );
      expect(TerrainNearbyService.statusLabel(m, now), 'GPS perdu');
    });

    test('incident n\'est jamais « En service »', () {
      final m = TerrainMarker(
        id: 'i',
        type: TerrainMarkerType.incident,
        position: const LatLng(47.22, -1.55),
        updatedAt: now,
      );
      expect(TerrainNearbyService.statusLabel(m, now), 'Incident');
      expect(TerrainNearbyService.statusDot(m, now), '🔴');
    });

    test('équipe MSR a son propre statut', () {
      final m = TerrainMarker(
        id: 'msr',
        type: TerrainMarkerType.msr,
        position: const LatLng(47.22, -1.55),
        updatedAt: now,
      );
      expect(TerrainNearbyService.statusLabel(m, now), 'MSR en mission');
    });
  });

  group('TerrainFeed itinéraire', () {
    test('un véhicule simulé suit le tracé de sa ligne (ne dérive pas)', () {
      final feed = TerrainFeed();
      const center = LatLng(47.2173, -1.5534);
      feed.seed(center);

      // Tracé horizontal (latitude constante) vers l'est.
      final path = <LatLng>[
        for (var i = 0; i < 25; i++) LatLng(47.2173, -1.5534 + i * 0.001),
      ];
      feed.applyRoutePaths({'C6': path});

      final now = DateTime.now();
      for (var i = 0; i < 400; i++) {
        feed.advance(0.1, now);
      }

      final c6 = feed.snapshot(now).firstWhere((m) => m.line == 'C6');
      // Sur le tracé : la latitude reste celle du tracé (pas d'errance).
      expect((c6.position.latitude - 47.2173).abs(), lessThan(0.0005));
      // Et reste dans les bornes longitudinales du tracé.
      expect(c6.position.longitude, greaterThan(-1.5535));
      expect(c6.position.longitude, lessThan(-1.5534 + 24 * 0.001 + 0.0005));
    });
  });

  group('TerrainSelectionController', () {
    test('selectMarker ouvre le détail', () {
      final ctrl = TerrainSelectionController();
      final m = TerrainMarker(
        id: 'x',
        type: TerrainMarkerType.bus,
        position: const LatLng(0, 0),
        updatedAt: DateTime.now(),
      );
      ctrl.selectMarker(m, expandTo: TerrainSheetLevel.detail);
      expect(ctrl.selectedMarker?.id, 'x');
      expect(ctrl.sheetLevel, TerrainSheetLevel.detail);
      ctrl.dispose();
    });
  });
}
