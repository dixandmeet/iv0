import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../../services/supabase_service.dart';

class DocumentsPanel extends StatefulWidget {
  final String? channelId;

  const DocumentsPanel({super.key, this.channelId});

  @override
  State<DocumentsPanel> createState() => _DocumentsPanelState();
}

class _DocumentsPanelState extends State<DocumentsPanel> {
  List<PlatformFile> _files = [];
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
          .from(Tables.channelFiles)
          .select()
          .eq('channel_id', widget.channelId!)
          .order('created_at', ascending: false);
      setState(() {
        _files = (rows as List)
            .map((r) => PlatformFile.fromJson(r as Map<String, dynamic>))
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
    if (_files.isEmpty) {
      return const Center(child: Text('Aucun document'));
    }
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, i) {
        final f = _files[i];
        return ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(f.fileName),
        );
      },
    );
  }
}
