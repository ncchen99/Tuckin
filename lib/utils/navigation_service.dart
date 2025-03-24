import 'package:flutter/material.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';

/// 集中管理應用程式的導航邏輯
///
/// 負責根據用戶狀態決定初始路由，以及處理用戶登入後的頁面導航
class NavigationService {
  // 單例模式
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // 服務實例
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  // 保存當前用戶狀態
  String _currentUserStatus = 'initial';
  String get currentUserStatus => _currentUserStatus;

  /// 初始化導航服務
  ///
  /// 檢查用戶登入狀態，並確定初始路由
  Future<String> determineInitialRoute() async {
    try {
      // 檢查用戶是否已登入
      if (_authService.isLoggedIn()) {
        final currentUser = _authService.getCurrentUser();
        if (currentUser != null) {
          // 檢查用戶狀態
          final userStatus = await _databaseService.getUserStatus(
            currentUser.id,
          );
          _currentUserStatus = userStatus;

          debugPrint('NavigationService: 用戶狀態為 $_currentUserStatus');

          // 檢查用戶是否已完成設置
          final hasCompletedSetup = await _databaseService.hasCompletedSetup(
            currentUser.id,
          );

          if (hasCompletedSetup) {
            // 用戶已完成設置，根據狀態決定路由
            return _getRouteByUserStatus(userStatus);
          } else {
            // 用戶未完成設置，檢查應該跳轉到哪個設置頁面
            return await _getSetupRoute(currentUser.id);
          }
        }
      }

      // 用戶未登入或無法獲取用戶資訊，返回歡迎頁面
      return '/';
    } catch (e) {
      debugPrint('導航服務錯誤: $e');
      return '/'; // 發生錯誤時，返回歡迎頁面
    }
  }

  /// 根據用戶狀態獲取對應的路由
  String _getRouteByUserStatus(String status) {
    switch (status) {
      case 'initial':
        return '/home';
      case 'booking':
        return '/dinner_reservation';
      case 'waiting_matching':
      case 'matching_failed':
        return '/matching_status';
      case 'waiting_confirmation':
        return '/attendance_confirmation';
      case 'waiting_restaurant':
        return '/restaurant_selection';
      case 'waiting_dinner':
        return '/dinner_info';
      case 'rating':
        return '/dinner_rating';
      default:
        return '/home';
    }
  }

  /// 根據用戶設置完成情況決定下一步設置頁面
  Future<String> _getSetupRoute(String userId) async {
    try {
      final userProfile = await _databaseService.getUserCompleteProfile(userId);

      debugPrint('NavigationService: 用戶設置狀態檢查');

      // 檢查個性測驗、食物偏好和基本資料的完成情況
      final hasPersonalityType = userProfile['personality_type'] != null;
      final hasFoodPreferences =
          userProfile['food_preferences'] != null &&
          userProfile['food_preferences'].isNotEmpty;
      final hasProfile =
          userProfile['profile'] != null && userProfile['profile'].isNotEmpty;

      // 根據完成情況決定下一步設置頁面
      if (!hasProfile) {
        // 基本資料未完成
        return '/profile_setup';
      } else if (!hasFoodPreferences) {
        // 食物偏好未完成
        return '/food_preference';
      } else if (!hasPersonalityType) {
        // 個性測驗未完成
        return '/personality_test';
      } else {
        // 所有設置已完成
        return '/home';
      }
    } catch (e) {
      debugPrint('獲取用戶設置狀態錯誤: $e');
      return '/profile_setup'; // 發生錯誤時，從基本資料設置開始
    }
  }

  /// 導航到根據用戶當前狀態決定的頁面
  Future<void> navigateToUserStatusPage(BuildContext context) async {
    try {
      if (!_authService.isLoggedIn()) {
        // 用戶未登入，導航到歡迎頁面
        if (ModalRoute.of(context)?.settings.name != '/') {
          Navigator.of(context).pushReplacementNamed('/');
        }
        return;
      }

      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) {
        // 無法獲取用戶資訊，導航到歡迎頁面
        Navigator.of(context).pushReplacementNamed('/');
        return;
      }

      // 檢查用戶狀態
      final userStatus = await _databaseService.getUserStatus(currentUser.id);
      _currentUserStatus = userStatus;

      debugPrint('NavigationService: 導航到狀態對應頁面，狀態: $_currentUserStatus');

      // 檢查用戶是否已完成設置
      final hasCompletedSetup = await _databaseService.hasCompletedSetup(
        currentUser.id,
      );

      if (hasCompletedSetup) {
        // 用戶已完成設置，根據狀態導航
        final targetRoute = _getRouteByUserStatus(userStatus);
        if (ModalRoute.of(context)?.settings.name != targetRoute) {
          Navigator.of(context).pushReplacementNamed(targetRoute);
        }
      } else {
        // 用戶未完成設置，導航到設置頁面
        final setupRoute = await _getSetupRoute(currentUser.id);
        if (ModalRoute.of(context)?.settings.name != setupRoute) {
          Navigator.of(context).pushReplacementNamed(setupRoute);
        }
      }
    } catch (e) {
      debugPrint('導航到用戶狀態頁面錯誤: $e');
    }
  }

  /// 在用戶完成設置後導航到主頁
  void navigateToHomeAfterSetup(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  /// 處理設置流程頁面之間的導航
  ///
  /// 從 profile_setup -> food_preference -> personality_test
  void navigateToNextSetupStep(BuildContext context, String currentStep) {
    switch (currentStep) {
      case 'profile_setup':
        Navigator.of(context).pushReplacementNamed('/food_preference');
        break;
      case 'food_preference':
        Navigator.of(context).pushReplacementNamed('/personality_test');
        break;
      case 'personality_test':
        navigateToHomeAfterSetup(context);
        break;
      default:
        break;
    }
  }

  /// 登出後導航回歡迎頁面
  void navigateAfterSignOut(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  /// 從歡迎頁面導航到登入頁面
  void navigateToLoginPage(BuildContext context) {
    Navigator.of(context).pushNamed('/login');
  }

  /// 導航到首頁
  void navigateToHome(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  /// 導航到晚餐預約頁面
  void navigateToDinnerReservation(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/dinner_reservation');
  }

  /// 導航到出席確認頁面
  void navigateToAttendanceConfirmation(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/attendance_confirmation');
  }

  /// 導航到餐廳選擇頁面
  void navigateToRestaurantSelection(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/restaurant_selection');
  }

  /// 導航到晚餐資訊頁面
  void navigateToDinnerInfo(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/dinner_info');
  }

  /// 導航到晚餐評分頁面
  void navigateToDinnerRating(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/dinner_rating');
  }

  /// 導航到通知頁面
  void navigateToNotifications(BuildContext context) {
    Navigator.of(context).pushNamed('/notifications');
  }

  /// 導航到用戶設置頁面
  void navigateToUserSettings(BuildContext context) {
    Navigator.of(context).pushNamed('/user_settings');
  }
}
