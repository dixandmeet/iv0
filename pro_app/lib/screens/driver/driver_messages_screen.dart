import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/driver/driver_message.dart';
import '../../services/driver/driver_message_service.dart';
import '../../services/driver/driver_service.dart';

/// Messagerie régulateur : fil de discussion, réponses rapides et saisie libre.
class DriverMessagesScreen extends StatefulWidget {
  const DriverMessagesScreen({super.key});

  @override
  State<DriverMessagesScreen> createState() => _DriverMessagesScreenState();
}

class _DriverMessagesScreenState extends State<DriverMessagesScreen> {
  final _controller = TextEditingController();
  String? _driverId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final driverId = context.read<DriverService>().driver?.id;
    if (driverId == null) return;
    _driverId = driverId;
    final messages = context.read<DriverMessageService>();
    await messages.fetchMessages(driverId);
    await messages.markRegulatorMessagesRead(driverId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final id = _driverId;
    if (id == null || text.trim().isEmpty) return;
    _controller.clear();
    await context.read<DriverMessageService>().sendReply(id, text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messageService = context.watch<DriverMessageService>();
    final messages = messageService.messages;

    return Column(
      children: [
        Expanded(
          child: messageService.loading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
                  ? _EmptyMessages(theme: theme)
                  : RefreshIndicator(
                      onRefresh: () async {
                        if (_driverId != null) {
                          await messageService.fetchMessages(_driverId!);
                        }
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: messages.length,
                        itemBuilder: (context, i) =>
                            _MessageBubble(message: messages[i]),
                      ),
                    ),
        ),

        // Réponses rapides
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: DriverMessageService.quickReplies
                .map((q) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(q),
                        onPressed: messageService.sending ? null : () => _send(q),
                      ),
                    ))
                .toList(),
          ),
        ),

        // Saisie libre
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: 'Votre message…',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: messageService.sending
                      ? null
                      : () => _send(_controller.text),
                  icon: const Icon(LucideIcons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final DriverMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.isFromDriver;
    final bg = mine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fg =
        mine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.radio,
                        size: 12, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text('Régulateur',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ),
            Text(message.message, style: TextStyle(color: fg)),
            const SizedBox(height: 2),
            Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  final ThemeData theme;
  const _EmptyMessages({required this.theme});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(LucideIcons.messageCircle,
            size: 56, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Center(
          child: Text('Aucun message',
              style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text('Les messages du régulateur apparaîtront ici.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}
