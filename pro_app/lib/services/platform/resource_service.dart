import 'package:flutter/foundation.dart';
import 'package:shared/shared.dart';

import '../supabase_service.dart';

/// Accès ressources, shell, watchers et graphe.
class ResourceService with ChangeNotifier {
  ResourceService({required SupabaseService supabaseService})
      : _supabase = supabaseService;

  final SupabaseService _supabase;

  ResourceShellData? _shell;
  List<Map<String, dynamic>> _graph = [];
  bool _loading = false;
  String? _error;

  ResourceShellData? get shell => _shell;
  List<Map<String, dynamic>> get graph => List.unmodifiable(_graph);
  bool get loading => _loading;
  String? get error => _error;

  Future<ResourceShellData?> loadShell(String resourceId) async {
    final client = _supabase.client;
    if (client == null) return null;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final raw = await client.rpc('get_resource_shell', params: {
        'p_resource_id': resourceId,
      });
      if (raw == null) return null;
      _shell = ResourceShellData.fromRpcJson(Map<String, dynamic>.from(raw as Map));
      final graphRaw = await client.rpc('get_resource_graph', params: {
        'p_resource_id': resourceId,
        'p_depth': 2,
      });
      if (graphRaw is List) {
        _graph = graphRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        _graph = const [];
      }
      return _shell;
    } catch (e) {
      debugPrint('Aule: loadShell failed ($e)');
      _error = 'Impossible de charger la ressource';
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> upsertResource({
    required String type,
    required String name,
    String? externalId,
    String? parentResourceId,
    String lifecycle = 'permanent',
  }) async {
    final client = _supabase.client;
    if (client == null) return null;
    try {
      final id = await client.rpc('upsert_platform_resource', params: {
        'p_type': type,
        'p_name': name,
        'p_external_id': externalId,
        'p_parent_resource_id': parentResourceId,
        'p_lifecycle': lifecycle,
      });
      return id as String?;
    } catch (e) {
      debugPrint('Aule: upsertResource failed ($e)');
      return null;
    }
  }

  Future<void> watchResource(String resourceId, {String mode = 'all'}) async {
    final client = _supabase.client;
    if (client == null) return;
    await client.rpc('watch_resource', params: {
      'p_resource_id': resourceId,
      'p_mode': mode,
    });
  }

  Future<void> unwatchResource(String resourceId) async {
    final client = _supabase.client;
    if (client == null) return;
    await client.rpc('unwatch_resource', params: {
      'p_resource_id': resourceId,
    });
  }

  void clear() {
    _shell = null;
    _graph = [];
    notifyListeners();
  }
}
