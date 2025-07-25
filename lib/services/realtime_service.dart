import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tuckin/services/supabase_service.dart';
import 'package:tuckin/services/api_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/auth_service.dart';

/// RealtimeService 用於訂閱 Supabase 的實時數據庫變更
/// 主要功能：監聽 user_status 資料表的變更，自動導航至對應頁面
class RealtimeService with WidgetsBindingObserver {
  // 單例模式
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  // 服務相關依賴
  final SupabaseService _supabaseService = SupabaseService();
  final DatabaseService _databaseService = DatabaseService();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  // 實時通道
  RealtimeChannel? _userStatusChannel;
  RealtimeChannel? _diningEventsChannel;

  // 用於儲存用戶ID
  String? _userId;

  // 導航鍵，用於頁面跳轉
  GlobalKey<NavigatorState>? _navigatorKey;

  // 訂閱狀態
  bool _isSubscribed = false;
  bool _isDiningEventsSubscribed = false;
  bool _isInitialized = false;

  // 保存上一個用戶狀態
  String? _lastUserStatus;

  // 初始化實時服務
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    debugPrint('RealtimeService: 初始化實時服務');

    // 註冊生命週期觀察者
    WidgetsBinding.instance.addObserver(this);

    try {
      // 獲取當前用戶
      final user = await _authService.getCurrentUser();
      if (user == null) {
        debugPrint('RealtimeService: 用戶未登入，無法訂閱狀態');
        return;
      }

      _userId = user.id;

      // 獲取初始用戶狀態
      _lastUserStatus = await _databaseService.getUserStatus(_userId!);
      debugPrint('RealtimeService: 初始用戶狀態: $_lastUserStatus');

      // 訂閱用戶狀態
      await subscribeToUserStatus();

      _isInitialized = true;
      debugPrint('RealtimeService: 初始化成功');
    } catch (e) {
      debugPrint('RealtimeService: 初始化錯誤 - $e');
      await _retryInitialize();
    }
  }

  // 處理應用生命週期變更
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('RealtimeService: 應用生命週期變更 - $state');

    if (state == AppLifecycleState.resumed) {
      // 應用從後台恢復到前台
      _onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      // 應用進入後台
      _onAppPaused();
    }
  }

  // 應用恢復前台處理
  Future<void> _onAppResumed() async {
    debugPrint('RealtimeService: 應用恢復前台');

    try {
      // 檢查用戶是否已登入
      if (!await _authService.isLoggedIn()) {
        debugPrint('RealtimeService: 用戶未登入，跳過狀態檢查和導航');
        return;
      }

      // 重新連接實時訂閱
      if (!_isSubscribed && _userId != null) {
        await subscribeToUserStatus();
      }

      // 檢查用戶狀態並只在狀態改變時導航
      if (_userId != null) {
        final currentStatus = await _databaseService.getUserStatus(_userId!);
        debugPrint(
          'RealtimeService: 檢查到當前用戶狀態: $currentStatus，上一狀態: $_lastUserStatus',
        );

        if (_lastUserStatus != currentStatus) {
          debugPrint(
            'RealtimeService: 用戶狀態已改變，從 $_lastUserStatus 變為 $currentStatus',
          );
          _lastUserStatus = currentStatus;
          _navigateBasedOnStatus(currentStatus);
        } else {
          debugPrint('RealtimeService: 用戶狀態未改變，保持當前頁面');
        }

        // 新增：如果用戶狀態是 waiting_attendance，訂閱聚餐事件變更
        if (currentStatus == 'waiting_attendance') {
          await _handleWaitingAttendanceStatus();
        }
      }
    } catch (e) {
      debugPrint('RealtimeService: 應用恢復處理錯誤 - $e');
    }
  }

  // 新增：處理 waiting_attendance 狀態的聚餐事件訂閱
  Future<void> _handleWaitingAttendanceStatus() async {
    try {
      debugPrint('RealtimeService: 用戶狀態為 waiting_attendance，開始處理聚餐事件訂閱');

      // 獲取用戶當前的聚餐事件資料
      final diningEvent = await _databaseService.getCurrentDiningEvent(
        _userId!,
      );

      if (diningEvent != null) {
        final diningEventId = diningEvent['id'] as String?;

        if (diningEventId != null && diningEventId.isNotEmpty) {
          debugPrint('RealtimeService: 找到聚餐事件ID: $diningEventId，開始訂閱');

          // 重新連接聚餐事件訂閱（如果尚未訂閱或需要重新訂閱）
          if (!_isDiningEventsSubscribed) {
            await subscribeToDiningEvent(diningEventId);
          }

          // 檢查聚餐事件的最新狀態，類似用戶狀態的邏輯
          await _checkDiningEventStatusAndHandle(diningEvent);
        } else {
          debugPrint('RealtimeService: 聚餐事件ID為空');
        }
      } else {
        debugPrint('RealtimeService: 未找到用戶的聚餐事件');
      }
    } catch (e) {
      debugPrint('RealtimeService: 處理 waiting_attendance 狀態時發生錯誤 - $e');
    }
  }

  // 新增：檢查聚餐事件狀態並處理（類似用戶狀態的邏輯）
  Future<void> _checkDiningEventStatusAndHandle(
    Map<String, dynamic> diningEventData,
  ) async {
    try {
      debugPrint('RealtimeService: 檢查到聚餐事件狀態: ${diningEventData['status']}');

      // 創建類似 _handleDiningEventChange 的事件數據
      Map<String, dynamic> eventData = {
        'status': diningEventData['status'],
        'id': diningEventData['id'],
        'reservation_name': diningEventData['reservation_name'],
        'reservation_phone': diningEventData['reservation_phone'],
        'restaurant_id': diningEventData['restaurant_id'],
        'description': diningEventData['description'],
      };

      // 通知聚餐事件監聽器
      _notifyDiningEventListeners(eventData);

      debugPrint('RealtimeService: 已處理聚餐事件狀態變更通知');
    } catch (e) {
      debugPrint('RealtimeService: 檢查聚餐事件狀態時發生錯誤 - $e');
    }
  }

  // 應用進入後台處理
  void _onAppPaused() {
    debugPrint('RealtimeService: 應用進入後台');
    // 可以選擇在此處暫停某些不必要的實時訂閱以節省資源
  }

  // 初始化失敗後的重試機制
  Future<void> _retryInitialize() async {
    debugPrint('RealtimeService: 5秒後重試初始化');
    await Future.delayed(const Duration(seconds: 5));

    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _userId = user.id;
        // 獲取初始用戶狀態
        _lastUserStatus = await _databaseService.getUserStatus(_userId!);
        debugPrint('RealtimeService: 重試初始化 - 獲取初始用戶狀態: $_lastUserStatus');
        await subscribeToUserStatus();
        _isInitialized = true;
      }
    } catch (e) {
      debugPrint('RealtimeService: 重試初始化失敗 - $e');
    }
  }

  // 訂閱用戶狀態變更
  Future<void> subscribeToUserStatus() async {
    if (_userId == null) {
      debugPrint('RealtimeService: 用戶ID為空，無法訂閱');
      return;
    }

    // 取消先前的訂閱
    await _userStatusChannel?.unsubscribe();

    try {
      debugPrint('RealtimeService: 開始訂閱用戶狀態 - 用戶ID: $_userId');

      // 創建實時通道
      _userStatusChannel = _supabaseService.client
          .channel('user_status_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'user_status',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: _userId!,
            ),
            callback: _handleUserStatusChange,
          );

      // 啟動訂閱並使用 await 等待訂閱完成
      debugPrint('RealtimeService: 正在啟動訂閱...');
      _userStatusChannel?.subscribe();
      _isSubscribed = true;

      debugPrint(
        'RealtimeService: 用戶狀態訂閱成功! 監聽 user_status 表格中 user_id=$_userId 的變更',
      );
    } catch (e) {
      _isSubscribed = false;
      debugPrint('RealtimeService: 訂閱用戶狀態失敗 - $e');

      // 重試機制
      Future.delayed(const Duration(seconds: 10), () {
        if (!_isSubscribed) {
          debugPrint('RealtimeService: 嘗試重新訂閱用戶狀態');
          subscribeToUserStatus();
        }
      });
    }
  }

  // 處理用戶狀態變更
  void _handleUserStatusChange(PostgresChangePayload payload) {
    debugPrint('RealtimeService: 收到用戶狀態變更事件');
    debugPrint('RealtimeService: 事件詳情 - ${payload.toString()}');

    try {
      final newRecord = payload.newRecord;
      final status = newRecord['status'] as String?;

      debugPrint('RealtimeService: 用戶狀態變更 - 新狀態: $status');

      if (status != null) {
        if (_lastUserStatus != status) {
          debugPrint('RealtimeService: 用戶狀態已改變，從 $_lastUserStatus 變為 $status');
          _lastUserStatus = status;

          // 異步檢查用戶是否已登入，只有登入狀態才導航
          _checkLoginAndNavigate(status);
        } else {
          debugPrint('RealtimeService: 用戶狀態未改變，保持當前頁面');
        }
      }
    } catch (e) {
      debugPrint('RealtimeService: 處理狀態變更事件時發生錯誤 - $e');
    }
  }

  // 檢查登入狀態後再導航
  Future<void> _checkLoginAndNavigate(String status) async {
    try {
      bool isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        debugPrint('RealtimeService: 用戶已登入，執行導航');
        _navigateBasedOnStatus(status);
      } else {
        debugPrint('RealtimeService: 用戶未登入，忽略狀態變化導航');
      }
    } catch (e) {
      debugPrint('RealtimeService: 檢查登入狀態出錯 - $e');
    }
  }

  // 檢查用戶當前狀態並導航
  Future<void> checkUserStatusAndNavigate() async {
    if (_userId == null) {
      debugPrint('RealtimeService: 用戶未登入，無法檢查狀態');
      return;
    }

    try {
      // 首先檢查用戶是否已登入
      if (!await _authService.isLoggedIn()) {
        debugPrint('RealtimeService: 用戶未登入，跳過狀態檢查和導航');
        return;
      }

      final currentStatus = await _databaseService.getUserStatus(_userId!);
      debugPrint(
        'RealtimeService: 檢查到用戶當前狀態: $currentStatus，上一狀態: $_lastUserStatus',
      );

      if (_lastUserStatus != currentStatus) {
        debugPrint(
          'RealtimeService: 用戶狀態已改變，從 $_lastUserStatus 變為 $currentStatus',
        );
        _lastUserStatus = currentStatus;
        _navigateBasedOnStatus(currentStatus);
      } else {
        debugPrint('RealtimeService: 用戶狀態未改變，保持當前頁面');
      }
    } catch (e) {
      debugPrint('RealtimeService: 檢查用戶狀態錯誤 - $e');
    }
  }

  // 根據用戶狀態導航到對應頁面
  void _navigateBasedOnStatus(String status) {
    if (_navigatorKey?.currentState == null) {
      debugPrint('RealtimeService: 導航器無效，無法導航');
      return;
    }

    // 由於這個方法可能在異步操作後被調用，再次檢查登入狀態
    _authService.isLoggedIn().then((isLoggedIn) {
      if (!isLoggedIn) {
        debugPrint('RealtimeService: 導航時檢測到用戶未登入，放棄導航');
        return;
      }

      final navigator = _navigatorKey!.currentState!;

      // 獲取當前路由名稱
      String? currentRoute;
      navigator.popUntil((route) {
        currentRoute = route.settings.name;
        return true;
      });

      debugPrint('RealtimeService: 當前路由: $currentRoute, 用戶狀態: $status');

      switch (status) {
        case 'initial':
          // 初始狀態，應該在首頁
          _navigateIfNotCurrent(navigator, '/home');
          break;

        case 'booking':
          // 預約階段，應該在預約頁面
          _navigateIfNotCurrent(navigator, '/dinner_reservation');
          break;

        case 'waiting_matching':
          // 等待配對階段，應該在等待配對頁面
          _navigateIfNotCurrent(navigator, '/matching_status');
          break;

        case 'waiting_restaurant':
          // 等待餐廳確認階段，應該在餐廳選擇頁面
          _navigateIfNotCurrent(navigator, '/restaurant_selection');
          break;

        case 'waiting_other_users':
          // 等待其他用戶階段，應該在等待其他用戶頁面
          _navigateIfNotCurrent(navigator, '/dinner_info');
          break;

        case 'waiting_attendance':
          // 等待出席階段，應該在晚餐資訊頁面
          _navigateIfNotCurrent(navigator, '/dinner_info');
          break;

        case 'matching_failed':
          // 配對失敗階段，應該回到首頁
          _navigateIfNotCurrent(navigator, '/matching_status');
          break;

        case 'confirmation_timeout':
          // 逾時未確認階段，應該導航到逾時未確認頁面
          _navigateIfNotCurrent(navigator, '/confirmation_timeout');
          break;

        case 'low_attendance':
          // 團體出席率過低階段，應該導航到團體出席率過低頁面
          _navigateIfNotCurrent(navigator, '/low_attendance');
          break;

        case 'rating':
          // 評分階段，應該在評分頁面
          _navigateIfNotCurrent(navigator, '/dinner_rating');
          break;

        default:
          debugPrint('RealtimeService: 未知狀態 - $status，保持當前頁面');
          break;
      }
    });
  }

  // 如果當前頁面不是目標頁面，則導航到目標頁面
  void _navigateIfNotCurrent(NavigatorState navigator, String targetRoute) {
    // 獲取當前路由名稱
    String? currentRoute;
    navigator.popUntil((route) {
      currentRoute = route.settings.name;
      return true;
    });

    debugPrint('RealtimeService: 當前路由: $currentRoute, 目標路由: $targetRoute');

    // 如果當前路由不是目標路由，則導航
    if (currentRoute != targetRoute) {
      debugPrint('RealtimeService: 導航到 $targetRoute');
      navigator.pushNamedAndRemoveUntil(targetRoute, (route) => false);
    }
  }

  // 新增: 訂閱特定聚餐事件變更
  Future<void> subscribeToDiningEvent(String diningEventId) async {
    if (diningEventId.isEmpty) {
      debugPrint('RealtimeService: 聚餐事件ID為空，無法訂閱');
      return;
    }

    // 取消先前的訂閱
    await _diningEventsChannel?.unsubscribe();

    try {
      debugPrint('RealtimeService: 開始訂閱聚餐事件狀態 - 事件ID: $diningEventId');

      // 創建實時通道
      _diningEventsChannel = _supabaseService.client
          .channel('dining_event_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'dining_events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: diningEventId,
            ),
            callback: (PostgresChangePayload payload) {
              _handleDiningEventChange(payload);
            },
          );

      // 啟動訂閱
      debugPrint('RealtimeService: 正在啟動聚餐事件訂閱...');
      _diningEventsChannel?.subscribe();
      _isDiningEventsSubscribed = true;

      debugPrint(
        'RealtimeService: 聚餐事件訂閱成功! 監聽 dining_events 表格中 id=$diningEventId 的變更',
      );
    } catch (e) {
      _isDiningEventsSubscribed = false;
      debugPrint('RealtimeService: 訂閱聚餐事件狀態失敗 - $e');

      // 重試機制
      Future.delayed(const Duration(seconds: 10), () {
        if (!_isDiningEventsSubscribed) {
          debugPrint('RealtimeService: 嘗試重新訂閱聚餐事件狀態');
          subscribeToDiningEvent(diningEventId);
        }
      });
    }
  }

  // 新增: 處理聚餐事件變更
  void _handleDiningEventChange(PostgresChangePayload payload) {
    debugPrint('RealtimeService: 收到聚餐事件變更事件');
    debugPrint('RealtimeService: 聚餐事件詳情 - ${payload.toString()}');

    try {
      final newRecord = payload.newRecord;
      final diningStatus = newRecord['status'] as String?;
      final diningEventId = newRecord['id'] as String?;
      final reservationName = newRecord['reservation_name'] as String?;
      final reservationPhone = newRecord['reservation_phone'] as String?;
      final restaurantId = newRecord['restaurant_id'] as String?;
      final description = newRecord['description'] as String?;

      // 創建變更事件數據
      Map<String, dynamic> eventData = {
        'status': diningStatus,
        'id': diningEventId,
        'reservation_name': reservationName,
        'reservation_phone': reservationPhone,
        'restaurant_id': restaurantId,
        'description': description,
      };

      debugPrint(
        'RealtimeService: 聚餐事件狀態變更 - 新狀態: $diningStatus, 餐廳ID: $restaurantId, 描述: $description',
      );

      // 廣播聚餐事件變更通知
      _notifyDiningEventListeners(eventData);
    } catch (e) {
      debugPrint('RealtimeService: 處理聚餐事件變更時發生錯誤 - $e');
    }
  }

  // 聚餐事件監聽器集合
  final Map<String, Function(Map<String, dynamic>)> _diningEventListeners = {};

  // 新增: 添加聚餐事件監聽器
  void addDiningEventListener(
    String listenerId,
    Function(Map<String, dynamic>) listener,
  ) {
    _diningEventListeners[listenerId] = listener;
    debugPrint('RealtimeService: 添加聚餐事件監聽器 - ID: $listenerId');
  }

  // 新增: 移除聚餐事件監聽器
  void removeDiningEventListener(String listenerId) {
    _diningEventListeners.remove(listenerId);
    debugPrint('RealtimeService: 移除聚餐事件監聽器 - ID: $listenerId');
  }

  // 新增: 通知所有聚餐事件監聽器
  void _notifyDiningEventListeners(Map<String, dynamic> eventData) {
    for (var callback in _diningEventListeners.values) {
      callback(eventData);
    }
  }

  // 銷毀實時服務
  void dispose() {
    _userStatusChannel?.unsubscribe();
    _diningEventsChannel?.unsubscribe();
    _isSubscribed = false;
    _isDiningEventsSubscribed = false;
    _diningEventListeners.clear();
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('RealtimeService: 已銷毀');
  }
}
