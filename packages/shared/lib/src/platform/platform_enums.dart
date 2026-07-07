/// Enums techniques stables — le reste est TEXT/JSON côté serveur.
enum PlatformChannelType {
  direct,
  discussion,
  group,
  team,
  mission,
  support,
  network,
  unknown;

  static PlatformChannelType fromDb(String? value) {
    switch (value) {
      case 'direct':
        return PlatformChannelType.direct;
      case 'discussion':
        return PlatformChannelType.discussion;
      case 'group':
        return PlatformChannelType.group;
      case 'team':
        return PlatformChannelType.team;
      case 'mission':
        return PlatformChannelType.mission;
      case 'support':
        return PlatformChannelType.support;
      case 'network':
        return PlatformChannelType.network;
      default:
        return PlatformChannelType.unknown;
    }
  }

  String get dbValue => name == 'unknown' ? 'discussion' : name;
}

enum PlatformMessageType {
  text,
  location,
  document,
  task,
  entity,
  image,
  unknown;

  static PlatformMessageType fromDb(String? value) {
    switch (value) {
      case 'text':
        return PlatformMessageType.text;
      case 'location':
        return PlatformMessageType.location;
      case 'document':
        return PlatformMessageType.document;
      case 'task':
        return PlatformMessageType.task;
      case 'entity':
        return PlatformMessageType.entity;
      case 'image':
        return PlatformMessageType.image;
      default:
        return PlatformMessageType.unknown;
    }
  }

  String get dbValue => name == 'unknown' ? 'text' : name;
}

enum NotificationCategory {
  message,
  activity,
  alert,
  unknown;

  static NotificationCategory fromDb(String? value) {
    switch (value) {
      case 'message':
        return NotificationCategory.message;
      case 'activity':
        return NotificationCategory.activity;
      case 'alert':
        return NotificationCategory.alert;
      default:
        return NotificationCategory.unknown;
    }
  }

  String get dbValue {
    switch (this) {
      case NotificationCategory.message:
        return 'message';
      case NotificationCategory.activity:
        return 'activity';
      case NotificationCategory.alert:
        return 'alert';
      case NotificationCategory.unknown:
        return 'activity';
    }
  }
}
