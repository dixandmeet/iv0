import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../../services/supabase_service.dart';

class TasksPanel extends StatefulWidget {
  final String? channelId;

  const TasksPanel({super.key, this.channelId});

  @override
  State<TasksPanel> createState() => _TasksPanelState();
}

class _TasksPanelState extends State<TasksPanel> {
  List<PlatformTask> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.channelId == null) {
      setState(() => _loading = false);
      return;
    }
    final client = context.read<SupabaseService>().client;
    if (client == null) return;
    try {
      final rows = await client
          .from(Tables.channelTasks)
          .select()
          .eq('channel_id', widget.channelId!)
          .order('updated_at', ascending: false);
      setState(() {
        _tasks = (rows as List)
            .map((r) => PlatformTask.fromJson(r as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tasks.isEmpty) return const Center(child: Text('Aucune tâche'));
    return ListView.builder(
      itemCount: _tasks.length,
      itemBuilder: (context, i) {
        final t = _tasks[i];
        return CheckboxListTile(
          value: t.status == 'completed',
          onChanged: null,
          title: Text(t.title),
          subtitle: Text(t.status),
        );
      },
    );
  }
}
