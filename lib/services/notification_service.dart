import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/supabase_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

/// 通知服務，處理推送通知相關邏輯
class NotificationService {
  // 單例模式
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // 服務實例
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late FlutterLocalNotificationsPlugin _localNotifications;
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseService _supabaseService = SupabaseService();
  final NavigationService _navigationService = NavigationService();

  // 註冊全局導航上下文
  GlobalKey<NavigatorState>? _navigatorKey;

  // 定義通知頻道
  static const AndroidNotificationChannel _reservationChannel =
      AndroidNotificationChannel(
        'reservation_channel',
        '預約提醒',
        description: '用於顯示晚餐預約的提醒通知',
        importance: Importance.max,
      );

  // 初始化通知服務
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    try {
      // 檢查 Firebase 是否已初始化
      if (Firebase.apps.isEmpty) {
        debugPrint('NotificationService: Firebase 尚未初始化，正在初始化...');
        await Firebase.initializeApp();
      } else {
        debugPrint('NotificationService: Firebase 已經初始化');
      }

      // 請求通知權限
      await _requestPermission();

      // 初始化本地通知
      await _initNotifications();

      // 清除所有現有通知
      await clearAllNotifications();

      // 設置 token 刷新監聽
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token 已更新: $newToken');
        saveTokenToSupabase();
      });

      // 設置前台通知選項
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      // 處理後台消息
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // 處理前台消息
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 處理通知點擊
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);

      // 檢查當前用戶，如果已登入則保存 token
      final currentUser = _supabaseService.auth.currentUser;
      if (currentUser != null) {
        await saveTokenToSupabase();
      }
    } catch (e) {
      debugPrint('通知服務初始化錯誤: $e');
      // 記錄詳細堆疊跟踪
      debugPrintStack(label: '通知服務初始化錯誤堆疊');
    }
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
  Future<void> _initNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();
    await _localNotifications.initialize(
      InitializationSettings(
        android: AndroidInitializationSettings('@drawable/notification_icon'),
      ),
    );

    // 創建通知頻道
    await _createNotificationChannels();
  }

  // 創建所有需要的通知頻道
  Future<void> _createNotificationChannels() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_reservationChannel);
        debugPrint('通知頻道創建成功: ${_reservationChannel.id}');
      } else {
        debugPrint('無法獲取Android通知插件實例');
      }
    } catch (e) {
      debugPrint('創建通知頻道時出錯: $e');
    }
  }

  // 保存 FCM token 到 Supabase
  Future<bool> saveTokenToSupabase() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token == null) {
        debugPrint('無法獲取FCM Token');
        return false;
      }

      // 獲取當前用戶
      final currentUser = _supabaseService.auth.currentUser;
      if (currentUser == null) {
        debugPrint('用戶未登入，無法保存FCM Token');
        return false;
      }

      // 查詢用戶是否已有令牌記錄
      final existingTokens = await _supabaseService.client
          .from('user_device_tokens')
          .select()
          .eq('user_id', currentUser.id);

      if (existingTokens != null && existingTokens.isNotEmpty) {
        // 更新現有令牌
        final existingTokenId = existingTokens[0]['id'];
        await _supabaseService.client
            .from('user_device_tokens')
            .update({
              'token': token,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingTokenId);
      } else {
        // 創建新令牌記錄
        await _supabaseService.client.from('user_device_tokens').insert({
          'user_id': currentUser.id,
          'token': token,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      debugPrint('FCM Token已成功保存到Supabase');
      return true;
    } catch (e) {
      debugPrint('保存FCM Token發生異常: $e');
      return false;
    }
  }

  // 處理點擊通知
  void _handleNotificationClick(RemoteMessage message) {
    debugPrint('點擊了通知: ${message.data}');

    // 檢查是否是確認出席通知
    if (message.data['type'] == 'attendance_confirmation' ||
        message.data['status'] == 'waiting_restaurant') {
      // 導航到餐廳選擇頁面
      _navigateToRestaurantSelection();
    }
  }

  // 處理點擊本地通知
  void _handleLocalNotificationClick(String? payload) {
    if (payload != null) {
      debugPrint('點擊了本地通知: $payload');

      // 解析 payload
      if (payload.contains('attendance_confirmation') ||
          payload.contains('waiting_restaurant')) {
        // 導航到餐廳選擇頁面
        _navigateToRestaurantSelection();
      }
    }
  }

  // 導航到餐廳選擇頁面
  void _navigateToRestaurantSelection() {
    if (_navigatorKey?.currentState != null) {
      _navigationService.navigateToRestaurantSelection(
        _navigatorKey!.currentContext!,
      );
    }
  }

  // 處理前台消息
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('收到前台消息: ${message.notification?.title}');

    // 顯示本地通知
    if (message.notification != null) {
      // 創建一個新的消息數據，添加標記以防止後台處理程序重複顯示
      final Map<String, dynamic> modifiedData = Map<String, dynamic>.from(
        message.data,
      );
      modifiedData['showNotification'] = 'false';

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
            icon: '@drawable/notification_icon',
            // 確保小圖示可見
            color: const Color(0xFFB33D1C),
          ),
        ),
        payload: modifiedData.toString(),
      );
    }
  }

  // 清除所有通知
  Future<void> clearAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('所有本地通知已清除');

      // 清除 Firebase 的通知 (僅限 Android)
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
      debugPrint('Firebase 通知設置已更新');
    } catch (e) {
      debugPrint('清除通知錯誤: $e');
    }
  }

  // 排程本地通知
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String channelId = 'tuckin_notification_channel',
    String channelName = 'TuckIn 通知',
    String channelDescription = '用於接收聚餐相關通知',
  }) async {
    try {
      debugPrint('開始排程通知，ID: $id，時間: ${scheduledDate.toString()}');

      // 確保通知頻道已創建
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        debugPrint('已為排程通知創建頻道: ${channel.id}');
      } else {
        debugPrint('無法獲取Android通知插件實例');
      }

      final androidPlatformChannelSpecifics = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/notification_icon',
        showWhen: true,
        color: const Color(0xFFB33D1C),
      );

      final platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(
        scheduledDate,
        tz.local,
      );

      debugPrint('排程通知時間（本地）: ${scheduledDate.toString()}');
      debugPrint('排程通知時間（時區轉換後）: ${tzScheduledDate.toString()}');

      // 檢查設備 API 版本並嘗試排程
      try {
        // 嘗試使用精確鬧鐘
        await _localNotifications.zonedSchedule(
          id,
          title,
          body,
          tzScheduledDate,
          platformChannelSpecifics,
          androidAllowWhileIdle: true,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );

        debugPrint('成功排程精確通知，ID: $id，時間: $scheduledDate');
        debugPrint('通知詳情 - 標題: $title, 內容: $body');

        // 不再同時使用備用通知，僅記錄成功
        debugPrint('首選通知機制成功，不使用備用通知');
      } catch (e) {
        debugPrint('精確排程通知失敗: $e，嘗試使用備用通知機制');

        // 只有在精確通知失敗時，才使用備用通知機制
        if (scheduledDate.isAfter(DateTime.now())) {
          _scheduleBackupNotification(
            id: id, // 使用相同ID，因為主通知沒有成功
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            platformChannelSpecifics: platformChannelSpecifics,
            payload: payload,
          );
        } else {
          // 如果時間已經過了，則立即顯示通知
          try {
            await _localNotifications.show(
              id,
              title,
              body,
              platformChannelSpecifics,
              payload: payload,
            );
            debugPrint('已發送即時通知，因為排程時間已過');
          } catch (showError) {
            debugPrint('發送即時通知失敗: $showError');
          }
        }
      }
    } catch (e) {
      debugPrint('排程通知錯誤: $e');
    }
  }

  // 使用延遲而非精確排程的備用通知方法
  void _scheduleBackupNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required NotificationDetails platformChannelSpecifics,
    String? payload,
  }) {
    if (scheduledDate.isAfter(DateTime.now())) {
      final difference = scheduledDate.difference(DateTime.now());
      debugPrint('設置備用延遲通知，將在 ${difference.inMinutes} 分鐘後顯示（非精確排程）');

      // 使用延遲而非精確排程
      Future.delayed(difference, () async {
        try {
          await _localNotifications.show(
            id,
            title,
            body,
            platformChannelSpecifics,
            payload: payload,
          );
          debugPrint('備用延遲通知已觸發，ID: $id');
        } catch (e) {
          debugPrint('備用延遲通知失敗: $e');
        }
      });
    } else {
      debugPrint('排程時間已過，不設置備用延遲通知');
    }
  }

  // 取消特定通知
  Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id);
      debugPrint('已取消通知，ID: $id');
    } catch (e) {
      debugPrint('取消通知錯誤: $e');
    }
  }

  Future<void> scheduleReservationReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      debugPrint('開始排程預約提醒通知，ID: $id，時間: ${scheduledTime.toString()}');

      // 確保通知頻道已創建
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'reservation_channel',
        '預約提醒',
        description: '用於顯示晚餐預約的提醒通知',
        importance: Importance.max,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        debugPrint('已為預約提醒通知創建頻道: ${channel.id}');
      } else {
        debugPrint('無法獲取Android通知插件實例');
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'reservation_channel',
            '預約提醒',
            channelDescription: '用於顯示晚餐預約的提醒通知',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            icon: '@drawable/notification_icon',
            color: Color(0xFFB33D1C),
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );

      debugPrint('排程預約提醒時間（本地）: ${scheduledTime.toString()}');
      debugPrint('排程預約提醒時間（時區轉換後）: ${tzScheduledDate.toString()}');

      try {
        // 嘗試使用精確鬧鐘
        await _localNotifications.zonedSchedule(
          id,
          title,
          body,
          tzScheduledDate,
          platformChannelSpecifics,
          androidAllowWhileIdle: true,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );

        debugPrint('成功排程精確預約提醒通知，ID: $id，時間: $scheduledTime');
        debugPrint('通知詳情 - 標題: $title, 內容: $body');

        // 不再同時使用備用通知，僅記錄成功
        debugPrint('首選通知機制成功，不使用備用通知');
      } catch (e) {
        debugPrint('精確排程預約提醒通知失敗: $e，嘗試使用備用通知機制');

        // 只有在精確通知失敗時，才使用備用通知機制
        if (scheduledTime.isAfter(DateTime.now())) {
          _scheduleBackupNotification(
            id: id, // 使用相同ID，因為主通知沒有成功
            title: title,
            body: body,
            scheduledDate: scheduledTime,
            platformChannelSpecifics: platformChannelSpecifics,
          );
        } else {
          // 如果時間已經過了，則立即顯示通知
          try {
            await _localNotifications.show(
              id,
              title,
              body,
              platformChannelSpecifics,
            );
            debugPrint('已發送即時預約提醒通知，因為排程時間已過');
          } catch (showError) {
            debugPrint('發送即時預約提醒通知失敗: $showError');
          }
        }
      }
    } catch (e) {
      debugPrint('排程預約提醒通知整體錯誤: $e');
    }
  }
}

// 處理後台消息
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('收到後台消息: ${message.notification?.title}');

  // 只有當應用在後台時才顯示通知
  // 檢查消息數據中是否有特殊標記，避免重複通知
  if (message.notification != null &&
      message.data['showNotification'] != 'false') {
    // 為後台通知配置小圖標
    // 創建通知頻道
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'tuckin_notification_channel',
      'TuckIn 通知',
      description: '用於接收聚餐相關通知',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // 如果消息包含通知，則顯示本地通知
    await flutterLocalNotificationsPlugin.show(
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
          icon: '@drawable/notification_icon',
          color: const Color(0xFFB33D1C),
        ),
      ),
      payload: message.data.toString(),
    );
  }
}
