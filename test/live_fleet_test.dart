import 'package:flutter_test/flutter_test.dart';
import 'package:aule/models/community_vehicle.dart';
import 'package:aule/models/live_fleet_position.dart';

void main() {
  test('LiveFleetPosition.fromJson parse GeoJSON et score fiabilité', () {
    final live = LiveFleetPosition.fromJson({
      'id': 'abc-123',
      'route_id': '1',
      'trip_id': 'T1',
      'transport_type': 'tram',
      'geom': {'type': 'Point', 'coordinates': [-1.55, 47.21]},
      'speed': 8.5,
      'heading': 90,
      'source': 'driver',
      'source_confidence': 100,
      'reliability_score': 92,
      'freshness_seconds': 12,
      'coherence_score': 85,
      'last_seen_at': '2026-06-14T14:00:00Z',
    });

    expect(live.routeId, '1');
    expect(live.reliabilityScore, 92);
    expect(live.sourceLabel, 'Conducteur certifié');

    final vehicle = CommunityVehicle.fromLiveFleet(live);
    expect(vehicle.confidenceScore, 92);
    expect(vehicle.dataSource, 'driver');
    expect(vehicle.dataSourceLabel, 'Conducteur certifié');
  });
}
