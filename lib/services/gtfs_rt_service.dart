import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'realtime_config.dart';

/// Mise à jour temps réel d'un passage à un arrêt (issue d'un `StopTimeUpdate`
/// GTFS-RT). Les temps sont en secondes Unix ; les retards en secondes
/// (positif = en retard, négatif = en avance).
class StopTimeUpdateRt {
  final int? stopSequence;
  final String? stopId;
  final int? arrivalTime;
  final int? arrivalDelay;
  final int? departureTime;
  final int? departureDelay;

  const StopTimeUpdateRt({
    this.stopSequence,
    this.stopId,
    this.arrivalTime,
    this.arrivalDelay,
    this.departureTime,
    this.departureDelay,
  });

  /// Heure de départ effective (s Unix) si connue, sinon l'arrivée.
  int? get effectiveTime => departureTime ?? arrivalTime;

  /// Retard de départ effectif (s) si connu, sinon celui d'arrivée.
  int? get effectiveDelay => departureDelay ?? arrivalDelay;
}

/// Mise à jour temps réel d'une course (trip).
class TripUpdateRt {
  final String? tripId;
  final String? routeId;
  final int? directionId;

  /// Retard global de la course (s) quand fourni au niveau TripUpdate.
  final int? tripDelay;
  final List<StopTimeUpdateRt> stopTimeUpdates;

  const TripUpdateRt({
    this.tripId,
    this.routeId,
    this.directionId,
    this.tripDelay,
    this.stopTimeUpdates = const [],
  });
}

/// Instantané du flux GTFS-RT trip-updates, avec index de requête.
class GtfsRtSnapshot {
  final DateTime fetchedAt;
  final List<TripUpdateRt> tripUpdates;

  late final Map<String, int> _delayByTrip = {
    for (final t in tripUpdates)
      if (t.tripId != null && t.tripDelay != null) t.tripId!: t.tripDelay!,
  };

  GtfsRtSnapshot({required this.fetchedAt, required this.tripUpdates});

  /// Retard (s) de la course [tripId] si connu (niveau course).
  int? delayForTrip(String tripId) => _delayByTrip[tripId];

  /// Prochain départ en temps réel à l'arrêt [stopId] (id GTFS, ex.
  /// `FR_NAOLIB:Quay:42`), éventuellement filtré par [routeId]
  /// (ex. `NAOLIBORG:Line:1`). Retourne l'attente depuis [now], ou null si le
  /// flux ne couvre pas cet arrêt.
  Duration? nextWaitAtStop(String stopId, {String? routeId, DateTime? now}) {
    final ref = now ?? DateTime.now();
    final nowSec = ref.millisecondsSinceEpoch ~/ 1000;
    int? best;
    for (final trip in tripUpdates) {
      if (routeId != null && trip.routeId != null && trip.routeId != routeId) {
        continue;
      }
      for (final stu in trip.stopTimeUpdates) {
        if (stu.stopId != stopId) continue;
        final t = stu.effectiveTime;
        if (t == null || t < nowSec) continue;
        if (best == null || t < best) best = t;
      }
    }
    if (best == null) return null;
    return Duration(seconds: best - nowSec);
  }
}

/// Client du flux GTFS-RT `trip-updates` de Naolib (retards/avances live).
///
/// Décode le protobuf GTFS-RT sans dépendance externe (sous-ensemble
/// FeedMessage → TripUpdate → StopTimeUpdate). Inactif tant qu'aucune clé
/// Okina n'est configurée ([RealtimeConfig.isLiveEnabled]).
class GtfsRtService {
  static const Duration _timeout = Duration(seconds: 8);

  /// Durée de validité de l'instantané en cache (évite de marteler le flux).
  static const Duration _cacheTtl = Duration(seconds: 25);

  final http.Client _client;
  GtfsRtSnapshot? _cache;

  GtfsRtService({http.Client? client}) : _client = client ?? http.Client();

  bool get isEnabled => RealtimeConfig.isLiveEnabled;

  /// Instantané courant des trip-updates (depuis le cache si frais).
  /// Retourne null si le live est désactivé ou si le flux est indisponible.
  Future<GtfsRtSnapshot?> tripUpdates({DateTime? now}) async {
    if (!isEnabled) return null;
    final ref = now ?? DateTime.now();
    final cached = _cache;
    if (cached != null && ref.difference(cached.fetchedAt) < _cacheTtl) {
      return cached;
    }
    try {
      final res = await _client.get(
        RealtimeConfig.gtfsRtFeed('trip-updates'),
        headers: {
          'Accept': 'application/x-protobuf',
          ...RealtimeConfig.authHeaders(),
        },
      ).timeout(_timeout);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return _cache;
      final snapshot = GtfsRtSnapshot(
        fetchedAt: ref,
        tripUpdates: decodeFeed(res.bodyBytes),
      );
      _cache = snapshot;
      return snapshot;
    } catch (e) {
      debugPrint('Wazibus: GTFS-RT trip-updates failed ($e)');
      return _cache;
    }
  }

  // ── Décodage protobuf (FeedMessage GTFS-RT) ───────────────────────────────
  // Numéros de champ d'après gtfs-realtime.proto :
  //   FeedMessage.entity = 2 ; FeedEntity.trip_update = 3
  //   TripUpdate.trip = 1, stop_time_update = 2, delay = 5
  //   TripDescriptor.trip_id = 1, route_id = 5, direction_id = 6
  //   StopTimeUpdate.stop_sequence = 1, arrival = 2, departure = 3, stop_id = 4
  //   StopTimeEvent.delay = 1, time = 2

