import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/driver_home_palette.dart';

/// Sens de l'annonce d'échange.
enum ServiceExchangePostKind {
  request('request'),
  canReplace('can_replace');

  final String dbValue;
  const ServiceExchangePostKind(this.dbValue);

  static ServiceExchangePostKind fromDb(String? value) =>
      ServiceExchangePostKind.values.firstWhere(
        (k) => k.dbValue == value,
        orElse: () => ServiceExchangePostKind.request,
      );

  String get label => switch (this) {
        ServiceExchangePostKind.request => 'Je cherche un échange',
        ServiceExchangePostKind.canReplace => 'Je peux remplacer',
      };

  String get emoji => switch (this) {
        ServiceExchangePostKind.request => '🔄',
        ServiceExchangePostKind.canReplace => '🙋',
      };
}

/// Type de service concerné par l'annonce.
enum ServiceExchangeServiceType {
  bus('BUS'),
  tram('TRAM'),
  controle('CONTROLE'),
  intervention('INTERVENTION'),
  umtc('UMTC');

  final String dbValue;
  const ServiceExchangeServiceType(this.dbValue);

  static ServiceExchangeServiceType fromDb(String? value) =>
      ServiceExchangeServiceType.values.firstWhere(
        (t) => t.dbValue == value,
        orElse: () => ServiceExchangeServiceType.bus,
      );

  String get label => switch (this) {
        ServiceExchangeServiceType.bus => 'BUS',
        ServiceExchangeServiceType.tram => 'TRAM',
        ServiceExchangeServiceType.controle => 'Contrôle',
        ServiceExchangeServiceType.intervention => 'Intervention',
        ServiceExchangeServiceType.umtc => 'UMTC',
      };

  String get emoji => switch (this) {
        ServiceExchangeServiceType.bus => '🚌',
        ServiceExchangeServiceType.tram => '🚋',
        ServiceExchangeServiceType.controle => '🎫',
        ServiceExchangeServiceType.intervention => '🦺',
        ServiceExchangeServiceType.umtc => '👮',
      };

  Color get color => switch (this) {
        ServiceExchangeServiceType.bus => DriverHomePalette.primary,
        ServiceExchangeServiceType.tram => DriverHomePalette.blue,
        ServiceExchangeServiceType.controle => DriverHomePalette.warning,
        ServiceExchangeServiceType.intervention => DriverHomePalette.danger,
        ServiceExchangeServiceType.umtc => DriverHomePalette.purple,
      };

  /// Habilitation déduite (miroir SQL `se_deduce_required_habilitation`).
  String get requiredHabilitation => switch (this) {
        ServiceExchangeServiceType.bus => 'conduite',
        ServiceExchangeServiceType.tram => 'conduite',
        ServiceExchangeServiceType.controle => 'controle',
        ServiceExchangeServiceType.intervention => 'intervention',
        ServiceExchangeServiceType.umtc => 'umtc',
      };
}

/// Statut d'une annonce.
enum ServiceExchangeStatus {
  active('active'),
  inDiscussion('in_discussion'),
  agreed('agreed'),
  cancelled('cancelled'),
  expired('expired');

  final String dbValue;
  const ServiceExchangeStatus(this.dbValue);

  static ServiceExchangeStatus fromDb(String? value) =>
      ServiceExchangeStatus.values.firstWhere(
        (s) => s.dbValue == value,
        orElse: () => ServiceExchangeStatus.active,
      );
}

/// Réaction légère sur une annonce.
enum ServiceExchangeReaction {
  like('like'),
  seen('seen');

  final String dbValue;
  const ServiceExchangeReaction(this.dbValue);

  static ServiceExchangeReaction? fromDb(String? value) {
    if (value == null) return null;
    for (final r in ServiceExchangeReaction.values) {
      if (r.dbValue == value) return r;
    }
    return null;
  }

