import 'platform_enums.dart';

class PlatformMessage {
  final String id;
  final String channelId;
  final String? senderId;
  final PlatformMessageType messageType;
  final String body;
  final Map<String, dynamic> metadata;
  final String? linkedEntityType;
  final String? linkedEntityId;
  final String priority;
  final String? replyToId;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  PlatformMessage({
    required this.id,
    required this.channelId,
    this.senderId,
    this.messageType = PlatformMessageType.text,
    this.body = '',
    this.metadata = const {},
    this.linkedEntityType,
    this.linkedEntityId,
    this.priority = 'normal',
    this.replyToId,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  bool isMine(String? userId) => senderId != null && senderId == userId;

  factory PlatformMessage.fromJson(Map<String, dynamic> json) {
    return PlatformMessage(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      senderId: json['sender_id'] as String?,
      messageType: PlatformMessageType.fromDb(json['message_type'] as String?),
      body: json['body'] as String? ?? '',
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
      linkedEntityType: json['linked_entity_type'] as String?,
      linkedEntityId: json['linked_entity_id'] as String?,
      priority: json['priority'] as String? ?? 'normal',
      replyToId: json['reply_to_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson({
    required String channelId,
    required String senderId,
  }) {
    return {
      'channel_id': channelId,
      'sender_id': senderId,
      'message_type': messageType.dbValue,
      'body': body,
      if (metadata.isNotEmpty) 'metadata': metadata,
      if (linkedEntityType != null) 'linked_entity_type': linkedEntityType,
      if (linkedEntityId != null) 'linked_entity_id': linkedEntityId,
      'priority': priority,
      if (replyToId != null) 'reply_to_id': replyToId,
    };
  }
}

class PlatformNotification {
  final String id;
  final String userId;
  final NotificationCategory category;
  final String sourceType;
  final String? sourceId;
  final String? resourceId;
  final String? channelId;
  final String title;
  final String? body;
  final String priority;
  final DateTime? readAt;
  final DateTime createdAt;

  PlatformNotification({
    required this.id,
    required this.userId,
    required this.category,
    required this.sourceType,
    this.sourceId,
    this.resourceId,
    this.channelId,
    required this.title,
    this.body,
    this.priority = 'normal',
    this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  PlatformNotification copyWith({DateTime? readAt}) {
    return PlatformNotification(
      id: id,
      userId: userId,
      category: category,
      sourceType: sourceType,
      sourceId: sourceId,
      resourceId: resourceId,
      channelId: channelId,
      title: title,
      body: body,
      priority: priority,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  factory PlatformNotification.fromJson(Map<String, dynamic> json) {
    return PlatformNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: NotificationCategory.fromDb(json['category'] as String?),
      sourceType: json['source_type'] as String,
      sourceId: json['source_id'] as String?,
      resourceId: json['resource_id'] as String?,
      channelId: json['channel_id'] as String?,
      title: json['title'] as String,
      body: json['body'] as String?,
      priority: json['priority'] as String? ?? 'normal',
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PlatformTask {
  final String id;
  final String channelId;
  final String? resourceId;
  final String title;
  final String? description;
  final String? assignedTo;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlatformTask({
    required this.id,
    required this.channelId,
    this.resourceId,
    required this.title,
    this.description,
    this.assignedTo,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlatformTask.fromJson(Map<String, dynamic> json) {
    return PlatformTask(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      resourceId: json['resource_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      assignedTo: json['assigned_to'] as String?,
      status: json['status'] as String? ?? 'assigned',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class PlatformFile {
  final String id;
  final String channelId;
  final String fileName;
  final String fileUrl;
  final String? mimeType;
  final DateTime createdAt;

  PlatformFile({
    required this.id,
    required this.channelId,
    required this.fileName,
    required this.fileUrl,
    this.mimeType,
    required this.createdAt,
  });

  factory PlatformFile.fromJson(Map<String, dynamic> json) {
    return PlatformFile(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      fileName: json['file_name'] as String,
      fileUrl: json['file_url'] as String,
      mimeType: json['mime_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Résumé d'un canal pour la liste « Discussions » du Hub.
class HubDiscussion {
  final String channelId;
  final String? resourceId;
  final String channelType;
  final String name;
  final String type;
  final DateTime? lastReadAt;
  final String? lastBody;
  final DateTime? lastAt;
  final String? lastSenderId;
  final int unreadCount;

  HubDiscussion({
    required this.channelId,
    this.resourceId,
    required this.channelType,
    required this.name,
    required this.type,
    this.lastReadAt,
    this.lastBody,
    this.lastAt,
    this.lastSenderId,
    this.unreadCount = 0,
  });

  bool get hasUnread => unreadCount > 0;

  factory HubDiscussion.fromJson(Map<String, dynamic> json) {
    return HubDiscussion(
      channelId: json['channel_id'] as String,
      resourceId: json['resource_id'] as String?,
      channelType: json['channel_type'] as String? ?? 'discussion',
      name: json['name'] as String? ?? 'Discussion',
      type: json['type'] as String? ?? 'discussion',
      lastReadAt: json['last_read_at'] != null
          ? DateTime.tryParse(json['last_read_at'] as String)
          : null,
      lastBody: json['last_body'] as String?,
      lastAt: json['last_at'] != null
          ? DateTime.tryParse(json['last_at'] as String)
          : null,
      lastSenderId: json['last_sender_id'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}
