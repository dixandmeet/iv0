import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'gtfs_rt_service.dart';
import 'realtime_config.dart';

/// Temps réel opérateur (Naolib / Nantes Métropole).
///
/// Ordre des sources, de la plus fiable à la plus dégradée :
///   1. GTFS-RT trip-updates (gateway Okina) — retards/horaires live ;
///   2. Stop Monitoring SIRI-Lite (gateway Okina) — variante JSON ;
///   3. ancienne API JSON `open.tan.fr` (en repli, souvent vide aujourd'hui).
/// Les deux premières nécessitent une clé Okina ([RealtimeConfig]). Toutes les
/// erreurs (réseau, clé absente, réponse vide) sont silencieuses : l'appelant
/// retombe alors sur les horaires théoriques / l'estimation locale.
class OperatorRealtimeService {
  static const String _legacyBase = 'https://open.tan.fr/ewp';

  static const Duration _timeout = Duration(seconds: 6);

  final http.Client _client;
  final GtfsRtService _gtfsRt;

  OperatorRealtimeService({http.Client? client, GtfsRtService? gtfsRt})
      : _client = client ?? http.Client(),
        _gtfsRt = gtfsRt ?? GtfsRtService(client: client);

  /// Prochain passage (durée d'attente) de la ligne [lineCode] à l'arrêt
  /// [stopCode] (code lieu TAN, ex. `CRQU`), éventuellement filtré par
  /// direction ([headsign]). Retourne null si aucune donnée opérateur.
  ///
  /// [gtfsStopId] / [gtfsRouteId] (ids GTFS, ex. `FR_NAOLIB:Quay:42` /
  /// `NAOLIBORG:Line:1`), quand fournis par l'index horaires, activent la
  /// source GTFS-RT live.
  Future<Duration?> nextWait({
    required String stopCode,
    required String lineCode,
    String? headsign,
    String? gtfsStopId,
    String? gtfsRouteId,
  }) async {
    if (gtfsStopId != null) {
      final rt = await _tryGtfsRt(stopId: gtfsStopId, routeId: gtfsRouteId);
      if (rt != null) return rt;
    }
    final siri = await _trySiriLite(
        stopCode: stopCode, lineCode: lineCode, headsign: headsign);
    if (siri != null) return siri;
    return _tryLegacy(
        stopCode: stopCode, lineCode: lineCode, headsign: headsign);
  }

  // --- GTFS-RT trip-updates ------------------------------------------------

  Future<Duration?> _tryGtfsRt(
      {required String stopId, String? routeId}) async {
    if (!_gtfsRt.isEnabled) return null;
    final snapshot = await _gtfsRt.tripUpdates();
    return snapshot?.nextWaitAtStop(stopId, routeId: routeId);
  }

  // --- SIRI-Lite (Stop Monitoring) ---------------------------------------

  Future<Duration?> _trySiriLite({
    required String stopCode,
    required String lineCode,
    String? headsign,
  }) async {
    if (!RealtimeConfig.isLiveEnabled) return null;
    try {
      final uri = Uri.parse(
          '${RealtimeConfig.siriLiteBase}/stop-monitoring?MonitoringRef=$stopCode');
      final res = await _client.get(uri, headers: {
        'Accept': 'application/json',
        ...RealtimeConfig.authHeaders(),
      }).timeout(_timeout);
      if (res.statusCode != 200 || res.body.isEmpty) return null;

      final root = jsonDecode(res.body);
      final deliveries = root['Siri']?['ServiceDelivery']
          ?['StopMonitoringDelivery'] as List?;
      if (deliveries == null || deliveries.isEmpty) return null;

      final now = DateTime.now();
      Duration? best;
      for (final delivery in deliveries) {
        final visits = delivery['MonitoredStopVisit'] as List? ?? const [];
        for (final visit in visits) {
          final journey = visit['MonitoredVehicleJourney'];
          if (journey is! Map) continue;
          final line = _firstValue(journey['PublishedLineName']) ??
              (journey['LineRef'] as String?);
          if (line == null || !_lineMatches(line, lineCode)) continue;
          if (headsign != null && headsign.isNotEmpty) {
            final dest = _firstValue(journey['DestinationName']);
            if (dest != null && !_textMatches(dest, headsign)) continue;
          }
          final call = journey['MonitoredCall'];
          if (call is! Map) continue;
          final raw = call['ExpectedDepartureTime'] ??
              call['ExpectedArrivalTime'] ??
              call['AimedDepartureTime'];
          if (raw is! String) continue;
          final at = DateTime.tryParse(raw);
          if (at == null) continue;
          final wait = at.difference(now);
          if (wait.isNegative) continue;
          if (best == null || wait < best) best = wait;
        }
      }
      return best;
    } catch (e) {
      debugPrint('Aule: SIRI-Lite stop monitoring failed ($e)');
      return null;
    }
  }

  // --- API legacy open.tan.fr ---------------------------------------------

  Future<Duration?> _tryLegacy({
    required String stopCode,
    required String lineCode,
    String? headsign,
  }) async {
    try {
      final uri = Uri.parse('$_legacyBase/tempsattente.json/$stopCode');
      final res = await _client.get(uri).timeout(_timeout);
      if (res.statusCode != 200 || res.body.isEmpty) return null;

      final data = jsonDecode(res.body);
      if (data is! List || data.isEmpty) return null;

      Duration? best;
      for (final entry in data) {
        if (entry is! Map) continue;
        final num0 = entry['ligne'] is Map
            ? (entry['ligne']['numLigne'] as String?)
            : null;
        if (num0 == null || !_lineMatches(num0, lineCode)) continue;
        if (headsign != null && headsign.isNotEmpty) {
          final terminus = entry['terminus'] as String?;
          if (terminus != null && !_textMatches(terminus, headsign)) continue;
        }
        final wait = _parseLegacyWait(entry['temps'] as String?);
        if (wait == null) continue;
        if (best == null || wait < best) best = wait;
      }
      return best;
    } catch (e) {
      debugPrint('Aule: legacy TAN API failed ($e)');
      return null;
    }
  }

  /// Formats rencontrés : "proche", "5mn", "1h12".
  Duration? _parseLegacyWait(String? raw) {
    if (raw == null) return null;
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s.contains('proche')) return Duration.zero;
    final hourMatch = RegExp(r'^(\d+)h(\d*)$').firstMatch(s);
    if (hourMatch != null) {
      final h = int.parse(hourMatch.group(1)!);
      final m = int.tryParse(hourMatch.group(2) ?? '') ?? 0;
      return Duration(hours: h, minutes: m);
    }
    final minMatch = RegExp(r'^(\d+)\s*mn?$').firstMatch(s);
    if (minMatch != null) {
      return Duration(minutes: int.parse(minMatch.group(1)!));
    }
    return null;
  }

  // --- Helpers --------------------------------------------------------------

  /// Certains champs SIRI sont des listes de {value: ...}.
  String? _firstValue(dynamic field) {
    if (field is String) return field;
    if (field is List && field.isNotEmpty) {
      final first = field.first;
      if (first is String) return first;
      if (first is Map) return first['value'] as String?;
    }
    if (field is Map) return field['value'] as String?;
    return null;
  }

  bool _lineMatches(String candidate, String lineCode) {
    final a = candidate.trim().toLowerCase();
    final b = lineCode.trim().toLowerCase();
    return a == b || a.endsWith(':$b') || a.contains(':$b:');
  }

  bool _textMatches(String a, String b) {
    String norm(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ûüù]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final na = norm(a);
    final nb = norm(b);
    return na.contains(nb) || nb.contains(na);
  }
}
