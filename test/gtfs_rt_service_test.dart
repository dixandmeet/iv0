import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wazibus_nantes/services/gtfs_rt_service.dart';

// ── Mini-encodeur protobuf pour fabriquer un FeedMessage de test ───────────
List<int> _varint(int v) {
  final out = <int>[];
  var n = v;
  while (true) {
    final b = n & 0x7f;
    n >>= 7;
    if (n != 0) {
      out.add(b | 0x80);
    } else {
      out.add(b);
      break;
    }
  }
  return out;
}

List<int> _tag(int field, int wire) => _varint(field << 3 | wire);

List<int> _strField(int field, String s) {
  final bytes = utf8.encode(s);
  return [..._tag(field, 2), ..._varint(bytes.length), ...bytes];
}

List<int> _varField(int field, int v) => [..._tag(field, 0), ..._varint(v)];

List<int> _msgField(int field, List<int> body) =>
    [..._tag(field, 2), ..._varint(body.length), ...body];

/// int32 négatif sign-étendu sur 64 bits (conforme GTFS-RT).
List<int> _sint32Field(int field, int v) {
  final u = v < 0 ? (BigInt.from(v) & (BigInt.one << 64) - BigInt.one) : null;
  if (u == null) return _varField(field, v);
  final out = <int>[..._tag(field, 0)];
  var n = u;
  final mask = BigInt.from(0x7f);
  while (true) {
    final b = (n & mask).toInt();
    n = n >> 7;
    if (n != BigInt.zero) {
      out.add(b | 0x80);
    } else {
      out.add(b);
      break;
    }
  }
  return out;
}

void main() {
  test('décode un FeedMessage GTFS-RT (trip + stop_time_update)', () {
    // departure.time absolus
    const t1 = 1700000000;
    const t2 = 1700000600;

    final tripDesc = [
      ..._strField(1, 'NAOLIBORG:VehicleJourney:42'),
      ..._strField(5, 'NAOLIBORG:Line:1'),
      ..._varField(6, 1),
    ];
    final dep1 = [..._varField(2, t1)]; // StopTimeEvent.time
    final dep2 = [..._varField(2, t2)];
    final stu1 = [
      ..._varField(1, 5), // stop_sequence
      ..._msgField(3, dep1), // departure
      ..._strField(4, 'FR_NAOLIB:Quay:42'), // stop_id
    ];
    final stu2 = [
      ..._varField(1, 6),
      ..._msgField(3, dep2),
      ..._strField(4, 'FR_NAOLIB:Quay:99'),
    ];
    final tripUpdate = [
      ..._msgField(1, tripDesc),
      ..._msgField(2, stu1),
      ..._msgField(2, stu2),
      ..._sint32Field(5, -45), // retard global -45 s (en avance)
    ];
    final entity = [
      ..._strField(1, 'entity-1'),
      ..._msgField(3, tripUpdate),
    ];
    final feed = <int>[
      ..._strField(1, 'header-placeholder-ignored'), // champ 1 ignoré
      ..._msgField(2, entity),
    ];

    final updates = GtfsRtService.decodeFeed(Uint8List.fromList(feed));
    expect(updates.length, 1);
    final tu = updates.first;
    expect(tu.tripId, 'NAOLIBORG:VehicleJourney:42');
    expect(tu.routeId, 'NAOLIBORG:Line:1');
    expect(tu.directionId, 1);
    expect(tu.tripDelay, -45);
    expect(tu.stopTimeUpdates.length, 2);
    expect(tu.stopTimeUpdates.first.stopId, 'FR_NAOLIB:Quay:42');
    expect(tu.stopTimeUpdates.first.departureTime, t1);

    final snap = GtfsRtSnapshot(
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(t1 * 1000),
      tripUpdates: updates,
    );
    // À t1, l'arrêt Quay:42 part maintenant (0 s), filtré par ligne.
    final wait = snap.nextWaitAtStop('FR_NAOLIB:Quay:42',
        routeId: 'NAOLIBORG:Line:1',
        now: DateTime.fromMillisecondsSinceEpoch(t1 * 1000));
    expect(wait, Duration.zero);
    // Quay:99 part 600 s plus tard.
    final wait2 = snap.nextWaitAtStop('FR_NAOLIB:Quay:99',
        now: DateTime.fromMillisecondsSinceEpoch(t1 * 1000));
    expect(wait2, const Duration(seconds: 600));
    // Arrêt non couvert -> null.
    expect(snap.nextWaitAtStop('FR_NAOLIB:Quay:0'), isNull);
    expect(snap.delayForTrip('NAOLIBORG:VehicleJourney:42'), -45);
  });

  test('feed vide -> aucune mise à jour', () {
    expect(GtfsRtService.decodeFeed(Uint8List(0)), isEmpty);
  });
}
