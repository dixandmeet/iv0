import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/gtfs.dart';
import '../../services/driver/driver_service.dart';
import '../../services/gtfs_service.dart';

/// Prise de service : le conducteur confirme service / véhicule / ligne /
/// direction / géolocalisation, puis démarre.
class DriverTakeServiceScreen extends StatefulWidget {
  const DriverTakeServiceScreen({super.key});

  @override
  State<DriverTakeServiceScreen> createState() =>
      _DriverTakeServiceScreenState();
}

class _DriverTakeServiceScreenState extends State<DriverTakeServiceScreen> {
  final _vehicleController = TextEditingController();

  List<GtfsRoute> _routes = [];
  bool _loadingRoutes = true;

  GtfsRoute? _selectedRoute;
  int _directionId = 0; // 0 / 1
  bool _locationConsent = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final gtfs = context.read<GtfsService>();
    // Service planifié éventuel, lu avant tout await pour le pré-remplissage.
    final planned = context.read<DriverService>().currentService;

    final routes = await gtfs.fetchRoutes();
    routes.sort(_compareRoutes);
    GtfsRoute? preset;
    if (planned?.lineId != null) {
      preset = routes
          .where((r) => r.routeId == planned!.lineId)
          .cast<GtfsRoute?>()
          .firstWhere((r) => r != null, orElse: () => null);
    }

    if (!mounted) return;
    setState(() {
      _routes = routes;
      _selectedRoute = preset;
      _directionId = planned?.directionId ?? 0;
      if (planned?.vehicleId != null) {
        _vehicleController.text = planned!.vehicleId!;
      }
      _loadingRoutes = false;
    });
  }

  int _compareRoutes(GtfsRoute a, GtfsRoute b) {
    final an = int.tryParse(a.routeShortName ?? a.routeId);
    final bn = int.tryParse(b.routeShortName ?? b.routeId);
    if (an != null && bn != null) return an.compareTo(bn);
    return (a.routeShortName ?? a.routeId)
        .compareTo(b.routeShortName ?? b.routeId);
  }

  /// Deux destinations probables déduites du nom long de la ligne.
  List<String> _termini(GtfsRoute route) {
    final name = route.routeLongName ?? '';
    final parts = name
        .split(RegExp(r'\s*[-–—↔→/<>]+\s*'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) return [parts.first, parts.last];
    return ['Sens 0', 'Sens 1'];
  }

  String _routeLabel(GtfsRoute r) {
    final short = r.routeShortName ?? r.routeId;
    final long = r.routeLongName;
    return long != null && long.isNotEmpty ? '$short · $long' : 'Ligne $short';
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _selectedRoute != null && _locationConsent && !_submitting;

  Future<void> _submit() async {
    final route = _selectedRoute;
    if (route == null) return;

    setState(() => _submitting = true);
    final termini = _termini(route);
    final headsign =
        _directionId == 0 ? termini.last : termini.first; // dir 0 → destination

    final ok = await context.read<DriverService>().takeService(
          vehicleId: _vehicleController.text.trim().isEmpty
              ? null
              : _vehicleController.text.trim(),
          lineId: route.routeId,
          directionId: _directionId,
          headsign: headsign,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service démarré · suivi GPS actif')),
      );
    } else {
      final err = context.read<DriverService>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Échec de la prise de service')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Prise de service')),
      body: _loadingRoutes
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  'Confirmez les éléments de votre service avant de démarrer.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),

                // Ligne
                const _SectionLabel(
                    icon: LucideIcons.busFront, label: 'Ligne'),
                const SizedBox(height: 8),
                DropdownButtonFormField<GtfsRoute>(
                  initialValue: _selectedRoute,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Sélectionner une ligne',
                  ),
                  items: _routes
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(_routeLabel(r),
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (r) => setState(() {
                    _selectedRoute = r;
                    _directionId = 0;
                  }),
                ),
                const SizedBox(height: 20),

                // Direction
                const _SectionLabel(
                    icon: LucideIcons.arrowRight, label: 'Direction'),
                const SizedBox(height: 8),
                if (_selectedRoute == null)
                  Text('Choisissez d\'abord une ligne.',
                      style: theme.textTheme.bodySmall)
                else
                  _DirectionSelector(
                    termini: _termini(_selectedRoute!),
                    selected: _directionId,
                    onChanged: (d) => setState(() => _directionId = d),
                  ),
                const SizedBox(height: 20),

                // Véhicule
                const _SectionLabel(
                    icon: LucideIcons.bus, label: 'Véhicule'),
                const SizedBox(height: 8),
                TextField(
                  controller: _vehicleController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Numéro de véhicule (ex. 8421)',
                  ),
                ),
                const SizedBox(height: 20),

                // Géolocalisation
                const _SectionLabel(
                    icon: LucideIcons.mapPin, label: 'Géolocalisation'),
                const SizedBox(height: 4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _locationConsent,
                  onChanged: (v) =>
                      setState(() => _locationConsent = v ?? false),
                  title: const Text(
                      'J\'autorise le partage de ma position pendant le service'),
                  subtitle: Text(
                    'La position n\'est transmise que tant que le service est actif.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: _canSubmit ? _submit : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.play),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Je prends mon service',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(label,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _DirectionSelector extends StatelessWidget {
  final List<String> termini;
  final int selected;
  final ValueChanged<int> onChanged;

  const _DirectionSelector({
    required this.termini,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // direction 0 → vers termini.last ; direction 1 → vers termini.first
    final options = <int, String>{
      0: '→ ${termini.last}',
      1: '→ ${termini.first}',
    };
    return Column(
      children: options.entries.map((e) {
        final isSelected = selected == e.key;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onChanged(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e.value)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
