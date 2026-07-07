import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/driver/terrain_marker.dart';
import '../../widgets/driver/driver_map_marker.dart';

/// Centre par défaut quand la position utilisateur n'est pas (encore) connue.
const LatLng kTerrainDefaultCenter = LatLng(47.2173, -1.5534); // Nantes

/// Lignes portées par la couche d'ambiance simulée (doivent correspondre à
/// [TerrainFeed.seed] et aux libellés GTFS réels, ex. trams « 1/2/3 »).
const List<String> kTerrainSimLines = ['C6', 'C20', '11', '23', '1', '2'];

/// Source de données de la carte Terrain.
///
/// Deux couches, clairement séparées :
///  1. Une **couche réelle** issue de Supabase (`vehicle_positions`), branchée
///     en temps réel (Realtime + repli par interrogation périodique). Elle est
///     soumise au RLS : un régulateur/staff voit toute la flotte, un conducteur
///     ne voit que ses propres points — le reste reste donc vide côté conducteur.
///  2. Une **couche d'ambiance simulée** (trams, équipes contrôle/MSR,
///     incidents, assistance) autour de la position courante, animée avec de
///     vraies coordonnées GPS, un cap et une vitesse — pour que la carte semble
///     vivante en l'absence d'un flux flotte ouvert à ce rôle. Dès que des bus
///     réels remontent de Supabase, ils remplacent la couche bus simulée.
///
/// Le point de bascule vers « tout Supabase » se limite à [snapshot] et
/// [refreshFromSupabase] : aucune position n'est posée au hasard côté réel.
class TerrainFeed {
  final SupabaseClient? client;

  TerrainFeed({this.client});

  final List<_Sim> _sims = [];
  List<TerrainMarker> _real = const [];
  bool _seeded = false;
  bool _pathsApplied = false;

  Timer? _poll;
  RealtimeChannel? _channel;

  // ---------------------------------------------------------------------------
  // Simulation d'ambiance
  // ---------------------------------------------------------------------------
  bool get isSeeded => _seeded;

  /// (Re)génère la couche d'ambiance autour de [center]. Idempotent : ne fait
  /// rien si déjà semé (pour ne pas « téléporter » les marqueurs au 1er GPS).
  void seed(LatLng center) {
    if (_seeded) return;
    _seeded = true;
    final rnd = math.Random(7);

    void add(
      TerrainMarkerType type, {
      required double speed,
      double radius = 0.011,
      String? code,
      String? line,
      String? direction,
      int? delay,
      int reliability = 96,
      int? frozenAgeSec,
    }) {
      final a = rnd.nextDouble() * 2 * math.pi;
      final r = radius * (0.35 + rnd.nextDouble() * 0.65);
      final pos = LatLng(
        center.latitude + r * math.cos(a),
        center.longitude +
            r * math.sin(a) / math.cos(center.latitude * math.pi / 180),
      );
      _sims.add(
        _Sim(
          id: 'sim:${_sims.length}',
          type: type,
          position: pos,
          heading: rnd.nextDouble() * 360,
          speedKmh: speed,
          code: code,
          line: line,
          direction: direction,
          delayMinutes: delay,
          reliability: reliability,
          turnBias: (rnd.nextDouble() - 0.5) * 8,
          frozenAgeSec: frozenAgeSec,
          homeCenter: center,
          homeRadius: radius * 1.3,
        ),
      );
    }

    // Bus (ligne, direction, retard) — l'un est volontairement « GPS perdu »
    // (figé, vieillissant) pour illustrer l'état grisé.
    add(
      TerrainMarkerType.bus,
      speed: 28,
      code: 'Bus 3625',
      line: 'C6',
      direction: 'Direction Hermeland',
      delay: 2,
      reliability: 98,
    );
    add(
      TerrainMarkerType.bus,
      speed: 24,
      code: 'Bus 3711',
      line: 'C20',
      direction: 'Direction Gare de Pont-Rousseau',
      delay: 0,
      reliability: 94,
    );
    add(
      TerrainMarkerType.bus,
      speed: 31,
      code: 'Bus 2208',
      line: '11',
      direction: 'Direction Préfecture',
      delay: 5,
      reliability: 90,
    );
    add(
      TerrainMarkerType.bus,
      speed: 0,
      code: 'Bus 1042',
      line: '23',
      direction: 'Direction Bellevue',
      delay: 1,
      reliability: 61,
      frozenAgeSec: 105,
    );

    // Trams.
    add(
      TerrainMarkerType.tram,
      speed: 34,
      code: 'Tram 351',
      line: '1',
      direction: 'Direction François Mitterrand',
      delay: -1,
      reliability: 99,
    );
    add(
      TerrainMarkerType.tram,
      speed: 29,
      code: 'Tram 318',
      line: '2',
      direction: 'Direction Orvault Grand Val',
      delay: 0,
      reliability: 97,
    );

    // Agents & terrain (immobiles ou lents).
    add(
      TerrainMarkerType.controle,
      speed: 4,
      code: 'Équipe contrôle C2',
      reliability: 92,
    );
    add(TerrainMarkerType.msr, speed: 3, code: 'Équipe MSR 4', reliability: 88);
    add(
      TerrainMarkerType.incident,
      speed: 0,
      code: 'Incident voie',
      reliability: 100,
    );
    add(
      TerrainMarkerType.assistance,
      speed: 0,
      code: 'Demande d\'assistance',
      reliability: 100,
    );
  }

