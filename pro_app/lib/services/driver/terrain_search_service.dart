import 'package:latlong2/latlong.dart';

import '../../models/driver/terrain_display_mode.dart';
import '../../models/driver/terrain_marker.dart';
import '../../models/gtfs.dart';
import '../../services/gtfs_service.dart';
import '../../widgets/driver/driver_map_marker.dart';

enum TerrainSearchResultKind { vehicle, line, station, stop, agent }

class TerrainSearchResult {
  final TerrainSearchResultKind kind;
  final String title;
  final String subtitle;
  final int score;
  final TerrainMarker? marker;
  final String? lineId;
  final LatLng? position;

  const TerrainSearchResult({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.score,
    this.marker,
    this.lineId,
    this.position,
  });
}

class TerrainSearchCategory {
  final String label;
  final int priority;
  final List<TerrainSearchResult> results;

  const TerrainSearchCategory({
    required this.label,
    required this.priority,
    required this.results,
  });
}

/// Recherche universelle avec scoring de pertinence.
class TerrainSearchService {
  static const _distance = Distance();

  static List<TerrainSearchCategory> search({
    required String query,
    required List<TerrainMarker> markers,
    required GtfsService gtfs,
    LatLng? from,
    TerrainDisplayMode mode = TerrainDisplayMode.conducteur,
    int limitPerCategory = 5,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final vehicles = <TerrainSearchResult>[];
    final lines = <TerrainSearchResult>[];
    final stations = <TerrainSearchResult>[];
    final agents = <TerrainSearchResult>[];

    for (final m in markers) {
      if (m.type == TerrainMarkerType.bus || m.type == TerrainMarkerType.tram) {
        final score = _scoreMarker(m, q, from, mode.searchPriorityType);
        if (score > 0) {
          vehicles.add(TerrainSearchResult(
            kind: TerrainSearchResultKind.vehicle,
            title: m.title,
            subtitle: _vehicleSubtitle(m, from),
            score: score,
            marker: m,
            position: m.position,
          ));
        }
      } else if (m.type == TerrainMarkerType.controle ||
          m.type == TerrainMarkerType.msr) {
        final score = _scoreText(m.code ?? '', m.detail ?? '', q, from, m.position);
        if (score > 0) {
          agents.add(TerrainSearchResult(
            kind: TerrainSearchResultKind.agent,
            title: m.title,
            subtitle: _distanceLabel(from, m.position),
            score: score + (mode == TerrainDisplayMode.intervention ? 10 : 0),
            marker: m,
            position: m.position,
          ));
        }
      }
    }

    for (final route in gtfs.searchRoutes(q, limit: limitPerCategory * 2)) {
      final score = _scoreRoute(route, q);
      if (score > 0) {
        lines.add(TerrainSearchResult(
          kind: TerrainSearchResultKind.line,
          title: 'Ligne ${route.routeShortName ?? route.routeId}',
          subtitle: route.routeLongName ?? '',
          score: score,
          lineId: route.routeId,
        ));
      }
    }

    for (final nearby in gtfs.searchStations(q, from: from, limit: limitPerCategory * 2)) {
      final score = _scoreStation(nearby.stop.stopName, q, from, nearby.stop.position);
      if (score > 0) {
        stations.add(TerrainSearchResult(
          kind: TerrainSearchResultKind.station,
          title: nearby.stop.stopName,
          subtitle: _distanceLabel(from, nearby.stop.position),
          score: score,
          marker: TerrainMarker.fromStop(nearby.stop),
          position: nearby.stop.position,
        ));
      }
    }

    vehicles.sort((a, b) => b.score.compareTo(a.score));
    lines.sort((a, b) => b.score.compareTo(a.score));
    stations.sort((a, b) => b.score.compareTo(a.score));
    agents.sort((a, b) => b.score.compareTo(a.score));

    final categories = <TerrainSearchCategory>[];
    void add(String label, int priority, List<TerrainSearchResult> list) {
      if (list.isEmpty) return;
      categories.add(TerrainSearchCategory(
        label: label,
        priority: priority,
        results: list.take(limitPerCategory).toList(),
      ));
    }

    add('Véhicules', 5, vehicles);
    add('Lignes', 4, lines);
    add('Stations', 3, stations);
    add('Agents', 2, agents);

    categories.sort((a, b) {
      final maxA = a.results.isEmpty ? 0 : a.results.first.score;
      final maxB = b.results.isEmpty ? 0 : b.results.first.score;
      final cmp = maxB.compareTo(maxA);
      return cmp != 0 ? cmp : b.priority.compareTo(a.priority);
    });

    return categories;
  }

  static int _scoreMarker(
    TerrainMarker m,
    String q,
    LatLng? from,
    TerrainMarkerType? priorityType,
  ) {
    var score = _scoreText(
      '${m.code ?? ''} ${m.line ?? ''} ${m.id}',
      m.direction ?? '',
      q,
      from,
      m.position,
    );
    if (priorityType != null && m.type == priorityType) score += 10;
    return score;
  }

  static int _scoreRoute(GtfsRoute route, String q) {
    var score = 0;
    final short = (route.routeShortName ?? '').toLowerCase();
    final long = (route.routeLongName ?? '').toLowerCase();
    final id = route.routeId.toLowerCase();
    if (short == q || id == q) {
      score += 40;
    } else if (short.startsWith(q) || id.startsWith(q)) {
      score += 30;
    } else if (short.contains(q) || long.contains(q) || id.contains(q)) {
      score += 15;
    }
    return score;
  }

  static int _scoreStation(String name, String q, LatLng? from, LatLng pos) {
    return _scoreText(name, '', q, from, pos);
  }

  static int _scoreText(
    String primary,
    String secondary,
    String q,
    LatLng? from,
    LatLng position,
  ) {
    final p = primary.toLowerCase();
    final s = secondary.toLowerCase();
    var score = 0;
    if (p == q) {
      score += 40;
    } else if (p.startsWith(q)) {
      score += 30;
    } else if (p.contains(q) || s.contains(q)) {
      score += 15;
    }

    if (from != null) {
      final d = _distance.as(LengthUnit.Meter, from, position);
      if (d < 500) {
        score += 20;
      } else if (d < 1500) {
        score += 10;
      }
    }
    return score;
  }

  static String _vehicleSubtitle(TerrainMarker m, LatLng? from) {
    final parts = <String>[];
    if (m.direction != null) parts.add(m.direction!);
    final dist = _distanceLabel(from, m.position);
    if (dist.isNotEmpty) parts.add(dist);
    return parts.join(' · ');
  }

  static String _distanceLabel(LatLng? from, LatLng pos) {
    if (from == null) return '';
    final m = _distance.as(LengthUnit.Meter, from, pos);
    if (m < 950) return '${(m / 10).round() * 10} m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }
}
