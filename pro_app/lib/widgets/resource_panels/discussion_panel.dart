import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../../services/auth_service.dart';
import '../../services/platform/conversation_context_service.dart';
import '../../services/platform/discussion_service.dart';
import '../../theme/driver_home_palette.dart';
import '../platform/conversation_context_header.dart';
import '../platform/conversation_context_registry.dart';
import '../platform/conversation_timeline.dart';

class DiscussionPanel extends StatefulWidget {
  final String resourceId;
  final String? channelId;
  final bool readOnly;

  const DiscussionPanel({
    super.key,
    required this.resourceId,
    this.channelId,
    this.readOnly = false,
  });

  @override
  State<DiscussionPanel> createState() => _DiscussionPanelState();
}

class _DiscussionPanelState extends State<DiscussionPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  Future<void> _open() async {
    final discussion = context.read<DiscussionService>();
    final ctxService = context.read<ConversationContextService>();
    final userId = context.read<AuthService>().profile?.id;
    if (widget.channelId != null) {
      await discussion.openChannel(widget.channelId!, userId: userId);
    } else {
      await discussion.openForResource(widget.resourceId, userId: userId);
    }
    final cid = discussion.channelId;
    if (cid != null && mounted) {
      await ctxService.load(cid, silent: false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final userId = context.read<AuthService>().profile?.id;
    if (userId == null) return;
    _controller.clear();
    HapticFeedback.lightImpact();
    await context.read<DiscussionService>().sendMessage(
      senderId: userId,
      body: text,
    );
    _scrollToBottom();
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final discussion = context.watch<DiscussionService>();
    final ctxService = context.watch<ConversationContextService>();
    final userId = context.read<AuthService>().profile?.id;
    final messages = discussion.messages;
    final channelId = discussion.channelId;

    // Auto-scroll quand un nouveau message arrive (envoyé ou reçu en realtime).
    if (messages.length != _lastMessageCount) {
      final grew = messages.length > _lastMessageCount;
      _lastMessageCount = messages.length;
      if (grew) _scrollToBottom(animated: true);
    }

    // En-tête de chaque conversation : carte(s) live + timeline génériques,
    // pilotées par le registry selon le context_type.
    final leading = <Widget>[];
    if (channelId != null) {
      for (final ctx in ctxService.contextsFor(channelId)) {
        final card = ConversationContextRegistry.buildCard(context, ctx);
        if (card != null) leading.add(card);
      }
      if (ctxService.timelineFor(channelId).isNotEmpty) {
        leading.add(ConversationTimeline(channelId: channelId));
      }
    }

    return Column(
      children: [
        if (channelId != null) ConversationContextHeader(channelId: channelId),
        Expanded(
          child: discussion.loading
              ? const Center(child: CircularProgressIndicator())
              : (messages.isEmpty && leading.isEmpty)
              ? const _EmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  itemCount: leading.length + messages.length,
                  itemBuilder: (context, index) {
                    if (index < leading.length) return leading[index];
                    final i = index - leading.length;
                    final m = messages[i];
                    final prev = i > 0 ? messages[i - 1] : null;
                    final next = i < messages.length - 1
                        ? messages[i + 1]
                        : null;

                    final showDate =
                        prev == null || !_sameDay(prev.createdAt, m.createdAt);

                    // Message système (avis de modification / clôture).
                    if (m.metadata['system'] == true) {
                      return Column(
                        children: [
                          if (showDate) _DateSeparator(date: m.createdAt),
                          _SystemNotice(text: m.body),
                        ],
                      );
                    }

                    final mine = m.isMine(userId);
                    final prevSameAuthor =
                        prev != null &&
                        prev.metadata['system'] != true &&
                        prev.senderId == m.senderId &&
                        _sameDay(prev.createdAt, m.createdAt);
                    final nextSameAuthor =
                        next != null &&
                        next.metadata['system'] != true &&
                        next.senderId == m.senderId &&
                        _sameDay(next.createdAt, m.createdAt);

                    final isFirstOfGroup = !prevSameAuthor;
                    final isLastOfGroup = !nextSameAuthor;

                    return Column(
                      children: [
                        if (showDate) _DateSeparator(date: m.createdAt),
                        _MessageRow(
                          message: m,
                          mine: mine,
                          isFirstOfGroup: isFirstOfGroup,
                          isLastOfGroup: isLastOfGroup,
                          senderName: discussion.senderName(m.senderId),
                          avatarUrl: discussion.senderAvatar(m.senderId),
                        ),
                      ],
                    );
                  },
                ),
        ),
        if (widget.readOnly)
          const SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Discussion archivée · lecture seule',
                style: TextStyle(
                  color: DriverHomePalette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
        else
          _Composer(
            controller: _controller,
            sending: discussion.sending,
            canSend: _controller.text.trim().isNotEmpty,
            onSend: _send,
            onQuickReply: (q) {
              _controller.text = q;
              _send();
            },
          ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Une ligne de message : avatar (gouttière en groupe) + bulle.
class _MessageRow extends StatelessWidget {
  final PlatformMessage message;
  final bool mine;
  final bool isFirstOfGroup;
  final bool isLastOfGroup;
  final String? senderName;
  final String? avatarUrl;

  const _MessageRow({
    required this.message,
    required this.mine,
    required this.isFirstOfGroup,
    required this.isLastOfGroup,
    required this.senderName,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    final bubble = Flexible(
      child: Container(
        margin: EdgeInsets.only(bottom: isLastOfGroup ? 10 : 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        decoration: BoxDecoration(
          color: mine ? DriverHomePalette.primary : DriverHomePalette.card,
          borderRadius: _bubbleRadius(mine, isFirstOfGroup, isLastOfGroup),
          border: mine ? null : Border.all(color: DriverHomePalette.border),
          boxShadow: mine
              ? null
              : const [
                  BoxShadow(
                    color: DriverHomePalette.cardShadow,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine && isFirstOfGroup && senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  senderName!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _senderColor(senderName!),
                  ),
                ),
              ),
            if (m.linkedEntityType != null &&
                !(m.linkedEntityType as String).startsWith('service_exchange'))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '📎 ${m.linkedEntityType}: ${m.linkedEntityId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: mine ? Colors.white70 : DriverHomePalette.primary,
                  ),
                ),
              ),
            Text(
              m.body,
              style: TextStyle(
                fontSize: 15,
                height: 1.3,
                color: mine ? Colors.white : DriverHomePalette.textDark,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(m.createdAt),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: mine
                        ? Colors.white70
                        : DriverHomePalette.textSecondary,
                  ),
                ),
                if (m.editedAt != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    'modifié',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: mine
                          ? Colors.white70
                          : DriverHomePalette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (mine) {
      return Row(mainAxisAlignment: MainAxisAlignment.end, children: [bubble]);
    }

    // Côté autrui : avatar collé au dernier message du groupe, gouttière sinon
    // pour conserver l'alignement vertical.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: EdgeInsets.only(right: 8, bottom: isLastOfGroup ? 10 : 2),
          child: isLastOfGroup
              ? _Avatar(name: senderName, url: avatarUrl)
              : const SizedBox(width: 32),
        ),
        bubble,
      ],
    );
  }

  static BorderRadius _bubbleRadius(bool mine, bool isFirst, bool isLast) {
    const r = Radius.circular(18);
    const tail = Radius.circular(5);
    return BorderRadius.only(
      topLeft: (!mine && !isFirst) ? tail : r,
      topRight: (mine && !isFirst) ? tail : r,
      bottomLeft: (!mine && !isLast) ? tail : r,
      bottomRight: (mine && !isLast) ? tail : r,
    );
  }
}

/// Avatar circulaire : image réseau si dispo, sinon initiales colorées.
class _Avatar extends StatelessWidget {
  final String? name;
  final String? url;
  const _Avatar({this.name, this.url});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final color = _senderColor(name ?? '?');
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withValues(alpha: 0.15),
      backgroundImage: (url != null && url!.isNotEmpty)
          ? NetworkImage(url!)
          : null,
      child: (url == null || url!.isEmpty)
          ? Text(
              initials,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            )
          : null,
    );
  }

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

/// Couleur déterministe par expéditeur (pour distinguer les voix en groupe).
Color _senderColor(String key) {
  const palette = [
    DriverHomePalette.primary,
    DriverHomePalette.blue,
    DriverHomePalette.purple,
    DriverHomePalette.warning,
    DriverHomePalette.controlAccent,
    Color(0xFF1F9E8E),
  ];
  if (key.isEmpty) return palette.first;
  final hash = key.codeUnits.fold<int>(0, (acc, c) => acc + c);
  return palette[hash % palette.length];
}

/// Séparateur de date centré (Aujourd'hui / Hier / date complète).
class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;
    final String label;
    if (diff == 0) {
      label = "Aujourd'hui";
    } else if (diff == 1) {
      label = 'Hier';
    } else if (diff < 7) {
      label = DateFormat('EEEE', 'fr_FR').format(date);
    } else {
      label = DateFormat('d MMMM y', 'fr_FR').format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: DriverHomePalette.lightGreen,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label[0].toUpperCase() + label.substring(1),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: DriverHomePalette.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// État vide : aucun message dans le canal.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: DriverHomePalette.softGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: DriverHomePalette.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun message',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: DriverHomePalette.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Lancez la discussion de l\'équipe :\nposez une question ou faites un point.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: DriverHomePalette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notice système discrète au centre du fil (avis de modification, clôture).
class _SystemNotice extends StatelessWidget {
  final String text;
  const _SystemNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: DriverHomePalette.softGreen.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: DriverHomePalette.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool canSend;
  final VoidCallback onSend;
  final ValueChanged<String> onQuickReply;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.canSend,
    required this.onSend,
    required this.onQuickReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DriverHomePalette.card,
        border: Border(top: BorderSide(color: DriverHomePalette.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: DiscussionService.quickReplies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final q = DiscussionService.quickReplies[i];
                return ActionChip(
                  label: Text(q),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DriverHomePalette.primary,
                  ),
                  backgroundColor: DriverHomePalette.lightGreen,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: sending ? null : () => onQuickReply(q),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    filled: true,
                    fillColor: DriverHomePalette.background,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: DriverHomePalette.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: DriverHomePalette.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                sending: sending,
                enabled: canSend && !sending,
                onSend: onSend,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  const _SendButton({
    required this.sending,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: enabled
            ? DriverHomePalette.primary
            : DriverHomePalette.primary.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: enabled ? onSend : null,
        icon: sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}
