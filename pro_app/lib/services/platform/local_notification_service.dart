import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared/shared.dart';

/// Relais OS du flux `user_notifications` : affiche une bannière système
/// lorsqu'une notification temps réel arrive pendant que l'app tourne.
///
/// Ne dépend d'aucun backend push (FCM/APNs). Le push « app tuée » reste à
/// brancher séparément ; ici on surface ce que [HubEngine] capte déjà en
/// realtime, au premier plan comme en arrière-plan tant que le socket vit.
class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Invoqué quand l'utilisateur tape une bannière. Le payload transporte
  /// l'identifiant de la notification d'origine (`user_notifications.id`).
  void Function(String? payload)? onSelect;

  /// Canal prioritaire : alertes / incidents.
  static const AndroidNotificationChannel _alertsChannel =
      AndroidNotificationChannel(
    'aule_pro_alerts',
    'Alertes & incidents',
    description: 'Alertes prioritaires (incidents, sécurité).',
    importance: Importance.high,
  );

  /// Canal courant : messages, mentions, activité.
  static const AndroidNotificationChannel _generalChannel =
      AndroidNotificationChannel(
    'aule_pro_general',
    'Messages & activité',
    description: "Messages, mentions et activité de l'espace conducteur.",
    importance: Importance.defaultImportance,
  );

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // On demande les permissions explicitement plus tard (requestPermissions),
    // pas au moment de l'init.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (response) =>
          onSelect?.call(response.payload),
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_alertsChannel);
    await androidImpl?.createNotificationChannel(_generalChannel);

    _initialized = true;
  }

  /// Demande l'autorisation système d'afficher des notifications
  /// (Android 13+ via POST_NOTIFICATIONS, iOS via UNUserNotificationCenter).
  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Affiche une bannière pour [notification]. Le routage du canal dépend de la
  /// catégorie et de la priorité.
  Future<void> show(PlatformNotification notification) async {
    if (!_initialized) await init();

    final isAlert = notification.category == NotificationCategory.alert ||
        notification.priority == 'high' ||
        notification.priority == 'critical';
    final channel = isAlert ? _alertsChannel : _generalChannel;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: isAlert ? Priority.high : Priority.defaultPriority,
        ticker: notification.title,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.show(
        notification.id.hashCode,
        notification.title,
        notification.body,
        details,
        payload: notification.id,
      );
    } catch (e) {
      debugPrint('Aule: local notification show failed ($e)');
    }
  }
}