  /// Avance la simulation de [dt] secondes (positions fluides, pings GPS
  /// discrets toutes les quelques secondes).
  void advance(double dt, DateTime now) {
    for (final s in _sims) {
      s.advance(dt, now);
    }
  }

  /// Accroche les véhicules simulés au tracé GTFS de leur ligne (clé = libellé
  /// de ligne, ex. « C6 », « 1 »). Appliqué une seule fois, dès que des tracés
  /// non vides arrivent — ainsi les bus/trams suivent leur itinéraire réel au
  /// lieu d'errer aléatoirement.
  void applyRoutePaths(Map<String, List<LatLng>> pathsByLine) {
    if (_pathsApplied || pathsByLine.isEmpty) return;
    var any = false;
    for (final s in _sims) {
      final path = s.line == null ? null : pathsByLine[s.line];
      if (path != null && path.length >= 2) {
        s.setPath(path);
        any = true;
      }
    }
    if (any) _pathsApplied = true;
  }

  // ---------------------------------------------------------------------------
  // Couche réelle Supabase
  // ---------------------------------------------------------------------------
  /// Démarre l'écoute temps réel des positions véhicules. [onChange] est appelé
  /// à chaque rafraîchissement. Sans client Supabase, ne fait rien.
  void startRealtime(VoidCallback onChange) {
    final c = client;
    if (c == null) return;

    // Premier chargement + rafraîchissement périodique (temps quasi réel, et
    // repli si Realtime indisponible pour ce rôle).
    refreshFromSupabase().then((_) => onChange());
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      refreshFromSupabase().then((_) => onChange());
    });

    try {
      _channel = c.channel('terrain_live')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'vehicle_positions',
          callback: (_) => refreshFromSupabase().then((_) => onChange()),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_reports',
          callback: (_) => refreshFromSupabase().then((_) => onChange()),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'network_incidents',
          callback: (_) => refreshFromSupabase().then((_) => onChange()),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'msr_missions',
          callback: (_) => refreshFromSupabase().then((_) => onChange()),
        )
        ..subscribe();
    } catch (e) {
      debugPrint('Aule: terrain realtime indisponible ($e)');
    }
  }

  /// Recharge les trois couches réelles (véhicules, incidents, MSR) en parallèle
  /// via les fonctions SECURITY DEFINER dédiées (lecture seule, contournant le
  /// RLS). Chaque couche échoue isolément sans bloquer les autres.
  Future<void> refreshFromSupabase() async {
    final c = client;
    if (c == null) return;
    final results = await Future.wait<List<TerrainMarker>>([
      _fetchVehicles(c),
      _fetchIncidents(c),
      _fetchMsrTeams(c),
      _fetchControlPoints(c),
      _fetchAssistance(c),
    ]);
    _real = [for (final list in results) ...list];
  }

  /// Envoie une demande d'assistance géolocalisée (bouton « Besoin d'aide »),
  /// puis rafraîchit aussitôt la carte. Renvoie vrai si l'envoi a réussi.
  Future<bool> sendAssistance(LatLng pos, {String? message}) async {
    final c = client;
    if (c == null) return false;
    try {
      await c.from('assistance_requests').insert({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'message': message ?? 'Demande d\'assistance terrain',
      });
      await refreshFromSupabase();
      return true;
    } catch (e) {
      debugPrint('Aule: sendAssistance ($e)');
      return false;
    }
  }

  /// Dernière position de chaque service actif (`fleet_live_positions`).
  Future<List<TerrainMarker>> _fetchVehicles(SupabaseClient c) async {
    try {
      final rows = await c.rpc(
        'fleet_live_positions',
        params: {'p_max_age_seconds': 300},
      );
      final out = <TerrainMarker>[];
      for (final row in (rows as List? ?? const [])) {
        final m = row as Map<String, dynamic>;
        final lat = (m['latitude'] as num?)?.toDouble();
        final lng = (m['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final serviceId = m['driver_service_id']?.toString() ?? '';
        final vehicle = m['vehicle_id']?.toString();
        final line = m['line_id']?.toString();
        final acc = (m['accuracy'] as num?)?.toDouble();
        final type = _typeFromLine(line);
        out.add(
          TerrainMarker(
            id: 'veh:$serviceId',
            type: type,
            position: LatLng(lat, lng),
            updatedAt:
                DateTime.tryParse(
                  m['recorded_at']?.toString() ?? '',
                )?.toLocal() ??
                DateTime.now(),
            headingDeg: (m['heading'] as num?)?.toDouble() ?? 0,
            speedKmh: ((m['speed'] as num?)?.toDouble() ?? 0) * 3.6,
            code: '${type.label} ${vehicle ?? '—'}'.trim(),
            line: line,
            direction: m['headsign']?.toString(),
            gpsReliability: acc == null
                ? null
                : (100 - acc).clamp(0, 100).round(),
          ),
        );
      }
      return out;
    } catch (e) {
      debugPrint('Aule: fleet_live_positions ($e)');
      return const [];
    }
  }

  /// Incidents ouverts/en cours géolocalisés (`terrain_incidents`).
  Future<List<TerrainMarker>> _fetchIncidents(SupabaseClient c) async {
    try {
      final rows = await c.rpc(
        'terrain_incidents',
        params: {'p_max_age_seconds': 86400},
      );
      final out = <TerrainMarker>[];
      for (final row in (rows as List? ?? const [])) {
        final m = row as Map<String, dynamic>;
        final lat = (m['latitude'] as num?)?.toDouble();
        final lng = (m['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        out.add(
          TerrainMarker(
            id: (m['id'] ?? '').toString(),
            type: TerrainMarkerType.incident,
            position: LatLng(lat, lng),
            updatedAt:
                DateTime.tryParse(
                  m['recorded_at']?.toString() ?? '',
                )?.toLocal() ??
                DateTime.now(),
            code: _incidentLabel(m['category']?.toString()),
            detail: m['label']?.toString(),
          ),
        );
      }
      return out;
    } catch (e) {
      debugPrint('Aule: terrain_incidents ($e)');
      return const [];
    }
  }

  /// Missions MSR actives, positionnées au centroïde de leur zone
  /// (`terrain_msr_teams`).
  Future<List<TerrainMarker>> _fetchMsrTeams(SupabaseClient c) async {
    try {
      final rows = await c.rpc(
        'terrain_msr_teams',
        params: {'p_max_age_seconds': 43200},
      );
      final out = <TerrainMarker>[];
      for (final row in (rows as List? ?? const [])) {
        final m = row as Map<String, dynamic>;
        final lat = (m['latitude'] as num?)?.toDouble();
        final lng = (m['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        out.add(
          TerrainMarker(
            id: (m['id'] ?? '').toString(),
            type: TerrainMarkerType.msr,
            position: LatLng(lat, lng),
            updatedAt:
                DateTime.tryParse(
                  m['recorded_at']?.toString() ?? '',
                )?.toLocal() ??
                DateTime.now(),
            code: 'Équipe MSR',
            detail: m['status'] == 'in_progress'
                ? 'Mission en cours'
                : 'Mission assignée',
          ),
        );
      }
      return out;
    } catch (e) {
      debugPrint('Aule: terrain_msr_teams ($e)');
      return const [];
    }
  }

  /// Points de contrôle des plans actifs (`terrain_control_points`) :
  /// stations ciblées, positionnées sur leurs coordonnées.
  Future<List<TerrainMarker>> _fetchControlPoints(SupabaseClient c) async {
    try {
      final rows = await c.rpc('terrain_control_points');
      final out = <TerrainMarker>[];
      for (final row in (rows as List? ?? const [])) {
        final m = row as Map<String, dynamic>;
        final lat = (m['latitude'] as num?)?.toDouble();
        final lng = (m['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final station = m['station_name']?.toString();
        final plan = m['plan_name']?.toString();
        out.add(
          TerrainMarker(
            id: (m['id'] ?? '').toString(),
            type: TerrainMarkerType.controle,
            position: LatLng(lat, lng),
            updatedAt:
                DateTime.tryParse(
                  m['recorded_at']?.toString() ?? '',
                )?.toLocal() ??
                DateTime.now(),
            code: 'Contrôle',
            detail: station == null
                ? plan
                : (plan == null ? station : '$plan · $station'),
          ),
        );
      }
      return out;
    } catch (e) {
      debugPrint('Aule: terrain_control_points ($e)');
      return const [];
    }
  }

  /// Demandes d'assistance ouvertes (`terrain_assistance`).
  Future<List<TerrainMarker>> _fetchAssistance(SupabaseClient c) async {
    try {
      final rows = await c.rpc(
        'terrain_assistance',
        params: {'p_max_age_seconds': 7200},
      );
      final out = <TerrainMarker>[];
      for (final row in (rows as List? ?? const [])) {
        final m = row as Map<String, dynamic>;
        final lat = (m['latitude'] as num?)?.toDouble();
        final lng = (m['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final msg = m['message']?.toString();
        out.add(
          TerrainMarker(
            id: (m['id'] ?? '').toString(),
            type: TerrainMarkerType.assistance,
            position: LatLng(lat, lng),
            updatedAt:
                DateTime.tryParse(
                  m['recorded_at']?.toString() ?? '',
                )?.toLocal() ??
                DateTime.now(),
            code: 'Demande d\'assistance',
            detail: (msg == null || msg.isEmpty)
                ? 'En attente de prise en charge'
                : msg,
          ),
        );
      }
      return out;
    } catch (e) {
      debugPrint('Aule: terrain_assistance ($e)');
      return const [];
    }
  }

  /// Heuristique mode : les lignes 1/2/3 (et L1…) de Nantes sont des trams.
  static TerrainMarkerType _typeFromLine(String? line) {
    final l = (line ?? '').toUpperCase().trim();
    const tramLines = {'1', '2', '3', 'L1', 'L2', 'L3', 'T1', 'T2', 'T3'};
    return tramLines.contains(l)
        ? TerrainMarkerType.tram
        : TerrainMarkerType.bus;
  }

  /// Libellé FR d'un type de signalement conducteur.
  static String _incidentLabel(String? category) {
    switch (category) {
      case 'delay':
        return 'Retard signalé';
      case 'crowded':
        return 'Forte affluence';
      case 'breakdown':
        return 'Panne véhicule';
      case 'accident':
        return 'Accident';
      case 'traffic':
        return 'Trafic dense';
      case 'detour':
        return 'Déviation';
      case 'passenger_illness':
        return 'Malaise voyageur';
      case 'stop_skipped':
        return 'Arrêt non desservi';
      case 'incivility':
        return 'Incivilité';
      default:
        return (category == null || category.isEmpty) ? 'Incident' : category;
    }
  }

  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------
  /// Snapshot immuable courant. Le remplacement se fait par COUCHE : dès qu'une
  /// couche réelle (véhicules / incidents / MSR) remonte de Supabase, elle
  /// remplace la couche simulée correspondante ; les couches sans source réelle
  /// (contrôle, assistance) restent simulées pour garder la carte vivante.
  List<TerrainMarker> snapshot(DateTime now) {
    final sims = [for (final s in _sims) s.toMarker(now)];
    if (_real.isEmpty) return sims;

    final hasVehicles = _real.any((m) => m.isVehicle);
    final hasIncidents = _real.any((m) => m.type == TerrainMarkerType.incident);
    final hasMsr = _real.any((m) => m.type == TerrainMarkerType.msr);
    final hasControle = _real.any((m) => m.type == TerrainMarkerType.controle);
    final hasAssistance = _real.any(
      (m) => m.type == TerrainMarkerType.assistance,
    );

    bool replaced(TerrainMarker m) =>
        (m.isVehicle && hasVehicles) ||
        (m.type == TerrainMarkerType.incident && hasIncidents) ||
        (m.type == TerrainMarkerType.msr && hasMsr) ||
        (m.type == TerrainMarkerType.controle && hasControle) ||
        (m.type == TerrainMarkerType.assistance && hasAssistance);

    return [
      for (final m in sims)
        if (!replaced(m)) m,
      ..._real,
    ];
  }

  void dispose() {
    _poll?.cancel();
    final ch = _channel;
    if (ch != null) {
      try {
        client?.removeChannel(ch);
      } catch (_) {}
    }
  }
}

/// Entité simulée mutable (état interne du moteur d'ambiance).
class _Sim {
  final String id;
  final TerrainMarkerType type;
  LatLng position;
  double heading; // 0 = nord, sens horaire
  final double speedKmh;
  final String? code;
  final String? line;
  final String? direction;
  final int? delayMinutes;
  final int reliability;
  final double turnBias; // courbure douce (deg/s)
  final int? frozenAgeSec; // âge GPS figé (illustration grisé), sinon null
  final LatLng homeCenter;
  final double homeRadius;

  DateTime _updatedAt;
  double _sincePing = 0;

  // Suivi du tracé GTFS de la ligne (remplace l'errance aléatoire). Le véhicule
  // parcourt le tronçon en aller-retour, cap donné par la tangente.
  List<LatLng>? _path;
  int _i = 0; // index du sommet courant
  double _frac = 0; // progression 0..1 vers le sommet _i + _dir
  int _dir = 1; // sens de parcours (+1 / -1)

  _Sim({
    required this.id,
    required this.type,
    required this.position,
    required this.heading,
    required this.speedKmh,
    required this.reliability,
    required this.turnBias,
    required this.homeCenter,
    required this.homeRadius,
    this.code,
    this.line,
    this.direction,
    this.delayMinutes,
    this.frozenAgeSec,
  }) : _updatedAt = DateTime.now();

  static const _distance = Distance();

  /// Pose le véhicule sur le tracé [path] de sa ligne, accroché au sommet le
  /// plus proche de sa position courante.
  void setPath(List<LatLng> path) {
    if (path.length < 2) return;
    _path = path;
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < path.length; i++) {
      final d = _distance.as(LengthUnit.Meter, position, path[i]);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    _i = best;
    _frac = 0;
    _dir = best >= path.length - 1 ? -1 : 1;
    position = path[best];
  }

  void advance(double dt, DateTime now) {
    if (speedKmh > 0.1) {
      final metres = speedKmh * 1000 / 3600 * dt;
      final path = _path;
      if (path != null && path.length >= 2) {
        _advanceAlongPath(path, metres);
      } else {
        // Repli : errance douce bornée au secteur (lignes sans tracé GTFS).
        heading += turnBias * dt;
        final fromHome = _distance.as(LengthUnit.Meter, homeCenter, position);
        if (fromHome > homeRadius * 111320) {
          final bearingHome = _bearing(position, homeCenter);
          heading = bearingHome + (heading - bearingHome) * 0.1;
        }
        heading %= 360;
        final rad = heading * math.pi / 180;
        final dLat = metres * math.cos(rad) / 111320.0;
        final dLng =
            metres *
            math.sin(rad) /
            (111320.0 * math.cos(position.latitude * math.pi / 180));
        position = LatLng(position.latitude + dLat, position.longitude + dLng);
      }
    }

    // Pings GPS discrets (env. toutes les 3,5 s) — sauf entités figées.
    if (frozenAgeSec == null) {
      _sincePing += dt;
      if (_sincePing >= 3.5) {
        _sincePing = 0;
        _updatedAt = now;
      }
    } else {
      _updatedAt = now.subtract(Duration(seconds: frozenAgeSec!));
    }
  }

  TerrainMarker toMarker(DateTime now) => TerrainMarker(
    id: id,
    type: type,
    position: position,
    updatedAt: _updatedAt,
    headingDeg: heading,
    speedKmh: speedKmh,
    code: code,
    line: line,
    direction: direction,
    delayMinutes: delayMinutes,
    gpsReliability: reliability,
  );

  /// Avance de [metres] le long de [path] (aller-retour aux extrémités) et met
  /// à jour position + cap selon la tangente du tracé.
  void _advanceAlongPath(List<LatLng> path, double metres) {
    var remaining = metres;
    var guard = 0;
    while (remaining > 0 && guard++ < 10000) {
      var toIdx = _i + _dir;
      if (toIdx < 0 || toIdx >= path.length) {
        _dir = -_dir;
        toIdx = _i + _dir;
        if (toIdx < 0 || toIdx >= path.length) break;
      }
      final segLen = _distance.as(LengthUnit.Meter, path[_i], path[toIdx]);
      if (segLen <= 0.0001) {
        _i = toIdx;
        _frac = 0;
        continue;
      }
      final segRemaining = segLen * (1 - _frac);
      if (remaining < segRemaining) {
        _frac += remaining / segLen;
        remaining = 0;
      } else {
        remaining -= segRemaining;
        _i = toIdx;
        _frac = 0;
      }
    }

    final toIdx = (_i + _dir).clamp(0, path.length - 1);
    final from = path[_i];
    final to = path[toIdx];
    position = LatLng(
      from.latitude + (to.latitude - from.latitude) * _frac,
      from.longitude + (to.longitude - from.longitude) * _frac,
    );
    if (toIdx != _i) heading = _bearing(from, to);
  }

  static double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
