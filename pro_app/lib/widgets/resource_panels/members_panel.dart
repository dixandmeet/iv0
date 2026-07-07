import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../../services/supabase_service.dart';
import '../../theme/driver_home_palette.dart';
import '../driver/driver_avatar.dart';

class MembersPanel extends StatefulWidget {
  final String? channelId;

  const MembersPanel({super.key, this.channelId});

  @override
  State<MembersPanel> createState() => _MembersPanelState();
}

class _MembersPanelState extends State<MembersPanel> {
  List<_ChannelMember> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MembersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) {
      _load();
    }
  }

  Future<void> _load() async {
    final channelId = widget.channelId;
    if (channelId == null) {
      setState(() {
        _members = [];
        _loading = false;
      });
      return;
    }

    final client = context.read<SupabaseService>().client;
    if (client == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await client.rpc('ensure_self_channel_access', params: {
        'p_channel_id': channelId,
      });

      final profilesFuture = client.rpc('get_channel_member_profiles', params: {
        'p_channel_id': channelId,
      });
      final statusFuture = client
          .from(Tables.channelMembers)
          .select('user_id, status, joined_at')
          .eq('channel_id', channelId);

      final results = await Future.wait([profilesFuture, statusFuture]);
      final profilesRaw = results[0];
      final statusRaw = results[1];

      final statusByUser = <String, Map<String, dynamic>>{};
      if (statusRaw is List) {
        for (final row in statusRaw) {
          final map = Map<String, dynamic>.from(row as Map);
          final id = map['user_id'] as String?;
          if (id != null) statusByUser[id] = map;
        }
      }

      final members = <_ChannelMember>[];
      if (profilesRaw is List) {
        for (final row in profilesRaw) {
          final map = Map<String, dynamic>.from(row as Map);
          final id = map['id'] as String?;
          if (id == null) continue;
          final statusRow = statusByUser[id];
          members.add(
            _ChannelMember(
              id: id,
              displayName: (map['display_name'] as String?)?.trim().isNotEmpty ==
                      true
                  ? map['display_name'] as String
                  : 'Membre',
              avatarUrl: map['avatar_url'] as String?,
              status: statusRow?['status'] as String? ?? 'active',
              joinedAt: statusRow?['joined_at'] != null
                  ? DateTime.tryParse(statusRow!['joined_at'] as String)
                  : null,
            ),
          );
        }
      }

      members.sort((a, b) {
        final activeCmp = _statusOrder(a.status).compareTo(_statusOrder(b.status));
        if (activeCmp != 0) return activeCmp;
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });

      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _members = [];
        _loading = false;
        _error = 'Impossible de charger les membres';
      });
    }
  }

  int _statusOrder(String status) {
    switch (status) {
      case 'active':
        return 0;
      case 'left':
        return 1;
      case 'removed':
        return 2;
      case 'blocked':
        return 3;
      default:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: DriverHomePalette.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: DriverHomePalette.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    if (_members.isEmpty) {
      return const Center(
        child: Text(
          'Aucun membre',
          style: TextStyle(
            color: DriverHomePalette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final activeCount =
        _members.where((m) => m.status == 'active').length;

    return RefreshIndicator(
      color: DriverHomePalette.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _MembersSummary(
            total: _members.length,
            active: activeCount,
          ),
          const SizedBox(height: 14),
          ..._members.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MemberTile(member: m),
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersSummary extends StatelessWidget {
  final int total;
  final int active;

  const _MembersSummary({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DriverHomePalette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DriverHomePalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DriverHomePalette.lightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.usersRound,
              color: DriverHomePalette.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total membre${total > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: DriverHomePalette.textDark,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '$active actif${active > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: DriverHomePalette.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final _ChannelMember member;

  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final active = member.status == 'active';

    return Material(
      color: DriverHomePalette.card,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: DriverHomePalette.border),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            DriverAvatarCompact(
              initials: member.initials,
              imageUrl: member.avatarUrl,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: const TextStyle(
                      color: DriverHomePalette.textDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (member.joinedLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      member.joinedLabel!,
                      style: const TextStyle(
                        color: DriverHomePalette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _MemberStatusBadge(status: member.status, active: active),
          ],
        ),
      ),
    );
  }
}

class _MemberStatusBadge extends StatelessWidget {
  final String status;
  final bool active;

  const _MemberStatusBadge({required this.status, required this.active});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'active' => ('Actif', DriverHomePalette.primary, DriverHomePalette.lightGreen),
      'left' => ('Parti', DriverHomePalette.textSecondary, DriverHomePalette.background),
      'removed' => ('Retiré', DriverHomePalette.warning, const Color(0xFFFFF4E8)),
      'blocked' => ('Bloqué', DriverHomePalette.danger, const Color(0xFFFFEBEB)),
      _ => (status, DriverHomePalette.textSecondary, DriverHomePalette.background),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChannelMember {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String status;
  final DateTime? joinedAt;

  const _ChannelMember({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.status,
    this.joinedAt,
  });

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length < 2 ? word.length : 2).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String? get joinedLabel {
    if (joinedAt == null) return null;
    final now = DateTime.now();
    final diff = now.difference(joinedAt!);
    if (diff.inDays == 0) return 'Rejoint aujourd\'hui';
    if (diff.inDays == 1) return 'Rejoint hier';
    if (diff.inDays < 30) return 'Rejoint il y a ${diff.inDays} j';
    return 'Membre depuis ${joinedAt!.day}/${joinedAt!.month}/${joinedAt!.year}';
  }
}
