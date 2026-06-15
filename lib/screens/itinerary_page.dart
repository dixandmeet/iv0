import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/gtfs_service.dart';
import '../services/location_service.dart';
import '../widgets/nearby_stops/tab_page_header.dart';
import 'route_result_screen.dart';

enum _FocusedField { origin, destination }

class ItineraryPage extends StatefulWidget {
  const ItineraryPage({super.key});

  @override
  State<ItineraryPage> createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<ItineraryPage> {
  static const _recentsKey = 'itinerary_recent_destinations';

  final TextEditingController _originController =
      TextEditingController(text: 'Ma position');
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  final FocusNode _destFocus = FocusNode();

  bool _loading = false;
  List<String> _suggestions = [];
  _FocusedField _focusedField = _FocusedField.destination;
  List<String> _recents = [];

  final List<String> _popularStops = [
    'Commerce',
    'Gare Nord - Jardin des Plantes',
    'Gare Sud',
    'Cité des Congrès',
    'Place du Cirque',
    'Trentemoult',
    'Bouffay',
    'Duchesse Anne - Château',
  ];

  static const _quickAccess = [
    _QuickAccessItem(
      icon: LucideIcons.house,
      label: 'Maison',
      destination: 'Commerce',
    ),
    _QuickAccessItem(
      icon: LucideIcons.briefcase,
      label: 'Travail',
      destination: 'Cité des Congrès',
    ),
    _QuickAccessItem(
      icon: LucideIcons.trainFront,
      label: 'Gare Sud',
      destination: 'Gare Sud',
    ),
    _QuickAccessItem(
      icon: LucideIcons.landmark,
      label: 'Congrès',
      destination: 'Cité des Congrès',
    ),
  ];

  bool get _canSearch =>
      _originController.text.trim().isNotEmpty &&
      _destinationController.text.trim().isNotEmpty;

  TextEditingController get _activeController =>
      _focusedField == _FocusedField.origin
          ? _originController
          : _destinationController;

  @override
  void initState() {
    super.initState();
    _originController.addListener(_onFieldChanged);
    _destinationController.addListener(_onFieldChanged);
    _originFocus.addListener(_onFocusChanged);
    _destFocus.addListener(_onFocusChanged);
    _loadRecents();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _originFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recents = prefs.getStringList(_recentsKey) ??
          ['Gare Sud', 'Chantiers Navals', 'Beaulieu'];
    });
  }

  Future<void> _saveRecent(String destination) async {
    final trimmed = destination.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'ma position') return;
    final prefs = await SharedPreferences.getInstance();
    final updated = [
      trimmed,
      ..._recents.where((r) => r != trimmed),
    ].take(5).toList();
    await prefs.setStringList(_recentsKey, updated);
    if (!mounted) return;
    setState(() => _recents = updated);
  }

  void _onFocusChanged() {
    if (_originFocus.hasFocus) {
      setState(() => _focusedField = _FocusedField.origin);
      _updateSuggestions();
    } else if (_destFocus.hasFocus) {
      setState(() => _focusedField = _FocusedField.destination);
      _updateSuggestions();
    }
  }

  void _onFieldChanged() {
    _updateSuggestions();
    setState(() {});
  }

  void _updateSuggestions() {
    final text = _activeController.text.trim();
    if (text.isEmpty || text.toLowerCase() == 'ma position') {
      setState(() => _suggestions = []);
      return;
    }
    final gtfs = Provider.of<GtfsService>(context, listen: false);
    final results = gtfs.searchStations(text, limit: 12);
    setState(() {
      _suggestions = [for (final r in results) r.stop.stopName];
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _swapFields() {
    HapticFeedback.lightImpact();
    final origin = _originController.text;
    final dest = _destinationController.text;
    _originController.text = dest;
    _destinationController.text = origin;
    setState(() {
      _focusedField = _focusedField == _FocusedField.origin
          ? _FocusedField.destination
          : _FocusedField.origin;
    });
    _updateSuggestions();
  }

  void _applySuggestion(String stop) {
    _activeController.text = stop;
    setState(() => _suggestions = []);
    FocusScope.of(context).unfocus();
  }

  void _setMyPosition() {
    _originController.text = 'Ma position';
    _updateSuggestions();
  }

  Future<void> _performSearch({String? dest, bool saveRecent = true}) async {
    if (dest != null) _destinationController.text = dest;
    final origin = _originController.text.trim();
    final destination = _destinationController.text.trim();

    final navigator = Navigator.of(context);
    final gtfsService = Provider.of<GtfsService>(context, listen: false);
    final locationService =
        Provider.of<LocationService>(context, listen: false);

    if (origin.isEmpty || destination.isEmpty) {
      _showMessage('Veuillez renseigner le départ et l\'arrivée.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final pos = locationService.currentPosition ??
          await locationService.updateCurrentPosition();
      final itineraries = await gtfsService.searchItinerary(
        origin,
        destination,
        userPosition:
            pos == null ? null : LatLng(pos.latitude, pos.longitude),
      );
      if (!mounted) return;
      setState(() => _loading = false);

      if (itineraries.isEmpty) {
        _showMessage('Aucun itinéraire trouvé pour ce trajet.');
      } else {
        if (saveRecent) await _saveRecent(destination);
        if (!mounted) return;
        navigator.push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => RouteResultScreen(
              origin: origin,
              destination: destination,
              itineraries: itineraries,
            ),
            transitionDuration: const Duration(milliseconds: 320),
            reverseTransitionDuration: const Duration(milliseconds: 260),
            transitionsBuilder: (_, animation, __, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.18, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: FadeTransition(opacity: curved, child: child),
              );
            },
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Erreur lors du calcul ($e)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF141A23) : Colors.white;
    final primaryTextColor =
        isDark ? const Color(0xFFEFF3F9) : const Color(0xFF0B1220);
    final mutedTextColor =
        isDark ? const Color(0xFF9BA7B7) : const Color(0xFF5B6677);
    final borderCol =
        isDark ? const Color(0x17FFFFFF) : const Color(0xFFE7EAF0);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TabPageHeader(
              title: 'Itinéraire',
              subtitle: 'Planifiez votre trajet en transports en commun',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _RouteInputCard(
                originController: _originController,
                destinationController: _destinationController,
                originFocus: _originFocus,
                destFocus: _destFocus,
                focusedField: _focusedField,
                cardBg: cardBg,
                primaryTextColor: primaryTextColor,
                mutedTextColor: mutedTextColor,
                borderCol: borderCol,
                loading: _loading,
                canSearch: _canSearch,
                onSwap: _swapFields,
                onMyPosition: _setMyPosition,
                onSearch: () => _performSearch(),
              ),
            ),
            Expanded(
              child: _suggestions.isNotEmpty
                  ? _buildSuggestions(
                      primaryTextColor, mutedTextColor, cardBg, borderCol)
                  : _buildDefault(
                      primaryTextColor, mutedTextColor, cardBg, borderCol),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBg,
    Color borderCol,
  ) {
    final label =
        _focusedField == _FocusedField.origin ? 'Départ' : 'Destination';
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: _suggestions.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _SectionLabel('$label — résultats', color: mutedTextColor);
        }
        final stop = _suggestions[index - 1];
        return _SuggestionTile(
          title: stop,
          subtitle: 'Arrêt Naolib',
          icon: LucideIcons.mapPin,
          iconColor: const Color(0xFF1B66F5),
          cardBg: cardBg,
          borderCol: borderCol,
          primaryTextColor: primaryTextColor,
          mutedTextColor: mutedTextColor,
          onTap: () => _applySuggestion(stop),
        );
      },
    );
  }

  Widget _buildDefault(
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBg,
    Color borderCol,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _SectionLabel('Accès rapide', color: mutedTextColor),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickAccess.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = _quickAccess[index];
              return _QuickChip(
                icon: item.icon,
                label: item.label,
                onTap: () => _performSearch(dest: item.destination),
                cardBg: cardBg,
                borderCol: borderCol,
                textColor: primaryTextColor,
                compact: true,
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        _SectionLabel('Arrêts populaires', color: mutedTextColor),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _popularStops.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final stop = _popularStops[index];
              return _PopularChip(
                label: stop,
                onTap: () {
                  _destinationController.text = stop;
                  _destFocus.requestFocus();
                },
                cardBg: cardBg,
                borderCol: borderCol,
                textColor: primaryTextColor,
              );
            },
          ),
        ),
        if (_recents.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionLabel('Récents', color: mutedTextColor),
          const SizedBox(height: 8),
          ..._recents.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SuggestionTile(
                title: s,
                subtitle: 'Recherché récemment',
                icon: LucideIcons.history,
                iconColor: mutedTextColor,
                cardBg: cardBg,
                borderCol: borderCol,
                primaryTextColor: primaryTextColor,
                mutedTextColor: mutedTextColor,
                onTap: () => _performSearch(dest: s, saveRecent: false),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickAccessItem {
  final IconData icon;
  final String label;
  final String destination;

  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.destination,
  });
}

class _RouteInputCard extends StatelessWidget {
  static const _fieldHeight = 40.0;
  static const _dividerBlockHeight = 17.0;

  final TextEditingController originController;
  final TextEditingController destinationController;
  final FocusNode originFocus;
  final FocusNode destFocus;
  final _FocusedField focusedField;
  final Color cardBg;
  final Color primaryTextColor;
  final Color mutedTextColor;
  final Color borderCol;
  final bool loading;
  final bool canSearch;
  final VoidCallback onSwap;
  final VoidCallback onMyPosition;
  final VoidCallback onSearch;

  const _RouteInputCard({
    required this.originController,
    required this.destinationController,
    required this.originFocus,
    required this.destFocus,
    required this.focusedField,
    required this.cardBg,
    required this.primaryTextColor,
    required this.mutedTextColor,
    required this.borderCol,
    required this.loading,
    required this.canSearch,
    required this.onSwap,
    required this.onMyPosition,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RouteConnector(
                borderColor: borderCol,
                fieldHeight: _fieldHeight,
                dividerBlockHeight: _dividerBlockHeight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: _fieldHeight,
                      child: _RouteField(
                        controller: originController,
                        focusNode: originFocus,
                        hint: 'Point de départ',
                        textColor: primaryTextColor,
                        mutedColor: mutedTextColor,
                        isFocused: focusedField == _FocusedField.origin,
                        onClear: originController.text.isNotEmpty &&
                                originController.text != 'Ma position'
                            ? () {
                                originController.clear();
                                originFocus.requestFocus();
                              }
                            : null,
                        trailing: originController.text != 'Ma position'
                            ? _MyPositionButton(
                                onTap: onMyPosition,
                                mutedColor: mutedTextColor,
                              )
                            : null,
                      ),
                    ),
                    SizedBox(
                      height: _dividerBlockHeight,
                      child: Divider(height: 1, color: borderCol),
                    ),
                    SizedBox(
                      height: _fieldHeight,
                      child: _RouteField(
                        controller: destinationController,
                        focusNode: destFocus,
                        hint: 'Où allez-vous ?',
                        textColor: primaryTextColor,
                        mutedColor: mutedTextColor,
                        isFocused: focusedField == _FocusedField.destination,
                        onClear: destinationController.text.isNotEmpty
                            ? () {
                                destinationController.clear();
                                destFocus.requestFocus();
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(
                  top: (_fieldHeight + _dividerBlockHeight + _fieldHeight - 36) / 2,
                ),
                child: _SwapButton(onTap: onSwap, borderColor: borderCol),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: loading || !canSearch ? null : onSearch,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.route, size: 18),
              label: Text(
                loading ? 'Calcul en cours...' : 'Calculer l\'itinéraire',
                style: GoogleFonts.hankenGrotesk(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B66F5),
                disabledBackgroundColor:
                    const Color(0xFF1B66F5).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteConnector extends StatelessWidget {
  final Color borderColor;
  final double fieldHeight;
  final double dividerBlockHeight;

  const _RouteConnector({
    required this.borderColor,
    required this.fieldHeight,
    required this.dividerBlockHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: fieldHeight,
            child: const Center(child: _RouteDot(color: Color(0xFF16A34A))),
          ),
          SizedBox(
            height: dividerBlockHeight,
            child: CustomPaint(
              painter: _DashedLinePainter(color: borderColor),
              size: Size(18, dividerBlockHeight),
            ),
          ),
          SizedBox(
            height: fieldHeight,
            child: const Center(child: _RouteDot(color: Color(0xFF1B66F5))),
          ),
        ],
      ),
    );
  }
}

class _RouteDot extends StatelessWidget {
  final Color color;

  const _RouteDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashHeight = 4.0;
    const gap = 3.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, (y + dashHeight).clamp(0, size.height)),
        paint,
      );
      y += dashHeight + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SwapButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color borderColor;

  const _SwapButton({required this.onTap, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: const Icon(
            LucideIcons.arrowUpDown,
            size: 16,
            color: Color(0xFF1B66F5),
          ),
        ),
      ),
    );
  }
}

