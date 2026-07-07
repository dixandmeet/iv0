import 'package:flutter_test/flutter_test.dart';
import 'package:aule_pro/models/driver/driver_onboarding_data.dart';

void main() {
  bool valid(Set<DriverHabilitation> h) =>
      DriverOnboardingData.isHabilitationSetValid(h);

  const conduite = DriverHabilitation.conduite;
  const controle = DriverHabilitation.controle;
  const intervention = DriverHabilitation.intervention;
  const umtc = DriverHabilitation.umtc;

  group('Habilitations — combinaisons autorisées', () {
    test('chaque habilitation seule est valide', () {
      for (final h in DriverHabilitation.values) {
        expect(valid({h}), isTrue, reason: '${h.name} seul');
      }
    });

    test('Conduite + Contrôle est valide', () {
      expect(valid({conduite, controle}), isTrue);
    });

    test('Conduite + Intervention est valide', () {
      expect(valid({conduite, intervention}), isTrue);
    });
  });

  group('Habilitations — combinaisons interdites', () {
    test('Conduite + UMTC est interdit', () {
      expect(valid({conduite, umtc}), isFalse);
    });

    test('Contrôle + Intervention est interdit', () {
      expect(valid({controle, intervention}), isFalse);
    });

    test('Contrôle + UMTC est interdit', () {
      expect(valid({controle, umtc}), isFalse);
    });

    test('Intervention + UMTC est interdit', () {
      expect(valid({intervention, umtc}), isFalse);
    });

    test('toute combinaison de trois est interdite', () {
      expect(valid({conduite, controle, intervention}), isFalse);
    });

    test('toutes les habilitations est interdit', () {
      expect(valid(DriverHabilitation.values.toSet()), isFalse);
    });

    test('UMTC est toujours exclusive', () {
      for (final other in [conduite, controle, intervention]) {
        expect(valid({umtc, other}), isFalse, reason: 'umtc + ${other.name}');
      }
    });
  });
}
