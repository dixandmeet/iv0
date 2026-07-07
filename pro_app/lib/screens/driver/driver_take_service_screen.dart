import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/transport_service.dart';
import '../../models/gtfs.dart';
import '../../services/driver/driver_service.dart';
import '../../services/gtfs_service.dart';
import '../../theme/driver_home_palette.dart';

/// Une vacation proposée : un trajet (sens + terminus) avec, si les horaires
/// théoriques le permettent, son départ planifié au terminus d'origine.
class _ServiceProposal {
  final int directionId; // 0 / 1
  final String headsign; // terminus visé
  final DateTime? departure; // null quand on n'a pas d'horaire exploitable

  const _ServiceProposal({
    required this.directionId,
    required this.headsign,
    this.departure,
  });
}

/// Prise de service : le conducteur choisit sa ligne (sélection ou saisie
/// manuelle), saisit le n° de train (position du véhicule dans la flotte en
/// ligne, ex. « 1-12 »), puis l'app lui propose les services correspondant à sa
/// vacation d'après les horaires théoriques. Il confirme véhicule et
/// géolocalisation avant de démarrer.
class DriverTakeServiceScreen extends StatefulWidget {
  const DriverTakeServiceScreen({super.key});

  @override
  State<DriverTakeServiceScreen> createState() =>
      _DriverTakeServiceScreenState();
}

class _DriverTakeServiceScreenState extends State<DriverTakeServiceScreen> {
  final _vehicleController = TextEditingController();
  final _trainController = TextEditingController();
  final _dayCodeController = TextEditingController();
  final _parkingSlotController = TextEditingController();

  List<GtfsRoute> _routes = [];
  bool _loadingRoutes = true;

  GtfsRoute? _selectedRoute;
  List<_ServiceProposal> _proposals = const [];
  int? _selectedProposalIndex;

  // Services de roulement réels (table transport_services) pour ligne + train.
  List<TransportService> _roulementServices = const [];
  bool _loadingRoulement = false;
  TransportService? _selectedService;
  String? _periodFilter; // null = toutes les périodes
  Timer? _roulementDebounce;

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
      if (planned?.vehicleId != null) {
        _vehicleController.text = planned!.vehicleId!;
      }
      if (planned?.dayCode != null) {
        _dayCodeController.text = planned!.dayCode!;
      }
      if (planned?.parkingSlot != null) {
        _parkingSlotController.text = planned!.parkingSlot!;
      }
      // « 1-12 » → on ne garde que la position (12) dans le champ.
      final train = planned?.trainNumber;
      if (train != null && train.contains('-')) {
        _trainController.text = train.split('-').last;
      } else if (train != null) {
        _trainController.text = train;
      }
      _loadingRoutes = false;
      if (preset != null) {
        _recomputeProposals();
        _scheduleRoulementLoad();
      }
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

  String _routeShort(GtfsRoute r) => r.routeShortName ?? r.routeId;

  String _routeLabel(GtfsRoute r) {
    final short = _routeShort(r);
    final long = r.routeLongName;
    return long != null && long.isNotEmpty ? '$short · $long' : 'Ligne $short';
  }

  /// Code « train » complet (ligne-position), ex. « 1-12 ». Null si incomplet.
  String? get _trainCode {
    final route = _selectedRoute;
    final pos = _trainController.text.trim();
    if (route == null || pos.isEmpty) return null;
    return '${_routeShort(route)}-$pos';
  }

  // ---------------------------------------------------------------------------
  // Propositions de services (vacation)
  // ---------------------------------------------------------------------------
  void _recomputeProposals() {
    final route = _selectedRoute;
    if (route == null) {
      _proposals = const [];
      _selectedProposalIndex = null;
      return;
    }
    _proposals = _buildProposals(route);
    _selectedProposalIndex = null;
    _syncProposalFromTrain();
  }

