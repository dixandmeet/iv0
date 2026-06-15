import 'package:latlong2/latlong.dart';

class StopData {
  final String id;
  final String name;
  final int distance; // in meters
  final int walkTime; // in minutes
  final List<String> lines;
  final int? nextPassage; // in minutes (null means not applicable or chevron)
  final int? secondaryPassage; // in minutes
  final LatLng position;

  const StopData({
    required this.id,
    required this.name,
    required this.distance,
    required this.walkTime,
    required this.lines,
    this.nextPassage,
    this.secondaryPassage,
    required this.position,
  });

  static final List<StopData> mockStops = [
    const StopData(
      id: 'ranzay',
      name: 'Ranzay',
      distance: 220,
      walkTime: 3,
      lines: ['1', 'C6', '23', '75', '80'],
      nextPassage: null, // Shows chevron when active, but can default to e.g. 3 min
      secondaryPassage: 8,
      position: LatLng(47.25156, -1.53026),
    ),
    const StopData(
      id: 'haluchere',
      name: 'Haluchère-Batignolles',
      distance: 340,
      walkTime: 5,
      lines: ['C1', '12', '75', '96'],
      nextPassage: 2,
      secondaryPassage: 7,
      position: LatLng(47.25292, -1.52445),
    ),
    const StopData(
      id: 'mendes_france',
      name: 'Mendès France - Bellevue',
      distance: 380,
      walkTime: 6,
      lines: ['23', 'C2', '30'],
      nextPassage: 1,
      secondaryPassage: 9,
      position: LatLng(47.24795, -1.53320),
    ),
    const StopData(
      id: 'facultes',
      name: 'Facultés',
      distance: 420,
      walkTime: 7,
      lines: ['75', '80', 'C20'],
      nextPassage: 3,
      secondaryPassage: 11,
      position: LatLng(47.25580, -1.53420),
    ),
    const StopData(
      id: 'beaujoire',
      name: 'Beaujoire',
      distance: 480,
      walkTime: 8,
      lines: ['1', 'C6'],
      nextPassage: 4,
      secondaryPassage: 12,
      position: LatLng(47.25625, -1.52980),
    ),
    const StopData(
      id: 'chantrerie',
      name: 'Chantrerie - Grandes Écoles',
      distance: 500,
      walkTime: 8,
      lines: ['C6', 'E1'],
      nextPassage: 5,
      secondaryPassage: 13,
      position: LatLng(47.24650, -1.52550),
    ),
  ];
}
