import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/driver/driver_profile.dart';
import '../../models/driver/driver_workspace_mode.dart';
import 'driver_service.dart';

/// Résultat d'une tentative de bascule de mode.
enum WorkspaceSwitchResult {
  /// Bascule effectuée.
  switched,

  /// Service conducteur actif : confirmation requise avant bascule MSR.
  needsConfirmation,

  /// Mode cible identique ou non autorisé.
  unchanged,
}

/// État du mode opérationnel (Conduite / Contrôle / Intervention).
class DriverWorkspaceService with ChangeNotifier {
  static const _keyMode = 'aule_pro_workspace_mode';

  bool _loaded = false;
  DriverWorkspaceMode _currentMode = DriverWorkspaceMode.conduite;

  bool get loaded => _loaded;
  DriverWorkspaceMode get currentMode => _currentMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currentMode =
        DriverWorkspaceModeX.fromStorage(prefs.getString(_keyMode)) ??
            DriverWorkspaceMode.conduite;
    _loaded = true;
    notifyListeners();
  }

  /// Modes disponibles selon les habilitations MSR du conducteur.
  List<DriverWorkspaceMode> availableModes(DriverProfile? profile) {
    if (profile == null || !profile.hasMsrCapabilities) {
      return const [DriverWorkspaceMode.conduite];
    }
    final modes = <DriverWorkspaceMode>[DriverWorkspaceMode.conduite];
    if (profile.msrControl) modes.add(DriverWorkspaceMode.controle);
    if (profile.msrIntervention) modes.add(DriverWorkspaceMode.intervention);
    return modes;
  }

  /// Tente de basculer vers [target]. Si un service conducteur est actif et
  /// que la cible est MSR, retourne [WorkspaceSwitchResult.needsConfirmation].
  WorkspaceSwitchResult trySwitchMode(
    DriverWorkspaceMode target, {
    required DriverProfile? profile,
    required bool hasActiveService,
  }) {
    final allowed = availableModes(profile);
    if (!allowed.contains(target) || target == _currentMode) {
      return WorkspaceSwitchResult.unchanged;
    }
    if (target != DriverWorkspaceMode.conduite && hasActiveService) {
      return WorkspaceSwitchResult.needsConfirmation;
    }
    return WorkspaceSwitchResult.switched;
  }

  /// Applique la bascule (après confirmation éventuelle) et persiste.
  Future<void> applySwitch(DriverWorkspaceMode target) async {
    if (target == _currentMode) return;
    _currentMode = target;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, target.storageKey);
  }

  /// Bascule complète : termine le service conducteur si [endDrivingService]
  /// est vrai, puis change de mode.
  Future<void> completeSwitch(
    DriverWorkspaceMode target, {
    required DriverService driver,
    required bool endDrivingService,
  }) async {
    if (endDrivingService && driver.hasActiveService) {
      await driver.endService();
    }
    await applySwitch(target);
  }

  /// Réinitialise si le mode persisté n'est plus autorisé (ex. déconnexion).
  Future<void> reconcileWithProfile(DriverProfile? profile) async {
    final allowed = availableModes(profile);
    if (allowed.contains(_currentMode)) return;
    await applySwitch(DriverWorkspaceMode.conduite);
  }
}
