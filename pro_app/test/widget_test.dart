// Tests unitaires de base d'Aule Pro.

import 'package:flutter_test/flutter_test.dart';

import 'package:shared/shared.dart';

void main() {
  group('AppUserRole.fromDb', () {
    test('mappe les rôles professionnels mobiles', () {
      expect(AppUserRoleX.fromDb('driver'), AppUserRole.driver);
      expect(AppUserRoleX.fromDb('msr_agent'), AppUserRole.msrAgent);
    });

    test('replie tout rôle inconnu vers passenger', () {
      expect(AppUserRoleX.fromDb('inconnu'), AppUserRole.passenger);
      expect(AppUserRoleX.fromDb('passenger'), AppUserRole.passenger);
    });

    test('isMobileStaff vrai pour conducteur et agent MSR', () {
      expect(AppUserRole.driver.isMobileStaff, isTrue);
      expect(AppUserRole.msrAgent.isMobileStaff, isTrue);
      expect(AppUserRole.passenger.isMobileStaff, isFalse);
    });
  });
}
