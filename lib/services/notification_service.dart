import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tuckin/services/supabase_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:tuckin/services/time_service.dart';

/// 通知服務，處理推送通知相關邏輯
class NotificationService {
  // 單例模式
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // 服務實例
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late FlutterLocalNotificationsPlugin _localNotifications;
  final SupabaseService _supabaseService = SupabaseService();
  final NavigationService _navigationService = NavigationService();

  // 註冊全局導航上下文
  GlobalKey<NavigatorState>? _navigatorKey;

  // 追蹤當前正在查看的聊天室 ID（用於抑制該聊天室的通知）
  String? _activeChatRoomId;

  // 儲存待處理的聊天通知導航（用於 APP 冷啟動時）
  String? _pendingChatNavigation;

  /// 設置當前正在查看的聊天室 ID
  /// 同時在 iOS 上動態調整前台通知設置，防止在聊天室內收到通知
  Future<void> setActiveChatRoom(String? diningEventId) async {
    _activeChatRoomId = diningEventId;
    debugPrint('NotificationService: 當前聊天室設置為 $diningEventId');

    // 在 iOS 上動態調整前台通知顯示設置
    // 當用戶在聊天室時，關閉自動顯示；離開時恢復
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin == null) {
        // iOS 平台：根據是否在聊天室調整通知顯示
        final bool shouldShowNotifications = diningEventId == null;
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: shouldShowNotifications,
              badge: shouldShowNotifications,
              sound: shouldShowNotifications,
            );
        debugPrint('iOS 平台：前台通知顯示已${shouldShowNotifications ? '開啟' : '關閉'}');
      }
    } catch (e) {
      debugPrint('調整 iOS 前台通知設置失敗: $e');
    }
  }

  /// 獲取當前正在查看的聊天室 ID
  String? get activeChatRoomId => _activeChatRoomId;

  /// 獲取並清除待處理的聊天導航
  String? consumePendingChatNavigation() {
    final pending = _pendingChatNavigation;
    _pendingChatNavigation = null;
    return pending;
  }

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

      // 只清除已顯示的通知，保留排程通知
      await clearDisplayedNotifications();

      // 設置 token 刷新監聽
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token 已更新 (${_getPlatformName()}): $newToken');
        saveTokenToSupabase();
      });

      // 設置前台通知選項 - 根據平台調整
      // iOS：讓 Firebase 自動處理前台通知顯示
      // Android：關閉 Firebase 自動顯示，由我們手動處理
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        // Android 平台：關閉 Firebase 自動顯示
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: false, // Android 關閉自動顯示
              badge: false,
              sound: false,
            );
        debugPrint('Android 平台：已關閉 Firebase 自動前台通知');
      } else {
        // iOS 平台：開啟 Firebase 自動顯示
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true, // iOS 開啟自動顯示
              badge: true,
              sound: true,
            );
        debugPrint('iOS 平台：已開啟 Firebase 自動前台通知');
      }

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

    // iOS 初始化設定
    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
          onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
        );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/notification_icon'),
        iOS: iosInitSettings,
      ),
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // 創建通知頻道（僅 Android 需要）
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

  // 獲取平台名稱
  String _getPlatformName() {
    try {
      // 導入 dart:io 來檢測平台
      if (const bool.fromEnvironment('dart.library.io')) {
        return 'iOS/Android';
      }
      return 'Web';
    } catch (e) {
      return 'Unknown';
    }
  }

  // 保存 FCM token 到 Supabase
  Future<bool> saveTokenToSupabase() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token == null) {
        debugPrint('無法獲取FCM Token (${_getPlatformName()})');
        return false;
      }

      debugPrint('獲取到 FCM Token (${_getPlatformName()}): $token');

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

      if (existingTokens.isNotEmpty) {
        // 更新現有令牌
        final existingTokenId = existingTokens[0]['id'];
        await _supabaseService.client
            .from('user_device_tokens')
            .update({
              'token': token,
              'updated_at': TimeService().now().toIso8601String(),
            })
            .eq('id', existingTokenId);
      } else {
        // 創建新令牌記錄
        await _supabaseService.client.from('user_device_tokens').insert({
          'user_id': currentUser.id,
          'token': token,
          'updated_at': TimeService().now().toIso8601String(),
        });
      }

      debugPrint('FCM Token已成功保存到Supabase');
      return true;
    } catch (e) {
      debugPrint('保存FCM Token發生異常: $e');
      return false;
    }
  }

  // 清除用戶的 FCM token 從 Supabase
  Future<bool> clearUserTokenFromSupabase() async {
    try {
      // 獲取當前用戶
      final currentUser = _supabaseService.auth.currentUser;
      if (currentUser == null) {
        debugPrint('用戶未登入，無法清除FCM Token');
        return false;
      }

      // 刪除該用戶的所有 FCM token 記錄
      await _supabaseService.client
          .from('user_device_tokens')
          .delete()
          .eq('user_id', currentUser.id);

      debugPrint('已成功清除用戶 ${currentUser.id} 的 FCM Token');
      return true;
    } catch (e) {
      debugPrint('清除FCM Token發生異常: $e');
      return false;
    }
  }

  // 處理點擊通知（Firebase 通知，用於後台/關閉時收到的通知）
  void _handleNotificationClick(RemoteMessage message) {
    debugPrint('點擊了 Firebase 通知: ${message.data}');

    // 檢查是否為聊天通知
    final notificationType = message.data['type'] as String?;
    final diningEventId = message.data['dining_event_id'] as String?;

    if (notificationType == 'chat_message' && diningEventId != null) {
      // 聊天通知：導航到對應的聊天室
      debugPrint('點擊聊天通知，導航到聊天室: $diningEventId');
      _navigateToChatRoom(diningEventId);
      return;
    }

    // 非聊天通知：根據使用者狀態進行導航
    _handleNotificationNavigation();
  }

  // 處理通知導航 - 根據使用者狀態進行導航
  Future<void> _handleNotificationNavigation() async {
    try {
      // 檢查是否有有效的導航鍵和上下文
      if (_navigatorKey?.currentState == null ||
          _navigatorKey!.currentContext == null) {
        debugPrint('NotificationService: 無有效的導航上下文，跳過導航');
        return;
      }

      final context = _navigatorKey!.currentContext!;

      // 檢查上下文是否仍然掛載
      if (!context.mounted) {
        debugPrint('NotificationService: 上下文已不再掛載，跳過導航');
        return;
      }

      debugPrint('NotificationService: 開始根據使用者狀態進行導航');

      // 使用 NavigationService 的 navigateToUserStatusPage 方法
      await _navigationService.navigateToUserStatusPage(context);

      debugPrint('NotificationService: 通知導航完成');
    } catch (e) {
      debugPrint('NotificationService: 處理通知導航時發生錯誤: $e');
      // 記錄錯誤但不阻止程式運行
      debugPrintStack(label: '通知導航錯誤堆疊');
    }
  }

  // 導航到聊天室頁面
  Future<void> _navigateToChatRoom(String diningEventId) async {
    try {
      // 檢查是否有有效的導航鍵和上下文
      if (_navigatorKey?.currentState == null ||
          _navigatorKey!.currentContext == null) {
        debugPrint('NotificationService: 無有效的導航上下文，儲存待處理導航');
        // 儲存待處理的導航，等 APP 初始化完成後處理
        _pendingChatNavigation = diningEventId;
        return;
      }

      final context = _navigatorKey!.currentContext!;

      // 檢查上下文是否仍然掛載
      if (!context.mounted) {
        debugPrint('NotificationService: 上下文已不再掛載，儲存待處理導航');
        _pendingChatNavigation = diningEventId;
        return;
      }

      debugPrint('NotificationService: 導航到聊天室 $diningEventId');

      // 使用 NavigationService 導航到聊天室
      _navigationService.navigateToChatRoom(context, diningEventId);

      debugPrint('NotificationService: 聊天室導航完成');
    } catch (e) {
      debugPrint('NotificationService: 導航到聊天室時發生錯誤: $e');
      // 儲存待處理的導航
      _pendingChatNavigation = diningEventId;
    }
  }

  /// 處理 APP 啟動時的初始通知（冷啟動時點擊通知打開 APP）
  Future<void> checkInitialMessage() async {
    try {
      // 獲取 APP 從終止狀態啟動時點擊的通知
      final RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();

      if (initialMessage != null) {
        debugPrint('APP 冷啟動時的通知: ${initialMessage.data}');

        // 檢查是否為聊天通知
        final notificationType = initialMessage.data['type'] as String?;
        final diningEventId = initialMessage.data['dining_event_id'] as String?;

        if (notificationType == 'chat_message' && diningEventId != null) {
          debugPrint('冷啟動聊天通知，儲存待處理導航: $diningEventId');
          _pendingChatNavigation = diningEventId;
        }
      }
    } catch (e) {
      debugPrint('檢查初始通知時發生錯誤: $e');
    }
  }

  // iOS 舊版本本地通知處理（iOS 10 以下）
  static Future<void> _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    debugPrint('iOS 舊版本收到本地通知: $title');
    // 可以在這裡處理舊版本 iOS 的通知邏輯
  }

  // 通知響應處理（點擊本地通知時觸發）
  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    final String? payload = response.payload;
    debugPrint('點擊了本地通知，payload: $payload');

    if (payload != null) {
      // 嘗試解析 payload 來判斷通知類型
      // payload 格式類似: {type: chat_message, dining_event_id: xxx}
      if (payload.contains('type: chat_message') ||
          payload.contains("'type': 'chat_message'")) {
        // 嘗試從 payload 中提取 dining_event_id
        final diningEventId = _extractDiningEventId(payload);
        if (diningEventId != null) {
          debugPrint('點擊聊天本地通知，導航到聊天室: $diningEventId');
          NotificationService()._navigateToChatRoom(diningEventId);
          return;
        }
      }

      // 非聊天通知：透過單例實例處理導航
      NotificationService()._handleNotificationNavigation();
    }
  }

  // 從 payload 字串中提取 dining_event_id
  static String? _extractDiningEventId(String payload) {
    try {
      // 嘗試匹配 dining_event_id: xxx 或 'dining_event_id': 'xxx'
      final patterns = [
        RegExp(r"dining_event_id:\s*([a-zA-Z0-9\-]+)"),
        RegExp(r"'dining_event_id':\s*'([a-zA-Z0-9\-]+)'"),
        RegExp(r'"dining_event_id":\s*"([a-zA-Z0-9\-]+)"'),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(payload);
        if (match != null && match.groupCount >= 1) {
          return match.group(1);
        }
      }

      return null;
    } catch (e) {
      debugPrint('解析 dining_event_id 失敗: $e');
      return null;
    }
  }

  // 處理前台消息
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('收到前台消息: ${message.notification?.title}');
    debugPrint('消息數據: ${message.data}');

    // 檢查是否為聊天訊息通知
    final notificationType = message.data['type'] as String?;
    final diningEventId = message.data['dining_event_id'] as String?;

    // 如果是聊天通知，且用戶當前正在該聊天室中，則不顯示通知也不導航
    if (notificationType == 'chat_message' && diningEventId != null) {
      if (_activeChatRoomId == diningEventId) {
        debugPrint('用戶正在聊天室 $diningEventId，跳過通知顯示和導航');
        // 不顯示通知，Realtime 會自動更新聊天內容
        return;
      }

      // 用戶不在該聊天室，顯示通知但不自動導航到其他頁面
      debugPrint('收到聊天通知，用戶不在該聊天室，顯示通知');
      await _showChatNotification(message, diningEventId);
      // 不要調用 _handleNotificationNavigation()，避免頁面跳轉
      return;
    }

    // 非聊天通知的處理邏輯（保持原有行為）
    // 在 iOS 上，Firebase 已經會自動顯示通知，所以我們不需要再手動顯示
    // 在 Android 上，我們需要手動顯示通知
    if (message.notification != null) {
      // 檢查平台，只在 Android 上顯示本地通知
      try {
        // 檢查是否為 Android 平台（通過檢查是否能創建 Android 特定的通知頻道）
        final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
            _localNotifications
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();

        if (androidPlugin != null) {
          // 這是 Android 平台，需要手動顯示通知
          debugPrint('Android 平台：手動顯示前台通知');

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
        } else {
          // 這是 iOS 平台，Firebase 已經自動顯示通知，不需要手動顯示
          debugPrint('iOS 平台：Firebase 自動顯示通知，跳過手動顯示');
        }
      } catch (e) {
        debugPrint('處理前台通知時發生錯誤: $e');
      }
    }

    // 收到非聊天通知後，根據使用者狀態進行導航
    await _handleNotificationNavigation();
  }

  // 顯示聊天通知（不觸發頁面導航）
  Future<void> _showChatNotification(
    RemoteMessage message,
    String diningEventId,
  ) async {
    if (message.notification == null) return;

    try {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      // 準備 payload，包含聊天室 ID 以便點擊時導航
      final Map<String, dynamic> payload = {
        'type': 'chat_message',
        'dining_event_id': diningEventId,
      };

      if (androidPlugin != null) {
        // Android 平台：手動顯示通知
        debugPrint('Android 平台：手動顯示聊天通知');

        await _localNotifications.show(
          message.hashCode,
          message.notification!.title,
          message.notification!.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'chat_notification_channel',
              '聊天訊息',
              channelDescription: '用於接收群組聊天訊息通知',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@drawable/notification_icon',
              color: const Color(0xFFB33D1C),
            ),
          ),
          payload: payload.toString(),
        );
      } else {
        // iOS 平台：Firebase 已經自動顯示通知
        debugPrint('iOS 平台：Firebase 自動顯示聊天通知');
      }
    } catch (e) {
      debugPrint('顯示聊天通知時發生錯誤: $e');
    }
  }

  // 清除所有通知
  Future<void> clearAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('所有本地通知已清除');

      // 保持 Firebase 前台通知設定一致
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        // Android 平台：關閉 Firebase 自動顯示
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: false,
              badge: false,
              sound: false,
            );
      } else {
        // iOS 平台：開啟 Firebase 自動顯示
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true, // iOS 開啟自動顯示
              badge: true, // 保持徽章功能
              sound: true, // iOS 開啟聲音
            );
      }
      debugPrint('Firebase 通知設置已更新');
    } catch (e) {
      debugPrint('清除通知錯誤: $e');
    }
  }

  // 清除已顯示的通知（僅清除通知欄上的通知，保留排程通知）
  Future<void> clearDisplayedNotifications() async {
    try {
      // 獲取所有活躍的通知
      final List<ActiveNotification>? activeNotifications =
          await _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.getActiveNotifications();

      if (activeNotifications != null && activeNotifications.isNotEmpty) {
        // 逐一取消已顯示的通知
        for (final notification in activeNotifications) {
          await _localNotifications.cancel(notification.id ?? 0);
        }
        debugPrint('已清除 ${activeNotifications.length} 個已顯示的通知');
      } else {
        debugPrint('沒有找到已顯示的通知');
      }
    } catch (e) {
      debugPrint('清除已顯示通知錯誤: $e');
      // 如果無法獲取活躍通知，回退到清除所有通知
      debugPrint('回退到清除所有通知方法');
      await _clearAllNotificationsForced();
    }
  }

  // 強制清除所有通知（包括排程通知）- 僅在必要時使用
  Future<void> _clearAllNotificationsForced() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('強制清除所有本地通知（包括排程通知）');
    } catch (e) {
      debugPrint('強制清除通知錯誤: $e');
    }
  }

  // 在初始化時使用的清除方法（保持原有行為）
  Future<void> clearAllNotificationsOnInit() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('初始化時所有本地通知已清除');

      // 保持 Firebase 前台通知設定一致
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        // Android 平台：關閉 Firebase 自動顯示
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: false,
              badge: false,
              sound: false,
            );
      } else {
        // iOS 平台：開啟 Firebase 自動顯示
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true, // iOS 開啟自動顯示
              badge: true, // 保持徽章功能
              sound: true, // iOS 開啟聲音
            );
      }
      debugPrint('Firebase 通知設置已更新');
    } catch (e) {
      debugPrint('清除通知錯誤: $e');
    }
  }

  // 用戶登出時清除所有通知（包括排程通知）
  Future<void> clearAllNotificationsOnLogout() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('登出時所有本地通知已清除（包括排程通知）');

      // 保持 Firebase 前台通知設定一致
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        // Android 平台：關閉 Firebase 自動顯示
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: false,
              badge: false,
              sound: false,
            );
      } else {
        // iOS 平台：開啟 Firebase 自動顯示
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true, // iOS 開啟自動顯示
              badge: true, // 保持徽章功能
              sound: true, // iOS 開啟聲音
            );
      }
      debugPrint('Firebase 通知設置已更新');
    } catch (e) {
      debugPrint('清除登出通知錯誤: $e');
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

      // iOS 通知設定
      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      final platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosNotificationDetails,
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
        if (scheduledDate.isAfter(TimeService().now())) {
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
    if (scheduledDate.isAfter(TimeService().now())) {
      final difference = scheduledDate.difference(TimeService().now());
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

      // iOS 預約提醒通知設定
      const DarwinNotificationDetails iosReservationNotificationDetails =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosReservationNotificationDetails,
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
        if (scheduledTime.isAfter(TimeService().now())) {
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

  // 當應用完全關閉時，Firebase會自動處理通知顯示
  // 我們不需要在這裡手動創建本地通知，以避免重複通知
  // Firebase的自動通知會使用我們在Android配置中設定的圖標和顏色
  debugPrint('後台消息處理完成，讓Firebase自動處理通知顯示');
}