  /// Décode un FeedMessage GTFS-RT en liste de [TripUpdateRt]. Exposé pour les
  /// tests.
  @visibleForTesting
  static List<TripUpdateRt> decodeFeed(Uint8List bytes) {
    final out = <TripUpdateRt>[];
    final r = _PbReader(bytes);
    while (!r.done) {
      final (field, wire) = r.readTag();
      if (field == 2 && wire == 2) {
        final tu = _decodeEntity(_PbReader(r.readBytes()));
        if (tu != null) out.add(tu);
      } else {
        r.skip(wire);
      }
    }
    return out;
  }

  static TripUpdateRt? _decodeEntity(_PbReader r) {
    while (!r.done) {
      final (field, wire) = r.readTag();
      if (field == 3 && wire == 2) {
        return _decodeTripUpdate(_PbReader(r.readBytes()));
      }
      r.skip(wire);
    }
    return null;
  }

  static TripUpdateRt _decodeTripUpdate(_PbReader r) {
    String? tripId, routeId;
    int? directionId, tripDelay;
    final stus = <StopTimeUpdateRt>[];
    while (!r.done) {
      final (field, wire) = r.readTag();
      switch (field) {
        case 1 when wire == 2: // trip (TripDescriptor)
          final d = _decodeTripDescriptor(_PbReader(r.readBytes()));
          tripId = d.$1;
          routeId = d.$2;
          directionId = d.$3;
        case 2 when wire == 2: // stop_time_update
          stus.add(_decodeStopTimeUpdate(_PbReader(r.readBytes())));
        case 5 when wire == 0: // delay
          tripDelay = _decodeSignedVarint(r.readVarint());
        default:
          r.skip(wire);
      }
    }
    return TripUpdateRt(
      tripId: tripId,
      routeId: routeId,
      directionId: directionId,
      tripDelay: tripDelay,
      stopTimeUpdates: stus,
    );
  }

  static (String?, String?, int?) _decodeTripDescriptor(_PbReader r) {
    String? tripId, routeId;
    int? directionId;
    while (!r.done) {
      final (field, wire) = r.readTag();
      switch (field) {
        case 1 when wire == 2:
          tripId = r.readString();
        case 5 when wire == 2:
          routeId = r.readString();
        case 6 when wire == 0:
          directionId = r.readVarint();
        default:
          r.skip(wire);
      }
    }
    return (tripId, routeId, directionId);
  }

  static StopTimeUpdateRt _decodeStopTimeUpdate(_PbReader r) {
    int? stopSequence;
    String? stopId;
    int? arrTime, arrDelay, depTime, depDelay;
    while (!r.done) {
      final (field, wire) = r.readTag();
      switch (field) {
        case 1 when wire == 0:
          stopSequence = r.readVarint();
        case 2 when wire == 2:
          final e = _decodeStopTimeEvent(_PbReader(r.readBytes()));
          arrDelay = e.$1;
          arrTime = e.$2;
        case 3 when wire == 2:
          final e = _decodeStopTimeEvent(_PbReader(r.readBytes()));
          depDelay = e.$1;
          depTime = e.$2;
        case 4 when wire == 2:
          stopId = r.readString();
        default:
          r.skip(wire);
      }
    }
    return StopTimeUpdateRt(
      stopSequence: stopSequence,
      stopId: stopId,
      arrivalTime: arrTime,
      arrivalDelay: arrDelay,
      departureTime: depTime,
      departureDelay: depDelay,
    );
  }

  /// (delay, time) d'un StopTimeEvent.
  static (int?, int?) _decodeStopTimeEvent(_PbReader r) {
    int? delay, time;
    while (!r.done) {
      final (field, wire) = r.readTag();
      switch (field) {
        case 1 when wire == 0:
          delay = _decodeSignedVarint(r.readVarint());
        case 2 when wire == 0:
          time = r.readVarint();
        default:
          r.skip(wire);
      }
    }
    return (delay, time);
  }

  /// `delay` GTFS-RT est un `int32` (complément à deux, pas du zigzag). Les
  /// valeurs négatives sont sérialisées sur 64 bits sign-étendus : sur un `int`
  /// Dart 64 bits, [_PbReader.readVarint] reconstitue déjà directement la
  /// valeur signée correcte. On la renvoie telle quelle, en repliant le cas
  /// résiduel où elle reviendrait comme un grand positif sur 32 bits.
  static int _decodeSignedVarint(int v) {
    if (v > 0x7fffffff && v <= 0xffffffff) return v - 0x100000000;
    return v;
  }
}

/// Lecteur protobuf minimal (varint, length-delimited, fixed32/64).
class _PbReader {
  final Uint8List _b;
  int _p = 0;
  _PbReader(this._b);

  bool get done => _p >= _b.length;

  int readVarint() {
    int result = 0, shift = 0;
    while (true) {
      final byte = _b[_p++];
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
    }
    return result;
  }

  /// Renvoie (numéro de champ, wire type).
  (int, int) readTag() {
    final tag = readVarint();
    return (tag >> 3, tag & 0x7);
  }

  Uint8List readBytes() {
    final len = readVarint();
    final sub = Uint8List.sublistView(_b, _p, _p + len);
    _p += len;
    return sub;
  }

  String readString() =>
      const Utf8Decoder(allowMalformed: true).convert(readBytes());

  void skip(int wire) {
    switch (wire) {
      case 0:
        readVarint();
      case 1:
        _p += 8;
      case 2:
        // NB: ne pas écrire `_p += readVarint()` — l'opérande gauche est lu
        // avant que readVarint() n'avance _p, ce qui perdrait son avancée.
        final len = readVarint();
        _p += len;
      case 5:
        _p += 4;
      default:
        throw FormatException('GTFS-RT: wire type inconnu $wire');
    }
  }
}
