import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb) return;

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings, 
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings, // <-- O VS Code quer exatamente a palavra 'settings'
    );
  }

  static Future<void> showNotification({required String title, required String body}) async {
    if (kIsWeb) {
      debugPrint('🔔 NOTIFICAÇÃO WEB: $title - $body');
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_validades_id',
      'Alertas de Validade',
      channelDescription: 'Avisa quando os produtos estão prestes a expirar',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // CORREÇÃO: O pacote agora exige que tudo tenha o nome explícito (id, title, body, etc)
    await _notificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}