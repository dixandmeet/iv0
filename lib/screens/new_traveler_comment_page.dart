import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/gtfs.dart';
import '../models/traveler_comment.dart';
import '../services/gtfs_service.dart';
import '../services/traveler_comment_service.dart';
import '../theme/app_fonts.dart';
import '../theme/aule_theme.dart';

class NewTravelerCommentPage extends StatefulWidget {
  final GtfsRoute route;
  final NearbyStation station;
  final List<GtfsStop> stops;
  final Color lineColor;
  final TravelerCommentAccessState accessState;

  const NewTravelerCommentPage({
    super.key,
    required this.route,
    required this.station,
    required this.stops,
    required this.lineColor,
    this.accessState = TravelerCommentAccessState.certified,
  });

  @override
  State<NewTravelerCommentPage> createState() => _NewTravelerCommentPageState();
}

class _NewTravelerCommentPageState extends State<NewTravelerCommentPage> {
  static const _maxLength = 500;

  TravelerCommentCategory _category = TravelerCommentCategory.delay;
  GtfsStop? _selectedStop;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedStop = widget.station.stop;
    _messageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                child: _buildBody(context),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          widget.accessState == TravelerCommentAccessState.certified
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _canPublish ? _publish : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.lineColor,
                        disabledBackgroundColor:
                            widget.lineColor.withValues(alpha: 0.32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 10,
                        shadowColor: widget.lineColor.withValues(alpha: 0.34),
                      ),
                      child: Text(
                        'Publier',
                        style: hankenGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                )
              : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (widget.accessState) {
      case TravelerCommentAccessState.certified:
        return _CertifiedForm(
          category: _category,
          selectedStop: _selectedStop,
          stops: widget.stops,
          messageController: _messageController,
          lineColor: widget.lineColor,
          onCategoryChanged: (category) => setState(() {
            _category = category;
          }),
          onStopChanged: (stop) => setState(() {
            _selectedStop = stop;
          }),
        );
      case TravelerCommentAccessState.anonymous:
        return _AccessStateCard(
          icon: LucideIcons.logIn,
          title: 'Connectez-vous pour contribuer et partager votre expérience.',
          body:
              'Les commentaires restent visibles en consultation, même sans compte.',
          primaryLabel: 'Se connecter',
          secondaryLabel: 'Continuer en mode consultation',
          lineColor: widget.lineColor,
          onPrimary: () =>
              _showAccessSnack('Connexion à brancher au flux compte.'),
          onSecondary: () => Navigator.pop(context),
        );
      case TravelerCommentAccessState.nonCertified:
        return _AccessStateCard(
          icon: LucideIcons.shieldQuestion,
          title:
              'La certification permet de garantir la fiabilité des informations partagées.',
          body:
              'Un voyageur peut être certifié par téléphone, email, usage régulier ou trajets réels détectés par géolocalisation.',
          primaryLabel: 'En savoir plus',
          lineColor: widget.lineColor,
          onPrimary: () => _showAccessSnack(
            'Certification à brancher au parcours de profil voyageur.',
          ),
        );
    }
  }

  bool get _canPublish =>
      _messageController.text.trim().isNotEmpty &&
      _messageController.text.characters.length <= _maxLength;

  void _publish() {
    final lineName = widget.route.routeShortName ?? widget.route.routeId;
    final stopName = _selectedStop?.stopName ?? widget.station.stop.stopName;
    final vehicleName = _vehicleName(widget.route, lineName);
    final contextKey = TravelerCommentService.contextKey(
      routeId: widget.route.routeId,
      stopId: widget.station.stop.stopId,
    );
    final service = _maybeCommentService(context);
    final comment = service?.addComment(
          contextKey: contextKey,
          lineName: lineName,
          vehicleName: vehicleName,
          stopName: stopName,
          category: _category,
          message: _messageController.text,
        ) ??
        TravelerComment(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          authorName: 'Vous',
          lineName: lineName,
          vehicleName: vehicleName,
          stopName: stopName,
          createdAt: DateTime.now(),
          category: _category,
          message: _messageController.text.trim(),
          reactionCount: 0,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Commentaire publié.')),
    );
    Navigator.pop(context, comment);
  }

  void _showAccessSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _vehicleName(GtfsRoute route, String lineName) {
    switch (route.transportType.toLowerCase()) {
      case 'tram':
        return 'Tram $lineName';
      case 'navibus':
        return 'Navibus $lineName';
      case 'busway':
        return 'Chronobus $lineName';
      default:
        return 'Bus $lineName';
    }
  }
}

