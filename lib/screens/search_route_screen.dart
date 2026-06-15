import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../theme/flow_theme.dart';
import '../widgets/flow_primitives.dart';
import '../widgets/flow_widgets.dart';
import 'route_result_screen.dart';

class SearchRouteScreen extends StatefulWidget {
  const SearchRouteScreen({super.key});

  @override
  State<SearchRouteScreen> createState() => _SearchRouteScreenState();
}

class _SearchRouteScreenState extends State<SearchRouteScreen> {
  final TextEditingController _originController = TextEditingController(text: 'Ma position');
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _destFocus = FocusNode();

  bool _loading = false;
  List<String> _suggestions = [];

  // Arrêts populaires : noms GTFS réels (toute autre graphie ne se
  // résoudrait pas en station et casserait le calcul d'itinéraire).
  final List<String> _popularStops = [
    'Commerce',
    'Gare Nord - Jardin des Plantes',
    'Gare Sud',
    'Cité des Congrès',
    'Place du Cirque',
    'Trentemoult',
    'Bouffay',
    'Duchesse Anne - Château'
  ];

  final List<String> _recents = ['Gare Sud', 'Chantiers Navals', 'Beaulieu'];

  @override
  void initState() {
    super.initState();
    _destinationController.addListener(_onDestinationChanged);
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  void _onDestinationChanged() {
    final text = _destinationController.text.trim();
    if (text.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    // Recherche dans les vraies stations du réseau (insensible aux
    // accents), pas dans une liste codée en dur : chaque suggestion est
    // garantie résoluble par le calculateur d'itinéraire.
    final gtfs = Provider.of<GtfsService>(context, listen: false);
    final results = gtfs.searchStations(text, limit: 12);
    setState(() {
      _suggestions = [for (final r in results) r.stop.stopName];
    });
  }

  Future<void> _performSearch([String? dest]) async {
    if (dest != null) _destinationController.text = dest;
    final origin = _originController.text.trim();
    final destination = _destinationController.text.trim();

    final navigator = Navigator.of(context);
    final gtfsService = Provider.of<GtfsService>(context, listen: false);
    final locationService = Provider.of<LocationService>(context, listen: false);

    if (origin.isEmpty || destination.isEmpty) {
      showFlowToast(context, 'Veuillez renseigner le départ et l\'arrivée.');
      return;
    }

    setState(() => _loading = true);

    try {
      // Position GPS réelle pour résoudre « Ma position » (sinon le service
      // retombe sur le centre-ville par défaut).
      final pos = locationService.currentPosition ??
          await locationService.updateCurrentPosition();
      final itineraries = await gtfsService.searchItinerary(
        origin,
        destination,
        userPosition: pos == null ? null : LatLng(pos.latitude, pos.longitude),
      );
      if (!mounted) return;
      setState(() => _loading = false);

      if (itineraries.isEmpty) {
        showFlowToast(context, 'Aucun itinéraire trouvé pour ce trajet.');
      } else {
        navigator.push(
          FlowPageRoute(
            page: RouteResultScreen(
              origin: origin,
              destination: destination,
              itineraries: itineraries,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showFlowToast(context, 'Erreur lors du calcul ($e)', icon: LucideIcons.triangleAlert);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlowColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // En-tête : retour + champ focus
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 6),
              child: Row(
                children: [
                  FlowIconButton(icon: LucideIcons.arrowLeft, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  Expanded(child: _FocusField(controller: _destinationController, focusNode: _destFocus)),
                ],
              ),
            ),
            // Champ origine compact
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Row(
                children: [
                  const Icon(LucideIcons.circleDot, size: 16, color: FlowColors.gWeak),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FlowTextField(
                      controller: _originController,
                      hintText: 'Point de départ',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (_loading) const LinearProgressIndicator(minHeight: 2, color: FlowColors.blue, backgroundColor: FlowColors.fill),
            Expanded(
              child: _suggestions.isNotEmpty
                  ? _buildSuggestions()
                  : _buildDefault(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final stop = _suggestions[index];
        return _ResultRow(
          icon: LucideIcons.mapPin,
          iconBg: FlowColors.blueSoft,
          iconColor: FlowColors.blue,
          title: stop,
          sub: 'Arrêt Naolib',
          onTap: () => _performSearch(stop),
        );
      },
    );
  }

  Widget _buildDefault() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const SectionLabel('Favoris'),
        const SizedBox(height: 10),
        Row(
          children: [
            _FavChip(icon: LucideIcons.house, label: 'Maison', onTap: () => _performSearch('Commerce')),
            const SizedBox(width: 8),
            _FavChip(icon: LucideIcons.briefcase, label: 'Travail', onTap: () => _performSearch('Cité des Congrès')),
            const SizedBox(width: 8),
            _FavChip(icon: LucideIcons.plus, label: 'Ajouter', ghost: true, onTap: () {}),
          ],
        ),
        const SizedBox(height: 22),
        const SectionLabel('Suggestions'),
        const SizedBox(height: 4),
        ..._popularStops.take(3).map((s) => _ResultRow(
              icon: LucideIcons.mapPin,
              iconBg: FlowColors.blueSoft,
              iconColor: FlowColors.blue,
              title: s,
              sub: 'Arrêt populaire à Nantes',
              onTap: () => _performSearch(s),
            )),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 8),
        const SectionLabel('Récents'),
        const SizedBox(height: 4),
        ..._recents.map((s) => _ResultRow(
              icon: LucideIcons.history,
              iconBg: FlowColors.fill,
              iconColor: FlowColors.ink,
              title: s,
              sub: 'Recherché récemment',
              onTap: () => _performSearch(s),
            )),
      ],
    );
  }
}

class _FocusField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const _FocusField({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: FlowColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlowColors.blue, width: 2),
        boxShadow: [
          BoxShadow(color: FlowColors.blue.withValues(alpha: 0.18), blurRadius: 0, spreadRadius: 4),
        ],
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search, color: FlowColors.blue, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: FlowTextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              hintText: 'Où allez-vous ?',
            ),
          ),
          const Icon(LucideIcons.venetianMask, color: FlowColors.g2, size: 18),
        ],
      ),
    );
  }
}

class _FavChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ghost;
  final VoidCallback onTap;
  const _FavChip({required this.icon, required this.label, required this.onTap, this.ghost = false});

  @override
  Widget build(BuildContext context) {
    return FlowTappable(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: ghost ? FlowColors.white : FlowColors.fill,
          borderRadius: BorderRadius.circular(12),
          border: ghost ? Border.all(color: FlowColors.line) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: ghost ? FlowColors.g2 : FlowColors.ink),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ghost ? FlowColors.g2 : FlowColors.ink)),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _ResultRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlowTappable(
      onTap: onTap,
      pressedScale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            IconTile(icon: icon, background: iconBg, iconColor: iconColor),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: FlowText.rowTitle),
                  const SizedBox(height: 1),
                  Text(sub, style: FlowText.rowSub),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
