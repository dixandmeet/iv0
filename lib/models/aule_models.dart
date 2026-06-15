import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../theme/aule_theme.dart';

class AuleLineDeparture {
  final String label;
  final String destination;
  final String modeLabel;
  final AuleLineMode mode;
  final DateTime arrivalAt;
  final Color? lineColor;

  const AuleLineDeparture({
    required this.label,
    required this.destination,
    required this.modeLabel,
    required this.mode,
    required this.arrivalAt,
    this.lineColor,
  });
}

class AuleStopData {
  final String name;
  final String distance;
  final String walkTime;
  final bool accessible;
  final List<AuleLineDeparture> lines;

  const AuleStopData({
    required this.name,
    required this.distance,
    required this.walkTime,
    required this.accessible,
    required this.lines,
  });
}

class AuleVehicleData {
  final String label;
  final AuleLineMode mode;
  final DateTime arrivalAt;
  final LatLng? position;
  final Color? lineColor;

  const AuleVehicleData({
    required this.label,
    required this.mode,
    required this.arrivalAt,
    this.position,
    this.lineColor,
  });
}

class AuleAlertData {
  final String line;
  final AuleLineMode mode;
  final String type;
  final String text;

  const AuleAlertData({
    required this.line,
    required this.mode,
    required this.type,
    required this.text,
  });
}

class AuleNetworkLine {
  final String code;
  final String terminus;
  final String modeLabel;
  final AuleLineMode mode;
  final String frequency;
  final bool disrupted;

  const AuleNetworkLine({
    required this.code,
    required this.terminus,
    required this.modeLabel,
    required this.mode,
    required this.frequency,
    this.disrupted = false,
  });
}

class AuleSuggestionView {
  final String timeLabel;
  final String line;
  final String title;
  final DateTime? arrivalAt;

  const AuleSuggestionView({
    required this.timeLabel,
    required this.line,
    required this.title,
    this.arrivalAt,
  });
}

/// Instantané des données voyageur pour l'écran Accueil Aule.
class AuleHomeSnapshot {
  final List<AuleStopData> stops;
  final List<AuleLineDeparture> departures;
  final List<AuleVehicleData> vehicles;
  final List<AuleAlertData> alerts;
  final AuleSuggestionView? suggestion;
  final int networkHealthPercent;
  final int networkDisruptions;
  final bool hasGps;
  final bool isOffline;

  const AuleHomeSnapshot({
    required this.stops,
    required this.departures,
    required this.vehicles,
    required this.alerts,
    this.suggestion,
    required this.networkHealthPercent,
    required this.networkDisruptions,
    required this.hasGps,
    required this.isOffline,
  });

  static const empty = AuleHomeSnapshot(
    stops: [],
    departures: [],
    vehicles: [],
    alerts: [],
    networkHealthPercent: 98,
    networkDisruptions: 0,
    hasGps: false,
    isOffline: false,
  );
}
