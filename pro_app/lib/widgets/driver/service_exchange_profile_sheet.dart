import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/service_exchange_author_profile.dart';
import '../../services/driver/service_exchange_service.dart';
import '../../theme/driver_home_palette.dart';
import 'driver_avatar.dart';

/// Affiche la fiche profil résumée d'un auteur d'annonce.
Future<void> showServiceExchangeProfileSheet(
  BuildContext context,
  String authorId,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: DriverHomePalette.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ProfileSheet(authorId: authorId),
  );
}

class _ProfileSheet extends StatefulWidget {
  final String authorId;
  const _ProfileSheet({required this.authorId});

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  ServiceExchangeAuthorProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await context
        .read<ServiceExchangeService>()
        .fetchAuthorProfile(widget.authorId);
    if (mounted) {
      setState(() {
        _profile = profile;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: DriverHomePalette.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_profile == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Profil indisponible'),
            )
          else
            _content(_profile!),
        ],
      ),
    );
  }

  Widget _content(ServiceExchangeAuthorProfile p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DriverAvatar(
          initials: p.initials,
          imageUrl: p.avatarUrl,
          size: 76,
          borderColor: DriverHomePalette.softGreen,
        ),
        const SizedBox(height: 12),
        Text(
          p.label,
          style: const TextStyle(
            color: DriverHomePalette.textDark,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          [p.roleLabel, if (p.depotName != null) p.depotName!].join(' · '),
          style: const TextStyle(
            color: DriverHomePalette.textSecondary,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 16),
        if (p.habilitations.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: p.habilitations
                .map((h) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: DriverHomePalette.lightGreen,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        p.habilitationLabel(h),
                        style: const TextStyle(
                          color: DriverHomePalette.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ))
                .toList(),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _statTile(
                LucideIcons.repeat,
                '${p.exchangesDone}',
                'Échanges réalisés',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statTile(
                LucideIcons.calendar,
                p.memberSinceYear != null ? 'Depuis ${p.memberSinceYear}' : '—',
                'Membre Aule',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statTile(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: DriverHomePalette.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: DriverHomePalette.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: DriverHomePalette.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DriverHomePalette.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
