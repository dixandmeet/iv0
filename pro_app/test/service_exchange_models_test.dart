import 'package:flutter_test/flutter_test.dart';
import 'package:aule_pro/models/driver/service_exchange_post.dart';
import 'package:aule_pro/models/driver/service_exchange_filters.dart';

Map<String, dynamic> _basePost(Map<String, dynamic> overrides) {
  return {
    'id': 'p1',
    'author_id': 'u1',
    'network_code': 'naolib',
    'depot_id': 'd1',
    'depot_name': 'Dépôt Dalby',
    'post_kind': 'request',
    'service_type': 'BUS',
    'required_habilitation': 'conduite',
    'service_date': '2026-07-04',
    'start_time': '13:20',
    'end_time': '20:15',
    'title': 'Échange service 214',
    'status': 'active',
    'visibility': 'public',
    'is_urgent': false,
    'contact_count': 0,
    'view_count': 0,
    'created_at': '2026-06-28T10:00:00Z',
    'updated_at': '2026-06-28T10:00:00Z',
    ...overrides,
  };
}

void main() {
  group('ServiceExchangePost', () {
    test('parse les flags viewer et les énumérations', () {
      final post = ServiceExchangePost.fromJson(_basePost({
        'is_favorited': true,
        'my_reaction': 'like',
        'reaction_likes': 3,
        'is_new': true,
        'is_resolved': false,
      }));

      expect(post.postKind, ServiceExchangePostKind.request);
      expect(post.serviceType, ServiceExchangeServiceType.bus);
      expect(post.status, ServiceExchangeStatus.active);
      expect(post.isFavorited, isTrue);
      expect(post.myReaction, ServiceExchangeReaction.like);
      expect(post.reactionLikes, 3);
      expect(post.isNew, isTrue);
    });

    test('displayTitle préfixe les annonces urgentes', () {
      final normal = ServiceExchangePost.fromJson(_basePost({}));
      final urgent = ServiceExchangePost.fromJson(_basePost({'is_urgent': true}));
      expect(normal.displayTitle, 'Échange service 214');
      expect(urgent.displayTitle, startsWith('⚡'));
    });

    test('serviceRefLabel agrège uniquement les parties présentes', () {
      final full = ServiceExchangePost.fromJson(_basePost({
        'service_number': '214',
        'line_code': '1',
        'vehicle_code': '31',
      }));
      expect(full.serviceRefLabel, 'Service 214 · Ligne 1 · Véhicule 31');

      final partial = ServiceExchangePost.fromJson(_basePost({
        'line_code': '4',
      }));
      expect(partial.serviceRefLabel, 'Ligne 4');

      final none = ServiceExchangePost.fromJson(_basePost({}));
      expect(none.serviceRefLabel, isNull);
    });

    test('periodLabel formate la plage horaire', () {
      final post = ServiceExchangePost.fromJson(_basePost({}));
      expect(post.periodLabel, '13h20 → 20h15');
    });

    test('statusLabel reflète le statut et le nombre de discussions', () {
      final discussing = ServiceExchangePost.fromJson(_basePost({
        'status': 'in_discussion',
        'contact_count': 2,
      }));
      expect(discussing.status, ServiceExchangeStatus.inDiscussion);
      expect(discussing.statusLabel, 'En discussion (2)');

      final agreed = ServiceExchangePost.fromJson(_basePost({
        'status': 'agreed',
        'is_resolved': true,
      }));
      expect(agreed.isResolved, isTrue);
      expect(agreed.statusLabel, 'Échange trouvé');
    });

    test('canExpressInterest seulement si non auteur et ouvert', () {
      final mine = ServiceExchangePost.fromJson(_basePost({'is_mine': true}));
      expect(mine.canExpressInterest, isFalse);

      final other = ServiceExchangePost.fromJson(_basePost({'is_mine': false}));
      expect(other.canExpressInterest, isTrue);

      final closed = ServiceExchangePost.fromJson(
          _basePost({'is_mine': false, 'status': 'agreed'}));
      expect(closed.canExpressInterest, isFalse);
    });

    test('habilitation déduite par type de service (miroir SQL)', () {
      expect(ServiceExchangeServiceType.bus.requiredHabilitation, 'conduite');
      expect(ServiceExchangeServiceType.tram.requiredHabilitation, 'conduite');
      expect(
          ServiceExchangeServiceType.controle.requiredHabilitation, 'controle');
      expect(ServiceExchangeServiceType.intervention.requiredHabilitation,
          'intervention');
      expect(ServiceExchangeServiceType.umtc.requiredHabilitation, 'umtc');
    });
  });

  group('ServiceExchangeFilters', () {
    test('hasActiveFilters détecte les filtres posés', () {
      const empty = ServiceExchangeFilters();
      expect(empty.hasActiveFilters, isFalse);

      const withType =
          ServiceExchangeFilters(serviceType: ServiceExchangeServiceType.tram);
      expect(withType.hasActiveFilters, isTrue);
    });

    test('copyWith permet de retirer un filtre', () {
      const f =
          ServiceExchangeFilters(serviceType: ServiceExchangeServiceType.bus);
      final cleared = f.copyWith(clearServiceType: true);
      expect(cleared.serviceType, isNull);
    });
  });
}
