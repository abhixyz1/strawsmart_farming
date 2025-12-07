import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background message handler untuk Firebase Cloud Messaging
/// Handler ini dijalankan bahkan saat app tidak aktif (terminated/killed)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('DEBUG FCM: Handling background message: ${message.messageId}');
  print('DEBUG FCM: Title: ${message.notification?.title}');
  print('DEBUG FCM: Body: ${message.notification?.body}');
  print('DEBUG FCM: Data: ${message.data}');
  
  // Show local notification
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // Android initialization
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings),
  );
  
  // Show notification
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'greenhouse_channel',
    'Greenhouse Notifications',
    channelDescription: 'Notifikasi untuk monitoring greenhouse',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
    enableVibration: true,
    playSound: true,
  );
  
  const NotificationDetails details = NotificationDetails(android: androidDetails);
  
  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'Notifikasi',
    message.notification?.body ?? '',
    details,
  );
}

/// Setup Firebase Cloud Messaging
/// Dipanggil saat aplikasi start untuk setup FCM
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  /// Initialize FCM dan request permission
  Future<void> initialize() async {
    print('DEBUG FCM: Initializing Firebase Cloud Messaging...');
    
    // Request permission (iOS & Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    print('DEBUG FCM: Permission status: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Get FCM token
      final token = await _messaging.getToken();
      print('DEBUG FCM: Device token: $token');
      
      // TODO: Save token to RTDB untuk digunakan backend mengirim notifikasi
      // await _saveTokenToDatabase(token);
      
      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        print('DEBUG FCM: Token refreshed: $newToken');
        // TODO: Update token di RTDB
        // _saveTokenToDatabase(newToken);
      });
      
      // Setup foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('DEBUG FCM: Received foreground message: ${message.messageId}');
        print('DEBUG FCM: Title: ${message.notification?.title}');
        print('DEBUG FCM: Body: ${message.notification?.body}');
        
        // Show notification saat app foreground
        _showForegroundNotification(message);
      });
      
      // Setup message click handler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('DEBUG FCM: Message clicked: ${message.messageId}');
        // TODO: Navigate to appropriate screen based on message data
        _handleMessageClick(message);
      });
      
      // Check if app was opened from terminated state by notification click
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        print('DEBUG FCM: App opened from notification: ${initialMessage.messageId}');
        _handleMessageClick(initialMessage);
      }
    } else {
      print('DEBUG FCM: Permission denied');
    }
  }
  
  /// Show notification saat app di foreground
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'greenhouse_channel',
      'Greenhouse Notifications',
      channelDescription: 'Notifikasi untuk monitoring greenhouse',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
    );
    
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'Notifikasi',
      message.notification?.body ?? '',
      details,
    );
  }
  
  /// Handle notification click
  void _handleMessageClick(RemoteMessage message) {
    print('DEBUG FCM: Handling message click');
    print('DEBUG FCM: Data: ${message.data}');
    
    // TODO: Navigate based on notification type
    final notificationType = message.data['type'];
    final deviceId = message.data['deviceId'];
    
    print('DEBUG FCM: Type: $notificationType, DeviceId: $deviceId');
    
    // Navigation logic akan ditambahkan nanti
    // Contoh: context.go('/dashboard?deviceId=$deviceId');
  }
  
  /// Save FCM token to RTDB (untuk backend)
  Future<void> _saveTokenToDatabase(String token) async {
    // TODO: Implement save token to RTDB
    // Format: users/{userId}/fcmTokens/{deviceId}: token
    print('DEBUG FCM: Saving token to database: $token');
  }
}
