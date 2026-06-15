import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wazibus_nantes/services/disruption_service.dart';

/// Réponse ODS réduite, fidèle au format observé sur l'API info-trafic.
const _sampleBody = '''
{
  "total_count": 4,
  "results": [
    {
      "code": "25250",
      "intitule": "Travaux bd Salvador Allende à Bouguenais",
      "resume": "En raison de travaux, la ligne 88 est déviée.",
      "texte_vocal": null,
      "date_debut": "2026-04-13",
      "date_fin": "2026-07-03",
      "perturbation_terminee": 0,
      "troncons": "[88/1/-/-]"
    },
    {
      "code": "25246",
      "intitule": "Problème technique passage à niveau - Rezé",
      "resume": null,
      "texte_vocal": "Passage à niveau bloqué",
      "date_debut": "2026-06-01",
      "date_fin": "2026-12-31",
      "perturbation_terminee": 0,
      "troncons": "[97/-/-/-]"
    },
    {
      "code": "11111",
      "intitule": "Perturbation terminée",
      "resume": "Texte",
      "date_debut": "2026-06-01",
      "date_fin": "2026-12-31",
      "perturbation_terminee": 1,
      "troncons": "[1/1/-/-]"
    },
    {
      "code": "22222",
      "intitule": "Perturbation passée",
      "resume": "Texte",
      "date_debut": "2026-01-01",
      "date_fin": "2026-02-01",
      "perturbation_terminee": 0,
      "troncons": "[2/1/-/-]"
    }
  ]
}
''';

void main() {
  final today = DateTime(2026, 6, 14);

  test('mappe les perturbations actives en Report officiels', () async {
    final service = DisruptionService(
      client: MockClient((req) async {
        expect(req.url.host, 'data.nantesmetropole.fr');
        return http.Response(_sampleBody, 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

    final reports = await service.fetchActiveDisruptions(now: today);

    // 2 actives retenues : la terminée et la passée sont écartées.
    expect(reports.length, 2);
    expect(reports.every((r) => r.isOfficial), isTrue);

    final l88 = reports.firstWhere((r) => r.routeId == '88');
    expect(l88.reportType, 'works'); // "travaux"
    expect(l88.description, contains('déviée'));
    expect(l88.id, 'disruption:25250:88');

    final l97 = reports.firstWhere((r) => r.routeId == '97');
    expect(l97.reportType, 'breakdown'); // "passage à niveau / technique"
    // resume null -> repli sur l'intitulé pour la description.
    expect(l97.description, contains('passage à niveau'));
  });

  test('renvoie une liste vide en cas d\'erreur réseau', () async {
    final service = DisruptionService(
      client: MockClient((req) async => http.Response('boom', 500)),
    );
    expect(await service.fetchActiveDisruptions(now: today), isEmpty);
  });

  test('extrait plusieurs lignes d\'un tronçon composite', () async {
    final body = jsonEncode({
      'results': [
        {
          'code': '999',
          'intitule': 'Manifestation centre-ville',
          'resume': 'Lignes déviées',
          'date_debut': '2026-06-01',
          'date_fin': '2026-12-31',
          'perturbation_terminee': 0,
          'troncons': '[C1/1/-/-][2/2/-/-]',
        }
      ]
    });
    final service = DisruptionService(
      client: MockClient((req) async => http.Response(body, 200)),
    );
    final reports = await service.fetchActiveDisruptions(now: today);
    expect(reports.map((r) => r.routeId).toSet(), {'C1', '2'});
    expect(reports.every((r) => r.reportType == 'safety'), isTrue);
  });
}
