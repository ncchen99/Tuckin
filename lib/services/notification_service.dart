import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/supabase_service.dart';

/// 通知服務，處理推送通知相關邏輯
class NotificationService {
  // 單例模式
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // 服務實例
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseService _supabaseService = SupabaseService();

  // 註冊全局導航上下文
  GlobalKey<NavigatorState>? _navigatorKey;

  // 初始化通知服務
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    // 初始化 Firebase
    await Firebase.initializeApp();

    // 請求通知權限
    await _requestPermission();

    // 初始化本地通知
    await _initializeLocalNotifications();

    // 處理後台消息
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 處理前台消息
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 處理通知點擊
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);

    // 保存 FCM token 到 Supabase
    await _saveFcmToken();
  }

  // 請求通知權限
  Future<void> _requestPermission() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // 初始化本地通知
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleLocalNotificationClick(response.payload);
      },
    );

    // 創建通知頻道
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'tuckin_notification_channel',
      'TuckIn 通知',
      description: '用於接收聚餐相關通知',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // 保存 FCM token 到 Supabase
  Future<void> _saveFcmToken() async {
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');

      // 獲取當前用戶
      final currentUser = _supabaseService.auth.currentUser;
      if (currentUser != null) {
        // 保存 token 到 Supabase（需要先在 Supabase 中創建表）
        try {
          await _supabaseService.client.from('user_device_tokens').upsert({
            'user_id': currentUser.id,
            'token': token,
            'updated_at': DateTime.now().toIso8601String(),
          });

          debugPrint('FCM Token 已保存到 Supabase');
        } catch (e) {
          debugPrint('保存 FCM Token 錯誤: $e');
        }
      }
    }
  }

  // 處理點擊通知
  void _handleNotificationClick(RemoteMessage message) {
    debugPrint('點擊了通知: ${message.data}');

    // 檢查是否是確認出席通知
    if (message.data['type'] == 'attendance_confirmation' ||
        message.data['status'] == 'waiting_confirmation') {
      // 導航到確認出席頁面
      _navigateToAttendanceConfirmation();
    }
  }

  // 處理點擊本地通知
  void _handleLocalNotificationClick(String? payload) {
    if (payload != null) {
      debugPrint('點擊了本地通知: $payload');

      // 解析 payload
      if (payload.contains('attendance_confirmation') ||
          payload.contains('waiting_confirmation')) {
        // 導航到確認出席頁面
        _navigateToAttendanceConfirmation();
      }
    }
  }

  // 導航到確認出席頁面
  void _navigateToAttendanceConfirmation() {
    if (_navigatorKey?.currentState != null) {
      _navigatorKey!.currentState!.pushNamed('/attendance_confirmation');
    }
  }

  // 處理前台消息
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('收到前台消息: ${message.notification?.title}');

    // 顯示本地通知
    if (message.notification != null) {
      await _localNotifications.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'tuckin_notification_channel',
            'TuckIn 通知',
            channelDescription: '用於接收聚餐相關通知',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  // 公開方法，可在用戶登入後調用
  Future<bool> saveTokenToSupabase() async {
    final token = await _firebaseMessaging.getToken();
    if (token == null) {
      debugPrint('無法獲取FCM Token');
      return false;
    }

    debugPrint('FCM Token: $token');

    // 獲取當前用戶
    final currentUser = _supabaseService.auth.currentUser;
    if (currentUser == null) {
      debugPrint('用戶未登入，無法保存FCM Token');
      return false;
    }

    // 保存token到Supabase
    try {
      final result = await _supabaseService.client
          .from('user_device_tokens')
          .upsert({
            'user_id': currentUser.id,
            'token': token,
            'updated_at': DateTime.now().toIso8601String(),
          });

      debugPrint('FCM Token保存結果: ${result.error == null ? "成功" : "失敗"}');
      if (result.error != null) {
        debugPrint('保存FCM Token錯誤: ${result.error!.message}');
        return false;
      }

      debugPrint('FCM Token已成功保存到Supabase');
      return true;
    } catch (e) {
      debugPrint('保存FCM Token發生異常: $e');
      return false;
    }
  }

  Future<void> debugTokenStatus() async {
    final token = await _firebaseMessaging.getToken();
    final currentUser = _supabaseService.auth.currentUser;

    print('====== FCM TOKEN DEBUG ======');
    print('FCM Token: ${token ?? "NULL"}');
    print('當前用戶: ${currentUser?.id ?? "未登入"}');

    if (token != null && currentUser != null) {
      print('正在檢查數據庫中是否存在此token...');
      try {
        final result = await _supabaseService.client
            .from('user_device_tokens')
            .select()
            .eq('user_id', currentUser.id)
            .eq('token', token);

        print('查詢結果: ${result.length ?? 0}條記錄');
        if (result.isNotEmpty) {
          print('記錄詳情: $result');
        }
      } catch (e) {
        print('查詢錯誤: $e');
      }
    }
    print('===========================');
  }
}

// 處理後台消息
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('收到後台消息: ${message.notification?.title}');
}
