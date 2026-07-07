import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../../services/supabase_service.dart';
import '../../theme/driver_home_palette.dart';

class TimelinePanel extends StatefulWidget {
  final String resourceId;

  const TimelinePanel({super.key, required this.resourceId});

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel> {
  List<PlatformResourceEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = context.read<SupabaseService>().client;
    if (client == null) return;
    try {
      final rows = await client
          .from(Tables.resourceEvents)
          .select()
          .eq('resource_id', widget.resourceId)
          .order('created_at', ascending: false)
          .limit(50);
      setState(() {
        _events = (rows as List)
            .map((r) => PlatformResourceEvent.fromJson(r as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_events.isEmpty) {
      return const Center(
        child: Text(
          'Aucun événement',
          style: TextStyle(color: DriverHomePalette.textSecondary),
        ),
      );
    }
    final df = DateFormat('d MMM · HH:mm', 'fr_FR');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, i) {
        final e = _events[i];
        final isMessage = e.eventType == 'message';
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(_icon(e.eventType), color: DriverHomePalette.primary),
          title: Text(
            _label(e.eventType),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: DriverHomePalette.textDark,
            ),
          ),
          subtitle: Text(
            isMessage ? e.preview : df.format(e.createdAt),
            style: const TextStyle(color: DriverHomePalette.textSecondary),
          ),
          trailing: isMessage
              ? Text(
                  df.format(e.createdAt),
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 11.5,
                  ),
                )
              : null,
        );
      },
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'message':
        return LucideIcons.messageCircle;
      case 'task_created':
        return LucideIcons.listChecks;
      case 'team_synced':
        return LucideIcons.users;
      case 'member_joined':
        return LucideIcons.userPlus;
      case 'resource_created':
        return LucideIcons.sparkles;
      default:
        return LucideIcons.activity;
    }
  }

  String _label(String type) {
    switch (type) {
      case 'message':
        return 'Message';
      case 'task_created':
        return 'Tâche créée';
      case 'team_synced':
        return 'Équipe mise à jour';
      case 'member_joined':
        return 'Membre rejoint';
      case 'resource_created':
        return 'Espace créé';
      default:
        return type;
    }
  }
}