  List<_ServiceProposal> _buildProposals(GtfsRoute route) {
    final gtfs = context.read<GtfsService>();
    final termini = _termini(route);
    final now = DateTime.now();
    final out = <_ServiceProposal>[];

    // direction 0 → vers termini.last ; direction 1 → vers termini.first
    for (final dir in <(int, String)>[(0, termini.last), (1, termini.first)]) {
      List<GtfsStop> stops;
      try {
        stops = gtfs.stopsToward(route, dir.$2);
      } catch (_) {
        stops = const [];
      }
      if (stops.isEmpty) continue;
      final origin = stops.first;
      final deps = gtfs.theoreticalDepartureTimes(
        route,
        origin,
        direction: dir.$2,
        now: now,
        maxCount: 6,
      );
      for (final dep in deps) {
        out.add(_ServiceProposal(
          directionId: dir.$1,
          headsign: dir.$2,
          departure: dep,
        ));
      }
    }

    out.sort((a, b) => a.departure!.compareTo(b.departure!));

    // Repli : aucune donnée horaire exploitable → on propose les deux sens.
    if (out.isEmpty) {
      return [
        _ServiceProposal(directionId: 0, headsign: termini.last),
        _ServiceProposal(directionId: 1, headsign: termini.first),
      ];
    }
    return out.take(10).toList();
  }

  /// Pré-sélectionne le service dont la position correspond au n° de train
  /// saisi (le « 1-12 » désigne le 12ᵉ véhicule en ligne).
  void _syncProposalFromTrain() {
    final pos = int.tryParse(_trainController.text.trim());
    if (pos != null && pos >= 1 && pos <= _proposals.length) {
      _selectedProposalIndex = pos - 1;
    }
  }

  // ---------------------------------------------------------------------------
  // Services de roulement (réels) correspondant à ligne + train
  // ---------------------------------------------------------------------------
  /// Programme (avec un léger debounce) le chargement des services réels dès
  /// que ligne + n° de train sont renseignés.
  void _scheduleRoulementLoad() {
    _roulementDebounce?.cancel();
    if (_trainCode == null) {
      _roulementServices = const [];
      _selectedService = null;
      _loadingRoulement = false;
      return;
    }
    _loadingRoulement = true;
    _roulementDebounce =
        Timer(const Duration(milliseconds: 400), _loadRoulementServices);
  }

  Future<void> _loadRoulementServices() async {
    final key = _trainCode;
    if (key == null) return;
    final services =
        await context.read<DriverService>().findServicesByVehicle(key);
    if (!mounted || key != _trainCode) return;
    setState(() {
      _roulementServices = services;
      _loadingRoulement = false;
      // Conserve la sélection si elle est toujours dans les résultats.
      if (_selectedService != null &&
          !services.any((s) => s.serviceKey == _selectedService!.serviceKey)) {
        _selectedService = null;
      }
      // Restreint le filtre période aux périodes réellement présentes.
      final periods =
          services.map((s) => (s.edition ?? '').toUpperCase()).toSet();
      if (_periodFilter != null && !periods.contains(_periodFilter)) {
        _periodFilter = null;
      }
    });
  }

  List<TransportService> get _filteredServices {
    final f = _periodFilter;
    if (f == null) return _roulementServices;
    return _roulementServices
        .where((s) => (s.edition ?? '').toUpperCase() == f)
        .toList();
  }

