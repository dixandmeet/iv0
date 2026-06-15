import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../services/location_service.dart';
import '../../services/report_service.dart';
import '../../theme/flow_theme.dart';
import '../../widgets/flow_primitives.dart';
import '../../widgets/flow_widgets.dart';

class ReportIncidentBottomSheet extends StatefulWidget {
  final String? preselectedRouteId;
  final String? preselectedVehicleId;

  const ReportIncidentBottomSheet({
    super.key,
    this.preselectedRouteId,
    this.preselectedVehicleId,
  });

  @override
  State<ReportIncidentBottomSheet> createState() => _ReportIncidentBottomSheetState();
}

class _ReportIncidentBottomSheetState extends State<ReportIncidentBottomSheet> {
  final TextEditingController _routeController = TextEditingController();
  String? _submittingType;

  static const List<_ReportType> _types = [
    _ReportType('delay', 'Retard', LucideIcons.timer, FlowColors.orange, FlowColors.orangeSoft),
    _ReportType('breakdown', 'Panne', LucideIcons.wrench, FlowColors.red, FlowColors.redSoft),
    _ReportType('crowded', 'Bondé', LucideIcons.users, FlowColors.orange, FlowColors.orangeSoft),
    _ReportType('control', 'Contrôle', LucideIcons.badgeCheck, FlowColors.blue, FlowColors.blueSoft),
    _ReportType('accident', 'Incident', LucideIcons.circleAlert, FlowColors.red, FlowColors.redSoft),
    _ReportType('safety', 'Sécurité', LucideIcons.shield, FlowColors.red, FlowColors.redSoft),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedRouteId != null) {
      _routeController.text = widget.preselectedRouteId!;
    }
  }

  @override
  void dispose() {
    _routeController.dispose();
    super.dispose();
  }

  Future<void> _submit(String type) async {
    final routeId = _routeController.text.trim().isEmpty
        ? 'Réseau'
        : _routeController.text.trim().toUpperCase();

    setState(() => _submittingType = type);

    final location = Provider.of<LocationService>(context, listen: false);
    final reportService = Provider.of<ReportService>(context, listen: false);

    LatLng reportPos = const LatLng(47.218371, -1.553621);
    final userPos = location.currentPosition;
    if (userPos != null) {
      reportPos = LatLng(userPos.latitude, userPos.longitude);
    }

    final success = await reportService.submitReport(
      routeId: routeId,
      reportType: type,
      position: reportPos,
      vehicleId: widget.preselectedVehicleId,
    );

    if (!mounted) return;
    setState(() => _submittingType = null);

    if (success) {
      // Le toast vit dans l'overlay racine : il survit à la fermeture du sheet.
      showFlowToast(context, 'Signalement envoyé · 100 % anonyme. Merci !',
          icon: LucideIcons.circleCheck);
      Navigator.pop(context);
    } else {
      showFlowToast(context, 'Erreur lors de l\'envoi du signalement.',
          icon: LucideIcons.triangleAlert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = widget.preselectedRouteId != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: FlowSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Que se passe-t-il ?', style: FlowText.title),
                FlowIconButton(
                  icon: LucideIcons.x,
                  size: 38,
                  iconSize: 18,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Contexte
            if (hasRoute)
              Row(
                children: [
                  LineBadge(code: widget.preselectedRouteId!, transportType: 'bus'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Sur la ligne ${widget.preselectedRouteId}',
                        style: FlowText.rowSub.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              )
            else
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: FlowColors.fill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.route, size: 18, color: FlowColors.g2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FlowTextField(
                        controller: _routeController,
                        textCapitalization: TextCapitalization.characters,
                        hintText: 'Ligne concernée (optionnel)',
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Grille 3 x 2
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.96,
              children: _types.map((t) {
                final loading = _submittingType == t.type;
                return _ReportCell(
                  type: t,
                  loading: loading,
                  disabled: _submittingType != null && !loading,
                  onTap: () => _submit(t.type),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Pied anonyme
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.venetianMask, size: 18, color: FlowColors.g2),
                SizedBox(width: 8),
                Text('Signalement 100 % anonyme',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: FlowColors.g2)),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _ReportType {
  final String type;
  final String label;
  final IconData icon;
  final Color color;
  final Color soft;
  const _ReportType(this.type, this.label, this.icon, this.color, this.soft);
}

class _ReportCell extends StatelessWidget {
  final _ReportType type;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;
  const _ReportCell({required this.type, required this.loading, required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: loading ? 0.95 : 1,
      duration: const Duration(milliseconds: 140),
      child: FlowTappable(
        onTap: disabled ? null : onTap,
        pressedScale: 0.95,
        child: Container(
          decoration: BoxDecoration(
            color: FlowColors.fill,
            borderRadius: BorderRadius.circular(15),
            border: loading ? Border.all(color: type.color) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: type.soft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: type.color),
                      )
                    : Icon(type.icon, size: 22, color: type.color),
              ),
              const SizedBox(height: 9),
              Text(type.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
