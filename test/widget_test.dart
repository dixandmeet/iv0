// Tests unitaires de la logique métier de Wazibus Nantes.
//
// On évite ici un test de widget complet (pumpWidget) car l'application
// dépend de plugins natifs (SharedPreferences, Supabase, Geolocator) qui ne
// sont pas disponibles dans l'environnement de test sans configuration.
// On vérifie plutôt la logique pure des modèles et services.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:wazibus_nantes/models/community_vehicle.dart';
import 'package:wazibus_nantes/models/report.dart';
import 'package:wazibus_nantes/services/map_service.dart';

void main() {
  group('CommunityVehicle.reliabilityLevel', () {
    CommunityVehicle vehicleWithScore(int score) => CommunityVehicle(
          id: 'cv',
          routeId: '1',
          transportType: 'tram',
          position: const LatLng(47.21, -1.55),
          speed: 8.0,
          heading: 90.0,
          confidenceScore: score,
          activeUserCount: 3,
          lastSeenAt: DateTime.now(),
        );

    test('score élevé => fiabilité forte', () {
      expect(vehicleWithScore(85).reliabilityLevel, 'fort');
    });

    test('score moyen => fiabilité moyenne', () {
      expect(vehicleWithScore(60).reliabilityLevel, 'moyen');
    });

    test('score faible => fiabilité faible', () {
      expect(vehicleWithScore(20).reliabilityLevel, 'faible');
    });
  });

  group('Report.typeLabel', () {
    Report reportOfType(String type) => Report(
          id: 'r',
          routeId: '4',
          reportType: type,
          position: const LatLng(47.21, -1.55),
          timestamp: DateTime.now(),
        );

    test('traduit les types connus en français', () {
      expect(reportOfType('delay').typeLabel, 'Retard');
      expect(reportOfType('crowded').typeLabel, 'Véhicule bondé');
      expect(reportOfType('control').typeLabel, 'Contrôle en cours');
    });

    test('retombe sur un libellé générique pour un type inconnu', () {
      expect(reportOfType('unknown_type').typeLabel, 'Signalement');
    });
  });

  group('MapService', () {
    final mapService = MapService();

    test('associe la bonne couleur de marque au type de transport', () {
      // Couleurs sémantiques carte alignées Aule (cf. map_service.dart).
      expect(mapService.getTransportColor('tram'), const Color(0xFF1B66F5));
      expect(mapService.getTransportColor('busway'), const Color(0xFFF59E0B));
      expect(mapService.getTransportColor('navibus'), const Color(0xFF2FA9C4));
    });

    test('utilise la couleur hexadécimale fournie si disponible', () {
      expect(
        mapService.getTransportColor('bus', routeColorHex: 'FF0000'),
        const Color(0xFFFF0000),
      );
    });

    test('retourne un libellé lisible', () {
      expect(mapService.getTransportLabel('tram'), 'Tramway');
      expect(mapService.getTransportLabel('navibus'), 'Navibus');
    });
  });
}