  String get emoji => switch (this) {
        ServiceExchangeReaction.like => '👍',
        ServiceExchangeReaction.seen => '👀',
      };
}

/// Annonce d'échange de service (table `service_exchange_posts`).
class ServiceExchangePost {
  final String id;
  final String authorId;
  final String networkCode;
  final String? depotId;
  final String? depotName;
  final ServiceExchangePostKind postKind;
  final ServiceExchangeServiceType serviceType;
  final String requiredHabilitation;
  final DateTime serviceDate;
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String? serviceNumber;
  final String? lineCode;
  final String? vehicleCode;
  final String? serviceLabel;
  final String? message;
  final String title;
  final ServiceExchangeStatus status;
  final String visibility;
  final DateTime? expiresAt;
  final bool isUrgent;
  final int contactCount;
  final int viewCount;
  final DateTime? resolvedAt;
  final String? resourceId;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Flags propres au viewer (renvoyés par les RPC).
  final bool isMine;
  final bool isFavorited;
  final ServiceExchangeReaction? myReaction;
  final int reactionLikes;
  final int reactionSeen;
  final bool isNew;
  final bool isExpiringSoon;
  final bool isResolved;
  final bool canRelance;

  const ServiceExchangePost({
    required this.id,
    required this.authorId,
    required this.networkCode,
    this.depotId,
    this.depotName,
    required this.postKind,
    required this.serviceType,
    required this.requiredHabilitation,
    required this.serviceDate,
    required this.startTime,
    required this.endTime,
    this.serviceNumber,
    this.lineCode,
    this.vehicleCode,
    this.serviceLabel,
    this.message,
    required this.title,
    required this.status,
    this.visibility = 'public',
    this.expiresAt,
    this.isUrgent = false,
    this.contactCount = 0,
    this.viewCount = 0,
    this.resolvedAt,
    this.resourceId,
    this.authorDisplayName,
    this.authorAvatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isMine = false,
    this.isFavorited = false,
    this.myReaction,
    this.reactionLikes = 0,
    this.reactionSeen = 0,
    this.isNew = false,
    this.isExpiringSoon = false,
    this.isResolved = false,
    this.canRelance = false,
  });