TravelerCommentService? _maybeCommentService(BuildContext context) {
  try {
    return Provider.of<TravelerCommentService>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(LucideIcons.arrowLeft, color: colors.text),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Nouveau commentaire',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: hankenGrotesk(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertifiedForm extends StatelessWidget {
  final TravelerCommentCategory category;
  final GtfsStop? selectedStop;
  final List<GtfsStop> stops;
  final TextEditingController messageController;
  final Color lineColor;
  final ValueChanged<TravelerCommentCategory> onCategoryChanged;
  final ValueChanged<GtfsStop?> onStopChanged;

  const _CertifiedForm({
    required this.category,
    required this.selectedStop,
    required this.stops,
    required this.messageController,
    required this.lineColor,
    required this.onCategoryChanged,
    required this.onStopChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    final messageLength = messageController.text.characters.length;
    final visibleStops = stops.take(24).toList();
    if (selectedStop != null &&
        !visibleStops.any((stop) => stop.stopId == selectedStop!.stopId)) {
      visibleStops.insert(0, selectedStop!);
    }
    final dropdownStop = selectedStop == null
        ? null
        : visibleStops.firstWhere(
            (stop) => stop.stopId == selectedStop!.stopId,
            orElse: () => selectedStop!,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoPanel(
          icon: LucideIcons.shieldCheck,
          text:
              'Seuls les voyageurs certifiés peuvent partager des commentaires.',
          lineColor: lineColor,
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Catégorie'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TravelerCommentCategory.values.map((item) {
            final isSelected = item == category;
            return FilterChip(
              selected: isSelected,
              showCheckmark: false,
              label: Text(item.label),
              onSelected: (_) => onCategoryChanged(item),
              labelStyle: hankenGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? item.color : colors.muted,
              ),
              selectedColor: item.color.withValues(alpha: 0.16),
              backgroundColor: colors.surface,
              side: BorderSide(
                color: isSelected
                    ? item.color.withValues(alpha: 0.35)
                    : colors.line,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Arrêt concerné (optionnel)'),
        const SizedBox(height: 10),
        DropdownButtonFormField<GtfsStop?>(
          initialValue: dropdownStop,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: lineColor, width: 1.4),
            ),
          ),
          icon: Icon(LucideIcons.chevronDown, size: 18, color: colors.muted),
          style: hankenGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: colors.text,
          ),
          items: [
            DropdownMenuItem<GtfsStop?>(
              value: null,
              child: Text(
                'Aucun arrêt précis',
                style: hankenGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.muted,
                ),
              ),
            ),
            ...visibleStops.map(
              (stop) => DropdownMenuItem<GtfsStop?>(
                value: stop,
                child: Text(
                  stop.stopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onStopChanged,
        ),
        const SizedBox(height: 22),
        const _FieldLabel('Votre commentaire'),
        const SizedBox(height: 10),
        TextField(
          controller: messageController,
          minLines: 7,
          maxLines: 9,
          maxLength: _NewTravelerCommentPageState._maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          style: hankenGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.text,
            height: 1.35,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText:
                'Partagez votre expérience...\nRespectez les autres voyageurs.',
            hintStyle: hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.faint,
              height: 1.35,
            ),
            filled: true,
            fillColor: colors.surface,
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: colors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: lineColor, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$messageLength/${_NewTravelerCommentPageState._maxLength}',
            style: hankenGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: messageLength > 450 ? lineColor : colors.muted,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _InfoPanel(
          icon: LucideIcons.eye,
          text:
              'Votre commentaire sera public et visible par tous les voyageurs.',
          lineColor: lineColor,
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    return Text(
      label,
      style: hankenGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: colors.text,
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color lineColor;

  const _InfoPanel({
    required this.icon,
    required this.text,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.brandWeak,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.brandLine),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: lineColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: hankenGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: colors.text,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final String? secondaryLabel;
  final Color lineColor;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  const _AccessStateCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.lineColor,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AuleTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.line),
        boxShadow: AuleTokens.cardShadow(colors.shadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.brandWeak,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 25, color: lineColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: hankenGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: hankenGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: lineColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                primaryLabel,
                style: hankenGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: hankenGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: lineColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
