import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class RoutePoint {
  final LatLng position;
  final double bearing;
  const RoutePoint(this.position, this.bearing);
}

double bearingBetween(LatLng a, LatLng b) {
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

List<double> _segmentLengths(List<LatLng> pts) {
  final lens = <double>[];
  for (var i = 0; i < pts.length - 1; i++) {
    final dLat = pts[i + 1].latitude - pts[i].latitude;
    final dLng =
        (pts[i + 1].longitude - pts[i].longitude) *
        math.cos(pts[i].latitude * math.pi / 180);
    lens.add(math.sqrt(dLat * dLat + dLng * dLng));
  }
  return lens;
}

/// Position + cap le long du tracé à la fraction [t] (0..1).
RoutePoint pointOnRoute(List<LatLng> pts, double t) {
  final segLens = _segmentLengths(pts);
  final total = segLens.fold<double>(0, (a, b) => a + b);
  var target = t.clamp(0, 1) * total;
  for (var i = 0; i < segLens.length; i++) {
    if (target <= segLens[i] || i == segLens.length - 1) {
      final f = segLens[i] == 0 ? 0.0 : (target / segLens[i]).clamp(0, 1);
      final lat = pts[i].latitude + (pts[i + 1].latitude - pts[i].latitude) * f;
      final lng =
          pts[i].longitude + (pts[i + 1].longitude - pts[i].longitude) * f;
      return RoutePoint(LatLng(lat, lng), bearingBetween(pts[i], pts[i + 1]));
    }
    target -= segLens[i];
  }
  return RoutePoint(pts.first, 0);
}

/// Projection d'un point réel (GPS) sur le tracé.
class RouteMatch {
  final double t; // fraction 0..1 le long du tracé
  final LatLng snapped; // point du tracé le plus proche
  final double bearing; // cap du segment le plus proche
  final double distanceMeters; // écart perpendiculaire au tracé
  const RouteMatch(this.t, this.snapped, this.bearing, this.distanceMeters);
}

/// Trouve le point du tracé [pts] le plus proche de [p] et renvoie sa
/// progression (0..1), utilisée pour caler prochain arrêt / ETA sur la
/// position réelle du bus.
RouteMatch projectOnRoute(List<LatLng> pts, LatLng p) {
  final segLens = _segmentLengths(pts);
  final total = segLens.fold<double>(0, (a, b) => a + b);
  final cosLat = math.cos(p.latitude * math.pi / 180);
  final px = p.longitude * cosLat, py = p.latitude;

  var best = double.infinity;
  var bestSeg = 0;
  var bestF = 0.0;
  var bestAccum = 0.0;
  var acc = 0.0;
  for (var i = 0; i < pts.length - 1; i++) {
    final ax = pts[i].longitude * cosLat, ay = pts[i].latitude;
    final bx = pts[i + 1].longitude * cosLat, by = pts[i + 1].latitude;
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final f = len2 == 0
        ? 0.0
        : (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
    final cx = ax + dx * f, cy = ay + dy * f;
    final d2 = (px - cx) * (px - cx) + (py - cy) * (py - cy);
    if (d2 < best) {
      best = d2;
      bestSeg = i;
      bestF = f;
      bestAccum = acc;
    }
    acc += segLens[i];
  }

  final along = bestAccum + segLens[bestSeg] * bestF;
  final a = pts[bestSeg], b = pts[bestSeg + 1];
  final snapped = LatLng(
    a.latitude + (b.latitude - a.latitude) * bestF,
    a.longitude + (b.longitude - a.longitude) * bestF,
  );
  const distance = Distance();
  return RouteMatch(
    total == 0 ? 0.0 : (along / total).clamp(0.0, 1.0),
    snapped,
    bearingBetween(a, b),
    distance.as(LengthUnit.Meter, p, snapped),
  );
}

/// Portion du tracé déjà parcourue, du départ jusqu'à la fraction [t].
List<LatLng> traveledCoords(List<LatLng> pts, double t) {
  final segLens = _segmentLengths(pts);
  final total = segLens.fold<double>(0, (a, b) => a + b);
  final target = pointOnRoute(pts, t);
  final targetDist = t.clamp(0, 1) * total;
  final traveled = <LatLng>[pts.first];
  var acc = 0.0;
  for (var i = 0; i < segLens.length; i++) {
    if (acc + segLens[i] <= targetDist) {
      traveled.add(pts[i + 1]);
      acc += segLens[i];
    } else {
      traveled.add(target.position);
      break;
    }
  }
  return traveled;
}

LatLng offsetLatLng(LatLng center, double meters, double angleDeg) {
  final rad = angleDeg * math.pi / 180;
  final dLat = (meters * math.cos(rad)) / 111320;
  final dLng =
      (meters * math.sin(rad)) /
      (111320 * math.cos(center.latitude * math.pi / 180));
  return LatLng(center.latitude + dLat, center.longitude + dLng);
}

/// Interpolation angulaire (gère le passage 359°→0°) pour un cap sans à-coups.
double lerpAngle(double a, double b, double f) {
  final d = ((b - a + 540) % 360) - 180;
  return (a + d * f + 360) % 360;
}

String formatDistance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }
  return '${(meters / 10).round() * 10} m';
}
