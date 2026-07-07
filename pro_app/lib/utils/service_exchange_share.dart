import 'package:share_plus/share_plus.dart';

import '../models/driver/service_exchange_post.dart';

/// Partage d'une annonce d'échange vers les apps externes (WhatsApp, SMS…).
abstract final class ServiceExchangeShare {
  static Future<void> share(ServiceExchangePost post) async {
    final buffer = StringBuffer()
      ..writeln('${post.postKind.emoji} ${post.title}')
      ..writeln('${post.serviceType.emoji} ${post.serviceType.label}')
      ..writeln('📅 ${post.serviceDateLabel} · ${post.periodLabel}');
    final ref = post.serviceRefLabel;
    if (ref != null) buffer.writeln('🚍 $ref');
    if (post.depotName != null) buffer.writeln('📍 ${post.depotName}');
    final message = post.message?.trim();
    if (message != null && message.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(message);
    }
    buffer
      ..writeln()
      ..writeln('Partagé via Aule Pro');

    await Share.share(buffer.toString(), subject: post.title);
  }
}