  factory ServiceExchangePost.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String key) =>
        DateTime.tryParse(json[key]?.toString() ?? '')?.toLocal() ??
        DateTime.now();
    DateTime? parseNullableDate(String key) => json[key] != null
        ? DateTime.tryParse(json[key].toString())?.toLocal()
        : null;

    return ServiceExchangePost(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      networkCode: json['network_code'] as String? ?? 'naolib',
      depotId: json['depot_id'] as String?,
      depotName: json['depot_name'] as String?,
      postKind: ServiceExchangePostKind.fromDb(json['post_kind'] as String?),
      serviceType:
          ServiceExchangeServiceType.fromDb(json['service_type'] as String?),
      requiredHabilitation:
          json['required_habilitation'] as String? ?? 'conduite',
      serviceDate: parseDate('service_date'),
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      serviceNumber: json['service_number'] as String?,
      lineCode: json['line_code'] as String?,
      vehicleCode: json['vehicle_code'] as String?,
      serviceLabel: json['service_label'] as String?,
      message: json['message'] as String?,
      title: json['title'] as String? ?? 'Échange de service',
      status: ServiceExchangeStatus.fromDb(json['status'] as String?),
      visibility: json['visibility'] as String? ?? 'public',
      expiresAt: parseNullableDate('expires_at'),
      isUrgent: json['is_urgent'] as bool? ?? false,
      contactCount: (json['contact_count'] as num?)?.toInt() ?? 0,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      resolvedAt: parseNullableDate('resolved_at'),
      resourceId: json['resource_id'] as String?,
      authorDisplayName: json['author_display_name'] as String?,
      authorAvatarUrl: json['author_avatar_url'] as String?,
      createdAt: parseDate('created_at'),
      updatedAt: parseDate('updated_at'),
      isMine: json['is_mine'] as bool? ?? false,
      isFavorited: json['is_favorited'] as bool? ?? false,
      myReaction: ServiceExchangeReaction.fromDb(json['my_reaction'] as String?),
      reactionLikes: (json['reaction_likes'] as num?)?.toInt() ?? 0,
      reactionSeen: (json['reaction_seen'] as num?)?.toInt() ?? 0,
      isNew: json['is_new'] as bool? ?? false,
      isExpiringSoon: json['is_expiring_soon'] as bool? ?? false,
      isResolved: json['is_resolved'] as bool? ?? false,
      canRelance: json['can_relance'] as bool? ?? false,
    );
  }

  bool get canExpressInterest =>
      !isMine &&
      (status == ServiceExchangeStatus.active ||
          status == ServiceExchangeStatus.inDiscussion);

  /// Titre affiché, avec préfixe urgent.
  String get displayTitle => isUrgent ? '⚡ $title' : title;

  String get authorLabel {
    final name = authorDisplayName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'Agent du réseau';
  }

  String get authorInitials {
    final parts = authorLabel
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String get periodLabel {
    final start = startTime.replaceFirst(':', 'h');
    final end = endTime.replaceFirst(':', 'h');
    return '$start → $end';
  }

  String get serviceDateLabel {
    final raw = DateFormat('EEEE d MMMM', 'fr_FR').format(serviceDate);
    return raw[0].toUpperCase() + raw.substring(1);
  }

  /// Référence service : « Service 214 · Ligne 1 · Véhicule 31 » (parties présentes).
  String? get serviceRefLabel {
    final parts = <String>[];
    if (serviceNumber != null && serviceNumber!.trim().isNotEmpty) {
      parts.add('Service ${serviceNumber!.trim()}');
    }
    if (lineCode != null && lineCode!.trim().isNotEmpty) {
      parts.add('Ligne ${lineCode!.trim()}');
    }
    if (vehicleCode != null && vehicleCode!.trim().isNotEmpty) {
      parts.add('Véhicule ${vehicleCode!.trim()}');
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String get statsLabel {
    final views = '👀 $viewCount';
    final contacts = contactCount <= 1
        ? '💬 $contactCount proposition'
        : '💬 $contactCount propositions';
    return '$views · $contacts';
  }

  String get statusLabel => switch (status) {
        ServiceExchangeStatus.active => 'Disponible',
        ServiceExchangeStatus.inDiscussion =>
          'En discussion${contactCount > 0 ? ' ($contactCount)' : ''}',
        ServiceExchangeStatus.agreed => 'Échange trouvé',
        ServiceExchangeStatus.cancelled => 'Annulée',
        ServiceExchangeStatus.expired => 'Expirée',
      };

  Color get statusColor => switch (status) {
        ServiceExchangeStatus.active => DriverHomePalette.primary,
        ServiceExchangeStatus.inDiscussion => DriverHomePalette.warning,
        ServiceExchangeStatus.agreed => DriverHomePalette.primary,
        ServiceExchangeStatus.cancelled => DriverHomePalette.textSecondary,
        ServiceExchangeStatus.expired => DriverHomePalette.textSecondary,
      };

  IconData get statusIcon => switch (status) {
        ServiceExchangeStatus.active => LucideIcons.circle,
        ServiceExchangeStatus.inDiscussion => LucideIcons.messagesSquare,
        ServiceExchangeStatus.agreed => LucideIcons.circleCheck,
        ServiceExchangeStatus.cancelled => LucideIcons.circleX,
        ServiceExchangeStatus.expired => LucideIcons.clock,
      };

  String get relativePublishedLabel {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Publié à l\'instant';
    if (diff.inMinutes < 60) return 'Publié il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Publié il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Publié il y a ${diff.inDays} j';
    return 'Publié le ${DateFormat('d MMM', 'fr_FR').format(createdAt)}';
  }
}
