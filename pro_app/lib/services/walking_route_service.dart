import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../utils/map_path_utils.dart';

/// Routage piéton via OSRM (réseau routier) avec repli hors-ligne.
class WalkingRouteService {
  WalkingRouteService._();

  static final _cache = <String, List<LatLng>>{};
  static final _client = http.Client();

  static String _cacheKey(LatLng from, LatLng to) =>
      '${from.latitude.toStringAsFixed(5)},${from.longitude.toStringAsFixed(5)}|'
      '${to.latitude.toStringAsFixed(5)},${to.longitude.toStringAsFixed(5)}';

  /// Chemin piéton réaliste ; retourne immédiatement le cache ou le repli L.
  static List<LatLng> immediate(LatLng from, LatLng to) {
    return _cache[_cacheKey(from, to)] ?? MapPathUtils.walkingPath(from, to);
  }

  /// Tente OSRM puis met en cache ; retourne le repli si échec.
  static Future<List<LatLng>> resolve(LatLng from, LatLng to) async {
    final key = _cacheKey(from, to);
    final cached = _cache[key];
    if (cached != null) return cached;

    final fallback = MapPathUtils.walkingPath(from, to);
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/foot/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['code'] == 'Ok') {
          final routes = body['routes'] as List<dynamic>?;
          final route = routes?.isNotEmpty == true
              ? routes!.first as Map<String, dynamic>
              : null;
          final geometry = route?['geometry'] as Map<String, dynamic>?;
          final coords = geometry?['coordinates'] as List<dynamic>?;
          if (coords != null && coords.length >= 2) {
            final points = coords
                .map(
                  (c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ),
                )
                .toList();
            final densified = MapPathUtils.densify(points, stepMeters: 7);
            _cache[key] = densified;
            return densified;
          }
        }
      }
    } catch (_) {
      // Repli silencieux sur le tracé L.
    }

    _cache[key] = fallback;
    return fallback;
  }
}
