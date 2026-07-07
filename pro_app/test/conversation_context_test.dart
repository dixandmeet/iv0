import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aule_pro/models/platform/conversation_context.dart';
import 'package:aule_pro/models/platform/conversation_event.dart';
import 'package:aule_pro/widgets/platform/conversation_context_registry.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('ConversationEvent (mapping resource_events)', () {
    ConversationEvent fromType(String type,
        {String? actor, Map<String, dynamic> payload = const {}}) {
      return ConversationEvent.fromJson({
        'event_type': type,
        'actor_display': actor,
        'payload': payload,
        'created_at': '2026-06-28T13:20:00Z',
      });
    }

    test('libellés humains par type d\'événement', () {
      expect(fromType('published').timelineLabel, 'Annonce publiée');
      expect(fromType('resolved').timelineLabel, 'Échange confirmé');
      expect(fromType('closed').timelineLabel, 'Discussions clôturées');
      expect(fromType('relanced').timelineLabel, 'Annonce relancée');
    });

    test('contacted inclut l\'acteur', () {
      final e = fromType('contacted', actor: 'Marie L.');
      expect(e.timelineLabel, 'Marie L. a contacté l\'auteur');
    });

    test('modified détaille les changements', () {
      final e = fromType('modified', payload: {
        'changes': ['horaires', 'date']
      });
      expect(e.timelineLabel, contains('horaires'));
      expect(e.timelineLabel, contains('date'));
    });

    test('timeLabel formate la date FR', () {
      final e = fromType('published');
      expect(e.timeLabel, isNotEmpty);
    });
  });

  group('ConversationContext', () {
    test('mappe le payload générique', () {
      final ctx = ConversationContext.fromJson({
        'context_type': 'service_exchange',
        'context_id': 'p1',
        'role': 'negotiation',
        'payload': {'id': 'p1', 'title': 'Échange'},
      });
      expect(ctx.contextType, 'service_exchange');
      expect(ctx.contextId, 'p1');
      expect(ctx.role, 'negotiation');
      expect(ctx.payload?['title'], 'Échange');
    });
  });

  group('ConversationContextRegistry (résolution par context_type)', () {
    test('service_exchange est enregistré, les contextes futurs non', () {
      ConversationContextRegistry.ensureRegistered();
      expect(ConversationContextRegistry.supports('service_exchange'), isTrue);
      expect(ConversationContextRegistry.supports('mission'), isFalse);
      expect(ConversationContextRegistry.supports('team'), isFalse);
    });
  });
}