class _MyPositionButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color mutedColor;

  const _MyPositionButton({required this.onTap, required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.locateFixed, size: 12, color: Color(0xFF16A34A)),
            const SizedBox(width: 4),
            Text(
              'Ma position',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final Color textColor;
  final Color mutedColor;
  final bool isFocused;
  final VoidCallback? onClear;
  final Widget? trailing;

  const _RouteField({
    required this.controller,
    required this.hint,
    required this.textColor,
    required this.mutedColor,
    this.focusNode,
    this.isFocused = false,
    this.onClear,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.hankenGrotesk(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: textColor,
      height: 1.0,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isFocused
            ? const Color(0xFF1B66F5).withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: textStyle,
              strutStyle: StrutStyle.fromTextStyle(textStyle),
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                hintText: hint,
                hintStyle: GoogleFonts.hankenGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: mutedColor.withValues(alpha: 0.8),
                  height: 1.0,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (onClear != null)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(LucideIcons.x, size: 16, color: mutedColor),
              ),
            )
          else if (trailing != null)
            trailing!,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.hankenGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: color,
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color cardBg;
  final Color borderCol;
  final Color textColor;
  final bool compact;

  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cardBg,
    required this.borderCol,
    required this.textColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(compact ? 22 : 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 22 : 14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 14,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 22 : 14),
            border: Border.all(color: borderCol),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF1B66F5)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color cardBg;
  final Color borderCol;
  final Color textColor;

  const _PopularChip({
    required this.label,
    required this.onTap,
    required this.cardBg,
    required this.borderCol,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderCol),
          ),
          child: Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color cardBg;
  final Color borderCol;
  final Color primaryTextColor;
  final Color mutedTextColor;
  final VoidCallback onTap;

  const _SuggestionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.cardBg,
    required this.borderCol,
    required this.primaryTextColor,
    required this.mutedTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: mutedTextColor),
            ],
          ),
        ),
      ),
    );
  }
}
