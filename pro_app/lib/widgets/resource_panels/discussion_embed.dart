import 'package:flutter/material.dart';

import '../../screens/resource/resource_shell_screen.dart';

/// Widget embeddable sur toute fiche métier.
class DiscussionEmbed extends StatelessWidget {
  final String resourceId;
  final int? messageCount;

  const DiscussionEmbed({
    super.key,
    required this.resourceId,
    this.messageCount,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.chat_bubble_outline),
      title: Text('Discussion${messageCount != null ? ' ($messageCount)' : ''}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResourceShellScreen(resourceId: resourceId),
        ),
      ),
    );
  }
}
