import 'package:flutter_test/flutter_test.dart';
import 'package:aule_pro/models/driver/driver_onboarding_data.dart';

void main() {
  group('Dépôts — contrat de codes (clé de matching)', () {
    test('chaque dépôt expose le code métier attendu', () {
      expect(DriverDepot.bele.code, 'BLX');
      expect(DriverDepot.trentemoult.code, 'TTX');
      expect(DriverDepot.semitan.code, 'SHX');
    });

    test('fromCode retrouve le dépôt à partir du code', () {
      for (final d in DriverDepot.values) {
        expect(DriverDepot.fromCode(d.code), d, reason: d.name);
      }
    });

    test('fromCode tolère null et code inconnu', () {
      expect(DriverDepot.fromCode(null), isNull);
      expect(DriverDepot.fromCode('ZZZ'), isNull);
    });
  });
}
