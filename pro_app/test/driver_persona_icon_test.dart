import 'package:aule_pro/models/driver/driver_onboarding_data.dart';
import 'package:aule_pro/models/driver/driver_persona_icon.dart';
import 'package:aule_pro/models/driver/driver_workspace_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverPersonaIcon.assetFor', () {
    test('conduite + homme → conducteur', () {
      expect(
        DriverPersonaIcon.assetFor(
          workspace: DriverWorkspaceMode.conduite,
          gender: DriverGender.homme,
        ),
        DriverPersonaIcon.conducteurHomme,
      );
    });

    test('controle + femme → contrôleur F', () {
      expect(
        DriverPersonaIcon.assetFor(
          workspace: DriverWorkspaceMode.controle,
          gender: DriverGender.femme,
        ),
        DriverPersonaIcon.controleurFemme,
      );
    });

    test('intervention + homme → contrôleur H', () {
      expect(
        DriverPersonaIcon.assetFor(
          workspace: DriverWorkspaceMode.intervention,
          gender: DriverGender.homme,
        ),
        DriverPersonaIcon.controleurHomme,
      );
    });

    test('conduite + femme → null (initiales)', () {
      expect(
        DriverPersonaIcon.assetFor(
          workspace: DriverWorkspaceMode.conduite,
          gender: DriverGender.femme,
        ),
        isNull,
      );
    });
  });
}
