import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum MapDayPeriod { dawn, day, dusk, night }

enum MapWeatherCondition { clear, cloudy, fog, rain, snow, storm }

@immutable
class MapWeatherSnapshot {
  final MapDayPeriod period;
  final MapWeatherCondition condition;
  final double? temperature;
  final bool live;

  const MapWeatherSnapshot({
    required this.period,
    required this.condition,
    this.temperature,
    this.live = false,
  });

  factory MapWeatherSnapshot.fallback([DateTime? now]) => MapWeatherSnapshot(
    period: _fallbackPeriod(now ?? DateTime.now()),
    condition: MapWeatherCondition.clear,
  );

  bool get isDark => period == MapDayPeriod.night;

  String get baseMapStyleUrl => isDark
      ? 'https://tiles.openfreemap.org/styles/dark'
      : 'https://tiles.openfreemap.org/styles/liberty';

  String get rasterTileUrl => isDark
      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
      : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

  String get label {
    final weather = switch (condition) {
      MapWeatherCondition.clear => 'Ciel dégagé',
      MapWeatherCondition.cloudy => 'Nuageux',
      MapWeatherCondition.fog => 'Brume',
      MapWeatherCondition.rain => 'Pluie',
      MapWeatherCondition.snow => 'Neige',
      MapWeatherCondition.storm => 'Orage',
    };
    final moment = switch (period) {
      MapDayPeriod.dawn => 'lever du jour',
      MapDayPeriod.day => 'journée',
      MapDayPeriod.dusk => 'soirée',
      MapDayPeriod.night => 'nuit',
    };
    return '$weather · $moment';
  }

  String get signature => '${period.name}-${condition.name}';
}

/// Météo commune aux cartes SAE. Les coordonnées sont arrondies à environ
/// 1 km avant l'appel afin de ne pas transmettre la position GPS précise.
class MapWeatherController extends ChangeNotifier {
  static const _refreshDelay = Duration(minutes: 15);

  final http.Client _client;
  Timer? _timer;
  LatLng? _location;
  MapWeatherSnapshot _value = MapWeatherSnapshot.fallback();
  bool _disposed = false;

  MapWeatherController({http.Client? client})
    : _client = client ?? http.Client();

  MapWeatherSnapshot get value => _value;

  void start(LatLng location) {
    _location = location;
    unawaited(refresh());
    _timer?.cancel();
    _timer = Timer.periodic(_refreshDelay, (_) => unawaited(refresh()));
  }

  void updateLocation(LatLng location) {
    final previous = _location;
    _location = location;
    if (previous == null ||
        (previous.latitude - location.latitude).abs() > 0.02 ||
        (previous.longitude - location.longitude).abs() > 0.02) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    final location = _location;
    if (location == null || _disposed) return;
    final latitude = (location.latitude * 100).round() / 100;
    final longitude = (location.longitude * 100).round() / 100;
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(2),
      'longitude': longitude.toStringAsFixed(2),
      'current':
          'temperature_2m,weather_code,precipitation,rain,showers,snowfall',
      'daily': 'sunrise,sunset',
      'timezone': 'auto',
      'forecast_days': '1',
    });

    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>?;
      final daily = json['daily'] as Map<String, dynamic>?;
      final period = _periodFromApi(
        current?['time'] as String?,
        _firstString(daily?['sunrise']),
        _firstString(daily?['sunset']),
      );
      final next = MapWeatherSnapshot(
        period: period,
        condition: _conditionFromApi(current),
        temperature: (current?['temperature_2m'] as num?)?.toDouble(),
        live: true,
      );
      if (_disposed ||
          next.signature == _value.signature &&
              next.temperature == _value.temperature) {
        return;
      }
      _value = next;
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      final fallback = MapWeatherSnapshot(
        period: _fallbackPeriod(DateTime.now()),
        condition: _value.condition,
        temperature: _value.temperature,
      );
      if (fallback.signature != _value.signature || _value.live) {
        _value = fallback;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _client.close();
    super.dispose();
  }
}

String? _firstString(dynamic value) {
  if (value is List && value.isNotEmpty && value.first is String) {
    return value.first as String;
  }
  return null;
}

int? _minutes(String? value) {
  if (value == null) return null;
  final match = RegExp(r'T(\d{2}):(\d{2})').firstMatch(value);
  if (match == null) return null;
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
}

MapDayPeriod _periodFromApi(String? current, String? sunrise, String? sunset) {
  final now = _minutes(current);
  final rise = _minutes(sunrise);
  final set = _minutes(sunset);
  if (now == null || rise == null || set == null) {
    return _fallbackPeriod(DateTime.now());
  }
  if (now < rise - 50 || now > set + 70) return MapDayPeriod.night;
  if (now <= rise + 80) return MapDayPeriod.dawn;
  if (now >= set - 70) return MapDayPeriod.dusk;
  return MapDayPeriod.day;
}

MapDayPeriod _fallbackPeriod(DateTime now) {
  if (now.hour < 6 || now.hour >= 22) return MapDayPeriod.night;
  if (now.hour < 9) return MapDayPeriod.dawn;
  if (now.hour < 19) return MapDayPeriod.day;
  return MapDayPeriod.dusk;
}

MapWeatherCondition _conditionFromApi(Map<String, dynamic>? current) {
  final code = (current?['weather_code'] as num?)?.toInt() ?? 0;
  final precipitation = (current?['precipitation'] as num?)?.toDouble() ?? 0;
  if (code == 95 || code == 96 || code == 99) {
    return MapWeatherCondition.storm;
  }
  if (code >= 71 && code <= 86) return MapWeatherCondition.snow;
  if ((code >= 51 && code <= 67) ||
      (code >= 80 && code <= 82) ||
      precipitation > 0) {
    return MapWeatherCondition.rain;
  }
  if (code == 45 || code == 48) return MapWeatherCondition.fog;
  if (code >= 1 && code <= 3) return MapWeatherCondition.cloudy;
  return MapWeatherCondition.clear;
}
