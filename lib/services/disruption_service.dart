import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/report.dart';

/// Perturbations officielles du réseau Naolib (info-trafic temps réel).
///
/// Source : API Opendatasoft de Nantes Métropole, en **accès libre** (sans
/// clé). Renvoie les perturbations en cours sous forme de [Report] marqués
/// [Report.isOfficial], fusionnés ensuite avec les signalements
/// communautaires par le [ReportService].
///
/// Expose en plus un cache partagé (via [ChangeNotifier]) pour que les fiches
/// d'arrêt et de ligne puissent savoir, sans nouvelle requête, si une ligne
/// est perturbée ([hasDisruptionForLine] / [disruptionsForLine]).
class DisruptionService extends ChangeNotifier {
  static const String _endpoint =
      'https://data.nantesmetropole.fr/api/explore/v2.1/catalog/datasets/'
      '244400404_info-trafic-tan-temps-reel/records';

  static const Duration _timeout = Duration(seconds: 8);

  /// Durée de fraîcheur du cache partagé.
  static const Duration _cacheTtl = Duration(minutes: 2);

  /// Position de repli (Place du Commerce) : l'info-trafic ne fournit pas de
  /// coordonnées exploitables, ces perturbations ne sont donc pas épinglées
  /// sur la carte (cf. [Report.isOfficial]).
  static const LatLng _fallbackPosition = LatLng(47.218371, -1.553621);

  final http.Client _client;

  DisruptionService({http.Client? client}) : _client = client ?? http.Client();

  // --- Cache partagé --------------------------------------------------------
  List<Report> _cached = const [];
  DateTime? _fetchedAt;
  bool _loading = false;
  Future<void>? _inFlight;

  List<Report> get cached => List.unmodifiable(_cached);
  bool get isLoading => _loading;

  bool get _isFresh =>
      _fetchedAt != null && DateTime.now().difference(_fetchedAt!) < _cacheTtl;

  /// Charge (ou rafraîchit) le cache partagé. Dédoublonne les appels
  /// concurrents et ne refait pas de requête tant que le cache est frais.
  Future<void> load({bool force = false}) {
    if (!force && _isFresh) return Future.value();
    if (_inFlight != null) return _inFlight!;
    _loading = true;
    notifyListeners();
    final future = fetchActiveDisruptions().then((reports) {
      _cached = reports;
      _fetchedAt = DateTime.now();
    }).whenComplete(() {
      _loading = false;
      _inFlight = null;
      notifyListeners();
    });
    _inFlight = future;
    return future;
  }

  /// Codes de lignes (normalisés majuscules) touchés par une perturbation
  /// rattachée à une ligne précise (les perturbations « Réseau » globales sont
  /// exclues pour ne pas signaler toutes les lignes comme perturbées).
  Set<String> get impactedLineCodes => {
        for (final r in _cached)
          if (r.routeId != 'Réseau') r.routeId.toUpperCase(),
      };

  /// Vrai si la ligne de code [lineCode] est actuellement perturbée.
  bool hasDisruptionForLine(String lineCode) =>
      impactedLineCodes.contains(lineCode.toUpperCase());

  /// Perturbations rattachées à la ligne [lineCode].
  List<Report> disruptionsForLine(String lineCode) {
    final code = lineCode.toUpperCase();
    return [
      for (final r in _cached)
        if (r.routeId.toUpperCase() == code) r,
    ];
  }

  /// Perturbations actives aujourd'hui, une entrée par ligne impactée.
  Future<List<Report>> fetchActiveDisruptions({DateTime? now}) async {
    try {
      final uri = Uri.parse('$_endpoint?limit=100&select='
          'code,intitule,resume,texte_vocal,date_debut,date_fin,'
          'perturbation_terminee,troncons');
      final res = await _client
          .get(uri, headers: {'Accept': 'application/json'}).timeout(_timeout);
      if (res.statusCode != 200 || res.body.isEmpty) return const [];

      final root = jsonDecode(res.body);
      final results = (root is Map ? root['results'] : null) as List?;
      if (results == null || results.isEmpty) return const [];

      final today = now ?? DateTime.now();
      final out = <Report>[];
      final seen = <String>{};
      for (final entry in results) {
        if (entry is! Map) continue;
        if (_asInt(entry['perturbation_terminee']) == 1) continue;
        if (!_isActiveOn(entry, today)) continue;

        final text = _firstText([
          entry['resume'],
          entry['intitule'],
          entry['texte_vocal'],
        ]);
        if (text == null) continue;

        final code = entry['code']?.toString() ?? '';
        // Classification sur l'ensemble du texte disponible (l'intitulé porte
        // souvent le motif « Travaux / Manifestation » absent du résumé).
        final type = _classify([
          entry['intitule'],
          entry['resume'],
          entry['texte_vocal'],
        ].whereType<String>().join(' '));
        final lines = _linesFromTroncons(entry['troncons'] as String?);
        final targets = lines.isEmpty ? const [''] : lines;
        for (final line in targets) {
          final routeId = line.isEmpty ? 'Réseau' : line;
          // Dédoublonne les perturbations multi-tronçons sur une même ligne.
          if (!seen.add('$code|$routeId')) continue;
          out.add(Report(
            id: 'disruption:$code:$routeId',
            routeId: routeId,
            reportType: type,
            position: _fallbackPosition,
            timestamp: today,
            description: text,
            isOfficial: true,
          ));
        }
      }
      return out;
    } catch (e) {
      debugPrint('Aule: official disruptions fetch failed ($e)');
      return const [];
    }
  }

  /// Codes de lignes impactées extraits du champ `troncons`
  /// (ex. `[88/1/-/-][C1/2/-/-]` -> {88, C1}).
  List<String> _linesFromTroncons(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final out = <String>[];
    for (final m in RegExp(r'\[([^\]]+)\]').allMatches(raw)) {
      final parts = m.group(1)!.split('/');
      final code = parts.isNotEmpty ? parts.first.trim() : '';
      if (code.isNotEmpty && code != '-' && !out.contains(code)) out.add(code);
    }
    return out;
  }

  /// Devine le type de signalement à partir du texte de la perturbation.
  String _classify(String text) {
    final t = text.toLowerCase();
    if (t.contains('travaux') || t.contains('chantier')) return 'works';
    if (t.contains('manifestation') ||
        t.contains('sécurité') ||
        t.contains('securite')) {
      return 'safety';
    }
    if (t.contains('panne') ||
        t.contains('technique') ||
        t.contains('passage à niveau') ||
        t.contains('incident')) {
      return 'breakdown';
    }
    if (t.contains('accident') || t.contains('déviée') || t.contains('deviee')) {
      return 'accident';
    }
    if (t.contains('retard')) return 'delay';
    return 'disruption';
  }

  bool _isActiveOn(Map entry, DateTime day) {
    final start = _parseDate(entry['date_debut']);
    final end = _parseDate(entry['date_fin']);
    final d = DateTime(day.year, day.month, day.day);
    if (start != null && d.isBefore(start)) return false;
    if (end != null && d.isAfter(end)) return false;
    return true;
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    // Format ODS : "2026-03-30" (parfois avec un suffixe horaire ISO).
    return DateTime.tryParse(raw.length >= 10 ? raw.substring(0, 10) : raw);
  }

  static int _asInt(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

  static String? _firstText(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c.trim();
    }
    return null;
  }
}
