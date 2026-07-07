import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/supabase_service.dart';

/// Support voyageur — ressource support contrôlée (Phase 5).
class SupportContactScreen extends StatefulWidget {
  const SupportContactScreen({super.key});

  static const supportResourceId = '00000000-0000-4000-8000-000000000101';

  @override
  State<SupportContactScreen> createState() => _SupportContactScreenState();
}

class _SupportContactScreenState extends State<SupportContactScreen> {
  final _controller = TextEditingController();
  List<PlatformMessage> _messages = [];
  String? _channelId;
  bool _loading = true;
  RealtimeChannel? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final client = context.read<SupabaseService>().client;
    if (client == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      _channelId = await client.rpc('join_support_channel') as String?;
      await _loadMessages();
      if (_channelId != null) _subscribe(_channelId!);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMessages() async {
    final client = context.read<SupabaseService>().client;
    if (client == null || _channelId == null) return;
    final rows = await client
        .from(Tables.messages)
        .select()
        .eq('channel_id', _channelId!)
        .order('created_at');
    setState(() {
      _messages = (rows as List)
          .map((r) => PlatformMessage.fromJson(r as Map<String, dynamic>))
          .toList();
    });
  }

  void _subscribe(String channelId) {
    final client = context.read<SupabaseService>().client;
    if (client == null) return;
    _sub = client
        .channel('passenger-support')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: Tables.messages,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel_id',
            value: channelId,
          ),
          callback: (_) => _loadMessages(),
        )
        .subscribe();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final userId = context.read<AuthService>().profile?.id;
    final client = context.read<SupabaseService>().client;
    if (text.isEmpty || userId == null || client == null || _channelId == null) {
      return;
    }
    _controller.clear();
    await client.from(Tables.messages).insert({
      'channel_id': _channelId,
      'sender_id': userId,
      'message_type': 'text',
      'body': text,
    });
    await _loadMessages();
  }

  @override
  void dispose() {
    _sub?.unsubscribe();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacter le support')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      return ListTile(
                        title: Text(m.body),
                        subtitle: Text(m.createdAt.toLocal().toString()),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Votre message…',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(onPressed: _send, icon: const Icon(Icons.send)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
