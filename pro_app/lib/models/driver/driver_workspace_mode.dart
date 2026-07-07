import 'package:flutter/material.dart';

import '../../theme/driver_home_palette.dart';

/// Mode opérationnel de l'espace conducteur (conduite ou mission MSR).
enum DriverWorkspaceMode { conduite, controle, intervention }

extension DriverWorkspaceModeX on DriverWorkspaceMode {
  String get label {
    switch (this) {
      case DriverWorkspaceMode.conduite:
        return 'Conduite';
      case DriverWorkspaceMode.controle:
        return 'Contrôle';
      case DriverWorkspaceMode.intervention:
        return 'Intervention';
    }
  }

  String get statusBadgeLabel {
    switch (this) {
      case DriverWorkspaceMode.conduite:
        return 'En service';
      case DriverWorkspaceMode.controle:
        return 'Mission contrôle';
      case DriverWorkspaceMode.intervention:
        return 'Mission intervention';
    }
  }

  String get menuRoleLabel {
    switch (this) {
      case DriverWorkspaceMode.conduite:
        return 'Conducteur';
      case DriverWorkspaceMode.controle:
        return 'Agent MSR · Contrôle';
      case DriverWorkspaceMode.intervention:
        return 'Agent MSR · Intervention';
    }
  }

  Color get accentColor {
    switch (this) {
      case DriverWorkspaceMode.conduite:
        return DriverHomePalette.primary;
      case DriverWorkspaceMode.controle:
        return DriverHomePalette.controlAccent;
      case DriverWorkspaceMode.intervention:
        return DriverHomePalette.warning;
    }
  }

  static DriverWorkspaceMode? fromStorage(String? value) {
    switch (value) {
      case 'controle':
        return DriverWorkspaceMode.controle;
      case 'intervention':
        return DriverWorkspaceMode.intervention;
      case 'conduite':
        return DriverWorkspaceMode.conduite;
      default:
        return null;
    }
  }

  String get storageKey {
    switch (this) {
      case DriverWorkspaceMode.conduite:
        return 'conduite';
      case DriverWorkspaceMode.controle:
        return 'controle';
      case DriverWorkspaceMode.intervention:
        return 'intervention';
    }
  }
}
