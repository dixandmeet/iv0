import 'dart:convert';

class PlatformResource {
  final String id;
  final String type;
  final String name;
  final String? externalId;
  final String? parentResourceId;
  final Map<String, dynamic> metadata;
  final String status;
  final String lifecycle;
  final Map<String, dynamic> context;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlatformResource({
    required this.id,
    required this.type,
    required this.name,
    this.externalId,
    this.parentResourceId,
    this.metadata = const {},
    this.status = 'active',
    this.lifecycle = 'permanent',
    this.context = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isWritable => status == 'active' || status == 'paused';

  List<Map<String, dynamic>> get contextRefs {
    final refs = context['refs'];
    if (refs is List) {
      return refs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  factory PlatformResource.fromJson(Map<String, dynamic> json) {
    return PlatformResource(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      externalId: json['external_id'] as String?,
      parentResourceId: json['parent_resource_id'] as String?,
      metadata: _map(json['metadata']),
      status: json['status'] as String? ?? 'active',
      lifecycle: json['lifecycle'] as String? ?? 'permanent',
      context: _map(json['context']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const {};
  }
}

class ResourceCapability {
  final String resourceType;
  final String capability;
  final bool enabled;
  final Map<String, dynamic> config;
  final String? inheritsFrom;

  ResourceCapability({
    required this.resourceType,
    required this.capability,
    required this.enabled,
    this.config = const {},
    this.inheritsFrom,
  });

  factory ResourceCapability.fromJson(Map<String, dynamic> json) {
    return ResourceCapability(
      resourceType: json['resource_type'] as String,
      capability: json['capability'] as String,
      enabled: json['enabled'] as bool? ?? true,
      config: PlatformResource._map(json['config']),
      inheritsFrom: json['inherits_from'] as String?,
    );
  }
}

class PanelLayoutEntry {
  final String panel;
  final String? capability;
  final int order;
  final bool visible;

  const PanelLayoutEntry({
    required this.panel,
    this.capability,
    required this.order,
    required this.visible,
  });

  factory PanelLayoutEntry.fromJson(Map<String, dynamic> json) {
    return PanelLayoutEntry(
      panel: json['panel'] as String,
      capability: json['capability'] as String?,
      order: json['order'] as int? ?? 0,
      visible: json['visible'] as bool? ?? true,
    );
  }
}

class ResourceShellData {
  final PlatformResource resource;
  final String? channelId;
  final List<ResourceCapability> capabilities;
  final List<PanelLayoutEntry> panelLayout;
  final Map<String, dynamic>? watcher;

  ResourceShellData({
    required this.resource,
    this.channelId,
    this.capabilities = const [],
    this.panelLayout = const [],
    this.watcher,
  });

  bool hasCapability(String key) =>
      capabilities.any((c) => c.capability == key && c.enabled);

  factory ResourceShellData.fromRpcJson(Map<String, dynamic> json) {
    final resourceJson = json['resource'];
    final caps = json['capabilities'];
    final layout = json['panel_layout'];

    return ResourceShellData(
      resource: PlatformResource.fromJson(
        Map<String, dynamic>.from(resourceJson as Map),
      ),
      channelId: json['channel_id'] as String?,
      capabilities: caps is List
          ? caps
              .map((e) => ResourceCapability.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
      panelLayout: layout is List
          ? layout
              .map((e) => PanelLayoutEntry.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : layout is String
              ? (jsonDecode(layout) as List)
                  .map((e) => PanelLayoutEntry.fromJson(
                        Map<String, dynamic>.from(e as Map),
                      ))
                  .toList()
              : const [],
      watcher: json['watcher'] is Map
          ? Map<String, dynamic>.from(json['watcher'] as Map)
          : null,
    );
  }
}
