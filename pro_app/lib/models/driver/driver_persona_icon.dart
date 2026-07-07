import 'driver_onboarding_data.dart';
import 'driver_workspace_mode.dart';

/// Icônes persona conducteur / agent MSR (vue du dessus).
abstract final class DriverPersonaIcon {
  static const conducteurHomme = 'assets/images/conducteur_H.png';
  static const controleurHomme = 'assets/images/controleur_H.png';
  static const controleurFemme = 'assets/images/controleur_F.png';

  /// Asset à afficher selon le mode workspace et le genre, ou `null` (initiales).
  static String? assetFor({
    required DriverWorkspaceMode workspace,
    required DriverGender? gender,
  }) {
    return switch (workspace) {
      DriverWorkspaceMode.conduite => switch (gender) {
          DriverGender.homme => conducteurHomme,
          _ => null,
        },
      DriverWorkspaceMode.controle ||
      DriverWorkspaceMode.intervention =>
        switch (gender) {
          DriverGender.homme => controleurHomme,
          DriverGender.femme => controleurFemme,
          _ => null,
        },
    };
  }
}
