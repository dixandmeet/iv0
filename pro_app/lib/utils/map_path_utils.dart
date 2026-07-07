import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Utilitaires de tracés pour les cartes (ligne, marche à pied).
class MapPathUtils {
  MapPathUtils._();

  static const _distance = Distance();
  static const _walkBlue = Color(0xFF1B66F5);

  /// Interpole des points le long d'une polyligne pour un rendu fluide.
  static List<LatLng> densify(List<LatLng> points, {double stepMeters = 12}) {
    if (points.length < 2) return points;
    final out = <LatLng>[points.first];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final len = _distance.as(LengthUnit.Meter, a, b);
      if (len <= stepMeters) {
        out.add(b);
        continue;
      }
      final steps = (len / stepMeters).ceil();
      for (var s = 1; s <= steps; s++) {
        final t = s / steps;
        out.add(LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
      }
    }
    return out;
  }

  /// Chemin piéton en « L » avec virage arrondi (hors-ligne, repli OSRM).
  static List<LatLng> walkingPath(LatLng from, LatLng to) {
    final cornerA = LatLng(from.latitude, to.longitude);
    final cornerB = LatLng(to.latitude, from.longitude);
    final viaA = _distance.as(LengthUnit.Meter, from, cornerA) +
        _distance.as(LengthUnit.Meter, cornerA, to);
    final viaB = _distance.as(LengthUnit.Meter, from, cornerB) +
        _distance.as(LengthUnit.Meter, cornerB, to);
    final corner = viaA <= viaB ? cornerA : cornerB;

    final leg1 = _distance.as(LengthUnit.Meter, from, corner);
    final leg2 = _distance.as(LengthUnit.Meter, corner, to);
    const cornerRadiusMeters = 22.0;
    final radius = math.min(cornerRadiusMeters, math.min(leg1, leg2) * 0.42);

    if (radius < 8 || leg1 < 18 || leg2 < 18) {
      return densify([from, corner, to], stepMeters: 5);
    }

    final t1 = radius / leg1;
    final t2 = radius / leg2;
    final beforeCorner = LatLng(
      from.latitude + (corner.latitude - from.latitude) * (1 - t1),
      from.longitude + (corner.longitude - from.longitude) * (1 - t1),
    );
    final afterCorner = LatLng(
      corner.latitude + (to.latitude - corner.latitude) * t2,
      corner.longitude + (to.longitude - corner.longitude) * t2,
    );

    final arc = <LatLng>[];
    for (var i = 0; i <= 14; i++) {
      final t = i / 14;
      final u = 1 - t;
      arc.add(
        LatLng(
          u * u * beforeCorner.latitude +
              2 * u * t * corner.latitude +
              t * t * afterCorner.latitude,
          u * u * beforeCorner.longitude +
              2 * u * t * corner.longitude +
              t * t * afterCorner.longitude,
        ),
      );
    }

    return densify([from, beforeCorner, ...arc, afterCorner, to], stepMeters: 5);
  }

  /// Polylignes marche à pied (style guidage piéton).
  static List<Polyline> walkPolylines(List<LatLng> walkPath) {
    if (walkPath.length < 2) return const [];
    return [
      Polyline(
        points: walkPath,
        color: _walkBlue.withValues(alpha: 0.18),
        strokeWidth: 11,
        strokeCap: StrokeCap.round,
        useStrokeWidthInMeter: true,
      ),
      Polyline(
        points: walkPath,
        color: _walkBlue,
        strokeWidth: 4.8,
        borderStrokeWidth: 2.2,
        borderColor: Colors.white,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
        useStrokeWidthInMeter: true,
      ),
    ];
  }

  /// Tronçon de polyligne autour d'un point (distance le long du tracé).
  static List<LatLng> segmentNear(
    List<LatLng> polyline,
    LatLng point, {
    double beforeMeters = 400,
    double afterMeters = 400,
  }) {
    if (polyline.length < 2) return polyline;
    final anchor = nearestIndex(polyline, point);

    var start = anchor;
    var acc = 0.0;
    for (var i = anchor; i > 0; i--) {
      acc += _distance.as(LengthUnit.Meter, polyline[i], polyline[i - 1]);
      start = i - 1;
      if (acc >= beforeMeters) break;
    }

    var end = anchor;
    acc = 0.0;
    for (var i = anchor; i < polyline.length - 1; i++) {
      acc += _distance.as(LengthUnit.Meter, polyline[i], polyline[i + 1]);
      end = i + 1;
      if (acc >= afterMeters) break;
    }

    return slice(polyline, start, end);
  }

  /// Sous-tracé entre deux positions (indices les plus proches).
  static List<LatLng> clipBetween(
    List<LatLng> polyline,
    LatLng from,
    LatLng to,
  ) {
    if (polyline.length < 2) return polyline;
    final fromIdx = nearestIndex(polyline, from);
    final toIdx = nearestIndex(polyline, to);
    return slice(polyline, fromIdx, toIdx);
  }

  /// Assure que le chemin piéton rejoint exactement [target].
  static List<LatLng> connectTo(List<LatLng> path, LatLng target) {
    if (path.isEmpty) return [target];
    if (_distance.as(LengthUnit.Meter, path.last, target) < 2) {
      return [...path.sublist(0, path.length - 1), target];
    }
    return [...path, target];
  }

  /// Index du point de [polyline] le plus proche de [point].
  static int nearestIndex(List<LatLng> polyline, LatLng point) {
    if (polyline.isEmpty) return 0;
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < polyline.length; i++) {
      final d = _distance.as(LengthUnit.Meter, polyline[i], point);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  /// Sous-sequence de la polyligne entre deux indices (inclus).
  static List<LatLng> slice(List<LatLng> polyline, int from, int to) {
    if (polyline.isEmpty) return const [];
    final start = from.clamp(0, polyline.length - 1);
    final end = to.clamp(0, polyline.length - 1);
    if (start <= end) return polyline.sublist(start, end + 1);
    return polyline.sublist(end, start + 1).reversed.toList();
  }
}
