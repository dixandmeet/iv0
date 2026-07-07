import 'package:shared/shared.dart';

/// Registre déclaratif des panels — aligné sur panel_layouts Supabase.
class PanelRegistry {
  PanelRegistry._();

  /// Panels retirés de l'affichage tant qu'ils ne sont pas alimentés côté
  /// app (aucun flux de création de tâche/upload/carte terrain — cf. audit).
  /// Le layout Supabase (`panel_layouts`) continue de les référencer : ce
  /// filtre est le seul point à retirer pour les réactiver.
  static const _hiddenPanels = {'tasks', 'documents', 'map'};

  static const defaultLayout = [
    PanelLayoutEntry(panel: 'context', capability: null, order: 10, visible: true),
    PanelLayoutEntry(panel: 'discussion', capability: 'discussion', order: 40, visible: true),
    PanelLayoutEntry(panel: 'timeline', capability: 'timeline', order: 60, visible: true),
  ];

  static List<PanelLayoutEntry> resolve({
    required ResourceShellData shell,
  }) {
    final layout = shell.panelLayout.isNotEmpty
        ? shell.panelLayout
        : defaultLayout;

    return layout
        .where((entry) {
          if (_hiddenPanels.contains(entry.panel)) return false;
          if (!entry.visible) return false;
          if (entry.capability == null) return true;
          return shell.hasCapability(entry.capability!);
        })
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  static List<PanelLayoutEntry> fallbackForType(String type) {
    switch (type) {
      case 'mission':
        return const [
          PanelLayoutEntry(panel: 'context', order: 10, visible: true),
          PanelLayoutEntry(panel: 'members', capability: 'members', order: 30, visible: true),
          PanelLayoutEntry(panel: 'discussion', capability: 'discussion', order: 40, visible: true),
          PanelLayoutEntry(panel: 'timeline', capability: 'timeline', order: 60, visible: true),
        ];
      case 'vehicle':
        return const [
          PanelLayoutEntry(panel: 'context', order: 10, visible: true),
          PanelLayoutEntry(panel: 'timeline', capability: 'timeline', order: 30, visible: true),
          PanelLayoutEntry(panel: 'discussion', capability: 'discussion', order: 40, visible: true),
        ];
      case 'team':
        return const [
          PanelLayoutEntry(panel: 'context', order: 10, visible: true),
          PanelLayoutEntry(panel: 'members', capability: 'members', order: 20, visible: true),
          PanelLayoutEntry(panel: 'discussion', capability: 'discussion', order: 30, visible: true),
        ];
      default:
        return defaultLayout;
    }
  }
}
