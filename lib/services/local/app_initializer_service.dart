import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../services.dart';
import '../../utils/navigation_service.dart';

/// 應用初始化服務
///
/// 負責處理 APP 啟動時的所有初始化邏輯，包括：
/// - 環境變數加載
/// - Firebase 初始化
/// - 時區初始化
/// - 網絡連接測試
/// - 各項服務初始化
/// - 通知服務初始化
class AppInitializerService {
  // 單例模式
  static final AppInitializerService _instance =
      AppInitializerService._internal();
  factory AppInitializerService() => _instance;
  AppInitializerService._internal();

  /// 初始化時區設置
  Future<void> initializeTimeZone() async {
    try {
      debugPrint('初始化時區...');
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('成功初始化時區: $timeZoneName');
    } catch (e) {
      debugPrint('初始化時區錯誤: $e');
      // 使用一個默認時區作為備用
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Taipei'));
      } catch (_) {
        // 如果無法設置任何時區，則不阻止程序繼續運行
      }
    }
  }

  /// 測試網絡連接
  Future<bool> testNetworkConnection() async {
    try {
      // 嘗試連接Google的DNS伺服器
      final result = await http
          .get(Uri.parse('https://g.co'))
          .timeout(const Duration(seconds: 5));
      return result.statusCode == 200;
    } catch (e) {
      try {
        // 嘗試連接Google的伺服器
        final result = await http
            .get(Uri.parse('https://www.google.com'))
            .timeout(const Duration(seconds: 5));
        return result.statusCode == 200;
      } catch (e) {
        return false;
      }
    }
  }

  /// 加載環境變數
  Future<bool> loadEnvironment() async {
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('環境變數加載成功。變數數量: ${dotenv.env.length}');
      return true;
    } catch (e) {
      debugPrint('環境變數加載錯誤: $e');
      return false;
    }
  }

  /// 初始化 Firebase
  Future<bool> initializeFirebase() async {
    try {
      await Firebase.initializeApp();
      debugPrint('Firebase 初始化成功');
      return true;
    } catch (e) {
      debugPrint('Firebase 初始化錯誤: $e');
      debugPrintStack(label: 'Firebase 初始化錯誤堆疊');
      return false;
    }
  }

  /// 初始化時間服務
  Future<bool> initializeTimeService() async {
    try {
      await TimeService().initialize();
      debugPrint('TimeService 初始化完成');
      return true;
    } catch (e) {
      debugPrint('TimeService 初始化錯誤: $e');
      return false;
    }
  }

  /// 初始化核心服務（AuthService, RealtimeService）
  Future<bool> initializeServices(
    ErrorHandler errorHandler,
    GlobalKey<NavigatorState> navigatorKey, {
    VoidCallback? onNetworkRetry,
  }) async {
    try {
      // 初始化 AuthService
      await AuthService().initialize();
      debugPrint('AuthService 初始化成功');

      // 初始化 RealtimeService
      try {
        await RealtimeService().initialize(navigatorKey);
        debugPrint('RealtimeService 初始化成功');
      } catch (e) {
        debugPrint('RealtimeService 初始化錯誤: $e');
        // 這裡不會阻止應用繼續啟動
      }
      return true;
    } catch (e) {
      debugPrint('服務初始化錯誤: $e');

      // 處理錯誤
      if (e is ApiError) {
        errorHandler.handleApiError(e, () async {
          try {
            await initializeServices(errorHandler, navigatorKey);
          } catch (retryError) {
            debugPrint('重試初始化服務錯誤: $retryError');
          }
        });
      } else {
        errorHandler.showError(
          message: '網絡連接錯誤，請檢查您的網絡設置',
          isServerError: false,
          isNetworkError: true,
          onRetry: onNetworkRetry ?? () {},
        );
      }

      // 嘗試強制登出以重置狀態
      try {
        await AuthService().signOut();
      } catch (signOutError) {
        debugPrint('強制登出錯誤: $signOutError');
      }
      return false;
    }
  }

  /// 確定初始路由
  Future<String> determineInitialRoute() async {
    try {
      debugPrint('AppInitializerService: 開始獲取初始路由');
      String route = await NavigationService().determineInitialRoute();
      debugPrint('AppInitializerService: 設置初始路由為: $route');
      return route;
    } catch (e) {
      debugPrint('AppInitializerService: 確定初始路由出錯: $e');
      debugPrintStack(label: '初始路由確定錯誤堆疊');
      return '/';
    }
  }

  /// 初始化通知服務
  Future<void> initializeNotificationService(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    try {
      debugPrint('開始初始化通知服務...');
      await NotificationService().initialize(navigatorKey);
      debugPrint('通知服務初始化成功');

      // 檢查 APP 冷啟動時是否有待處理的通知
      await NotificationService().checkInitialMessage();
      debugPrint('已檢查初始通知');

      // 獲取 FCM token 並輸出（僅用於調試）
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM Token: ${token?.substring(0, 50)}...');
    } catch (e) {
      debugPrint('通知服務初始化錯誤: $e');
      // 輸出詳細錯誤堆疊
      debugPrintStack(label: '通知服務初始化錯誤堆疊');
      // 通知服務初始化失敗不阻止應用程序啟動
    }
  }

  /// 執行完整的應用初始化流程
  ///
  /// 返回初始路由
  Future<String> performFullInitialization({
    required ErrorHandler errorHandler,
    required GlobalKey<NavigatorState> navigatorKey,
    VoidCallback? onNetworkError,
  }) async {
    // 1. 加載環境變數
    bool envLoaded = await loadEnvironment();

    // 2. 初始化 Firebase
    await initializeFirebase();

    // 3. 初始化時間服務
    await initializeTimeService();

    // 4. 檢測網絡連接
    bool isNetworkConnected = false;
    if (TimeService().isSynced) {
      isNetworkConnected = true;
      debugPrint('TimeService 已同步（NTP 成功），略過網絡測試');
    } else {
      debugPrint('正在測試網絡連接...');
      isNetworkConnected = await testNetworkConnection();
      debugPrint('網絡連接測試結果: ${isNetworkConnected ? '成功' : '失敗'}');
    }

    if (!isNetworkConnected) {
      debugPrint('網絡連接測試失敗，顯示錯誤訊息');
      errorHandler.showError(
        message: '網絡連接錯誤，請檢查您的網絡設置',
        isServerError: false,
        isNetworkError: true,
        onRetry: onNetworkError ?? () {},
      );
    }

    // 5. 初始化核心服務
    if (isNetworkConnected) {
      await initializeServices(errorHandler, navigatorKey);
    }

    // 6. 確定初始路由
    String initialRoute = '/';
    if (envLoaded) {
      initialRoute = await determineInitialRoute();

      // 7. 初始化通知服務
      await initializeNotificationService(navigatorKey);

      debugPrint('所有初始化完成 - 初始路由為: $initialRoute');
    } else {
      debugPrint('初始化未成功，使用默認路由: /');
    }

    return initialRoute;
  }
}