  /// « 3:43 » → DateTime d'aujourd'hui à 03:43 (pour les heures planifiées).
  DateTime? _composeDateTime(String? hm) {
    if (hm == null) return null;
    final parts = hm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, h, m);
  }

  @override
  void dispose() {
    _roulementDebounce?.cancel();
    _vehicleController.dispose();
    _trainController.dispose();
    _dayCodeController.dispose();
    _parkingSlotController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _selectedRoute != null &&
      _trainCode != null &&
      _locationConsent &&
      !_submitting &&
      (_selectedService != null || _selectedProposalIndex != null);

  Future<void> _submit() async {
    final route = _selectedRoute;
    if (route == null) return;

    // Sens / destination : repris de la proposition GTFS si sélectionnée.
    int? directionId;
    String? headsign;
    final index = _selectedProposalIndex;
    if (index != null && index < _proposals.length) {
      directionId = _proposals[index].directionId;
      headsign = _proposals[index].headsign;
    }

    // Service de roulement choisi : code + heures planifiées (début → fin).
    final svc = _selectedService;
    DateTime? plannedStart;
    DateTime? plannedEnd;
    if (svc != null) {
      plannedStart = _composeDateTime(svc.startTime);
      plannedEnd = _composeDateTime(svc.endTime);
      if (plannedStart != null &&
          plannedEnd != null &&
          plannedEnd.isBefore(plannedStart)) {
        plannedEnd = plannedEnd.add(const Duration(days: 1)); // service de nuit
      }
    }

    setState(() => _submitting = true);

    final ok = await context.read<DriverService>().takeService(
          vehicleId: _vehicleController.text.trim().isEmpty
              ? null
              : _vehicleController.text.trim(),
          lineId: route.routeId,
          trainNumber: _trainCode,
          serviceCode: svc?.serviceNo,
          dayCode: _dayCodeController.text.trim().isEmpty
              ? null
              : _dayCodeController.text.trim(),
          parkingSlot: _parkingSlotController.text.trim().isEmpty
              ? null
              : _parkingSlotController.text.trim(),
          plannedStart: plannedStart,
          plannedEnd: plannedEnd,
          directionId: directionId,
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
    return Scaffold(
      backgroundColor: DriverHomePalette.background,
      appBar: AppBar(
        title: const Text('Prise de service'),
        backgroundColor: DriverHomePalette.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: DriverHomePalette.textDark,
        elevation: 0,
      ),
      body: _loadingRoutes
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Confirmez les éléments de votre service avant de démarrer.',
                  style: TextStyle(
                    color: DriverHomePalette.textDark.withValues(alpha: 0.65),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),

                // --- Ligne (sélection OU saisie manuelle) ---
                _SectionCard(
                  icon: LucideIcons.busFront,
                  label: 'Ligne',
                  child: DropdownMenu<GtfsRoute>(
                    initialSelection: _selectedRoute,
                    expandedInsets: EdgeInsets.zero,
                    enableFilter: true,
                    requestFocusOnTap: true,
                    menuHeight: 360,
                    leadingIcon: const Icon(LucideIcons.search, size: 18),
                    hintText: 'Rechercher ou choisir (ex. 1, C6, Busway)',
                    inputDecorationTheme: InputDecorationTheme(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              DriverHomePalette.textDark.withValues(alpha: 0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color:
                              DriverHomePalette.textDark.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    dropdownMenuEntries: _routes
                        .map((r) => DropdownMenuEntry<GtfsRoute>(
                              value: r,
                              label: _routeLabel(r),
                            ))
                        .toList(),
                    onSelected: (r) => setState(() {
                      _selectedRoute = r;
                      _recomputeProposals();
                      _scheduleRoulementLoad();
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                // --- Train (position dans la flotte en ligne) ---
                _SectionCard(
                  icon: LucideIcons.trainFront,
                  label: 'Train',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _trainController,
                        enabled: _selectedRoute != null,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          prefixText: _selectedRoute != null
                              ? '${_routeShort(_selectedRoute!)}-'
                              : null,
                          prefixStyle: const TextStyle(
                            color: DriverHomePalette.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          hintText: _selectedRoute != null
                              ? 'Position du véhicule (ex. 12)'
                              : 'Choisissez d\'abord une ligne',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (_) => setState(() {
                          // Re-synchronise la proposition mise en avant.
                          _selectedProposalIndex = null;
                          _syncProposalFromTrain();
                          _scheduleRoulementLoad();
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Le numéro du véhicule dans la flotte en circulation sur '
                        'la ligne (ex. 12ᵉ tram → « ${_selectedRoute != null ? _routeShort(_selectedRoute!) : '1'}-12 »).',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              DriverHomePalette.textDark.withValues(alpha: 0.55),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // --- Services du roulement (réels) correspondant à ligne+train ---
                _SectionCard(
                  icon: LucideIcons.clipboardList,
                  label: 'Votre service',
                  child: _buildRoulementSection(),
                ),
                const SizedBox(height: 12),

                // --- Journée (code du roulement journalier) ---
                _SectionCard(
                  icon: LucideIcons.calendarDays,
                  label: 'Journée',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _dayCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Code journée (ex. 38B-4)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Le code de votre roulement du jour, tel qu\'affiché '
                        'sur la console du dépôt à votre badgeage.',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              DriverHomePalette.textDark.withValues(alpha: 0.55),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // --- Sens / départ théorique (indicatif GTFS) ---
                _SectionCard(
                  icon: LucideIcons.calendarClock,
                  label: 'Sens · départ théorique (GTFS)',
                  child: _buildProposalsSection(),
                ),
                const SizedBox(height: 12),

                // --- Véhicule ---
                _SectionCard(
                  icon: LucideIcons.bus,
                  label: 'Véhicule',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _vehicleController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Numéro de véhicule (ex. 8421)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _parkingSlotController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Emplacement au dépôt (ex. H13-1)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // --- Géolocalisation ---
                _SectionCard(
                  icon: LucideIcons.mapPin,
                  label: 'Géolocalisation',
                  child: _ConsentTile(
                    value: _locationConsent,
                    onChanged: (v) => setState(() => _locationConsent = v),
                  ),
                ),
                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: _canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: DriverHomePalette.primary,
                    disabledBackgroundColor:
                        DriverHomePalette.textDark.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.play),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Je prends mon service',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProposalsSection() {
    if (_selectedRoute == null) {
      return Text(
        'Choisissez une ligne pour voir les services proposés.',
        style: TextStyle(
          fontSize: 13,
          color: DriverHomePalette.textDark.withValues(alpha: 0.55),
        ),
      );
    }

    final now = DateTime.now();
    final hasTimes = _proposals.any((p) => p.departure != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasTimes
              ? 'D\'après les horaires théoriques — sélectionnez votre service.'
              : 'Sélectionnez le sens de votre service.',
          style: TextStyle(
            fontSize: 12,
            color: DriverHomePalette.textDark.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(_proposals.length, (i) {
          final p = _proposals[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ProposalTile(
              proposal: p,
              position: i + 1,
              selected: _selectedProposalIndex == i,
              now: now,
              onTap: () => setState(() => _selectedProposalIndex = i),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRoulementSection() {
    if (_trainCode == null) {
      return Text(
        'Renseignez la ligne et le n° de train pour voir les services qui '
        'correspondent à votre vacation.',
        style: TextStyle(
          fontSize: 13,
          color: DriverHomePalette.textDark.withValues(alpha: 0.55),
        ),
      );
    }
    if (_loadingRoulement) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Recherche des services…'),
          ],
        ),
      );
    }
    if (_roulementServices.isEmpty) {
      return Text(
        'Aucun service trouvé pour le train « $_trainCode ».',
        style: TextStyle(
          fontSize: 13,
          color: DriverHomePalette.textDark.withValues(alpha: 0.6),
        ),
      );
    }

    final periods = _roulementServices
        .map((s) => (s.edition ?? '').toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final services = _filteredServices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Train « $_trainCode » — choisissez votre service (début → fin).',
          style: TextStyle(
            fontSize: 12,
            color: DriverHomePalette.textDark.withValues(alpha: 0.55),
          ),
        ),
        if (periods.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PeriodChip(
                label: 'Toutes',
                selected: _periodFilter == null,
                onTap: () => setState(() => _periodFilter = null),
              ),
              ...periods.map((p) => _PeriodChip(
                    label: _periodLabel(p),
                    selected: _periodFilter == p,
                    onTap: () => setState(() => _periodFilter = p),
                  )),
            ],
          ),
        ],
        const SizedBox(height: 10),
        ...services.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RoulementTile(
                service: s,
                selected: _selectedService?.serviceKey == s.serviceKey,
                onTap: () => setState(() => _selectedService = s),
              ),
            )),
      ],
    );
  }

  static String _periodLabel(String edition) {
    switch (edition.toUpperCase()) {
      case 'VERT':
        return 'Vert';
      case 'BLEU':
        return 'Bleu';
      case 'HIVER':
        return 'Hiver';
      default:
        return edition;
    }
  }
}

/// Carte de section blanche, arrondie, avec en-tête icône + libellé.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: DriverHomePalette.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: DriverHomePalette.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DriverHomePalette.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Une proposition de service (sens + départ théorique), sélectionnable.
class _ProposalTile extends StatelessWidget {
  final _ServiceProposal proposal;
  final int position;
  final bool selected;
  final DateTime now;
  final VoidCallback onTap;

  const _ProposalTile({
    required this.proposal,
    required this.position,
    required this.selected,
    required this.now,
    required this.onTap,
  });

  String _relative(DateTime dep) {
    final m = dep.difference(now).inMinutes;
    if (m <= 0) return 'maintenant';
    if (m < 60) return 'dans $m min';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? 'dans ${h}h' : 'dans ${h}h$r';
  }

  @override
  Widget build(BuildContext context) {
    final dep = proposal.departure;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? DriverHomePalette.softGreen
              : DriverHomePalette.lightGreen.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? DriverHomePalette.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected
                  ? DriverHomePalette.primary
                  : DriverHomePalette.textDark.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '→ ${proposal.headsign}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: DriverHomePalette.textDark,
                    ),
                  ),
                  if (dep != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Départ ${DateFormat('HH:mm').format(dep)} · ${_relative(dep)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: DriverHomePalette.textDark
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (dep != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$position',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DriverHomePalette.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Puce de filtre par période (Vert / Bleu / Hiver / Toutes).
class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:
              selected ? DriverHomePalette.primary : DriverHomePalette.lightGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : DriverHomePalette.textDark,
          ),
        ),
      ),
    );
  }
}

/// Un service de roulement réel, sélectionnable (début → fin, période, dépôt).
class _RoulementTile extends StatelessWidget {
  final TransportService service;
  final bool selected;
  final VoidCallback onTap;

  const _RoulementTile({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  Color get _periodColor {
    switch ((service.edition ?? '').toUpperCase()) {
      case 'VERT':
        return DriverHomePalette.primary;
      case 'BLEU':
        return DriverHomePalette.blue;
      case 'HIVER':
        return DriverHomePalette.purple;
      default:
        return DriverHomePalette.textDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = service.startTime ?? '—';
    final end = service.endTime ?? '—';
    final subtitle = [
      if (service.serviceNo != null) 'Service ${service.serviceNo}',
      if (service.depotCode != null) service.depotCode!,
    ].join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? DriverHomePalette.softGreen
              : DriverHomePalette.lightGreen.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? DriverHomePalette.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected
                  ? DriverHomePalette.primary
                  : DriverHomePalette.textDark.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$start → $end',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: DriverHomePalette.textDark,
                        ),
                      ),
                      if (service.amplitude != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'ampl. ${service.amplitude}',
                          style: TextStyle(
                            fontSize: 11,
                            color: DriverHomePalette.textDark
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            DriverHomePalette.textDark.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _periodColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                service.periodLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _periodColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Case à cocher de consentement à la géolocalisation.
class _ConsentTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ConsentTile({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'J\'autorise le partage de ma position pendant le service',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: DriverHomePalette.textDark,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'La position n\'est transmise que tant que le service est actif.',
                  style: TextStyle(
                    fontSize: 12,
                    color: DriverHomePalette.textDark.withValues(alpha: 0.55),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Checkbox(
            value: value,
            activeColor: DriverHomePalette.primary,
            onChanged: (v) => onChanged(v ?? false),
          ),
        ],
      ),
    );
  }
}
