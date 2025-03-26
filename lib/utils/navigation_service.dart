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
      debugPrint('NavigationService: 開始決定初始路由');

      // 檢查用戶是否已登入
      if (await _authService.isLoggedIn()) {
        debugPrint('NavigationService: 用戶已登入');

        final currentUser = await _authService.getCurrentUser();
        if (currentUser != null) {
          debugPrint('NavigationService: 取得用戶ID - ${currentUser.id}');

          try {
            // 檢查用戶狀態
            final userStatus = await _databaseService.getUserStatus(
              currentUser.id,
            );
            _currentUserStatus = userStatus;

            debugPrint('NavigationService: 用戶狀態為 $_currentUserStatus');

            // 檢查用戶是否已完成設置
            bool hasCompletedSetup = false;
            try {
              hasCompletedSetup = await _databaseService.hasCompletedSetup(
                currentUser.id,
              );
              debugPrint('NavigationService: 用戶設置完成狀態: $hasCompletedSetup');
            } catch (setupError) {
              debugPrint('NavigationService: 檢查設置完成狀態出錯: $setupError，假設未完成設置');
              hasCompletedSetup = false;
            }

            if (hasCompletedSetup) {
              // 用戶已完成設置，根據狀態決定路由
              final route = _getRouteByUserStatus(userStatus);
              debugPrint('NavigationService: 導航到路由 $route');
              return route;
            } else {
              // 用戶未完成設置，檢查應該跳轉到哪個設置頁面
              try {
                final setupRoute = await _getSetupRoute(currentUser.id);
                debugPrint('NavigationService: 導航到設置路由 $setupRoute');
                debugPrint('NavigationService: 確認路由存在於main.dart的routes中');
                return setupRoute;
              } catch (setupRouteError) {
                debugPrint(
                  'NavigationService: 獲取設置路由出錯: $setupRouteError，返回基本資料設置頁面',
                );
                return '/profile_setup';
              }
            }
          } catch (userStatusError) {
            debugPrint('NavigationService: 獲取用戶狀態出錯: $userStatusError，返回歡迎頁面');
            // 用戶可能已被刪除，嘗試登出
            try {
              await _authService.signOut();
              debugPrint('NavigationService: 已登出用戶');
            } catch (signOutError) {
              debugPrint('NavigationService: 登出用戶出錯: $signOutError');
            }
            return '/';
          }
        } else {
          debugPrint('NavigationService: 無法獲取當前用戶，返回歡迎頁面');
          return '/';
        }
      }

      // 用戶未登入，返回歡迎頁面
      debugPrint('NavigationService: 用戶未登入，返回歡迎頁面');
      return '/';
    } catch (e) {
      debugPrint('NavigationService: 確定初始路由時發生嚴重錯誤: $e');
      // 嘗試登出用戶，以防止無限循環
      try {
        await _authService.signOut();
        debugPrint('NavigationService: 發生錯誤後已登出用戶');
      } catch (signOutError) {
        debugPrint('NavigationService: 發生錯誤後登出用戶出錯: $signOutError');
      }
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

      // 總是從基本資料設置開始，保持導航順序
      if (!hasProfile) {
        // 基本資料未完成，從頭開始設置流程
        return '/profile_setup';
      } else if (hasProfile && !hasFoodPreferences && !hasPersonalityType) {
        // 基本資料已完成，但食物偏好和個性測驗未完成
        return '/food_preference';
      } else if (hasProfile && hasFoodPreferences && !hasPersonalityType) {
        // 基本資料和食物偏好已完成，但個性測驗未完成
        return '/personality_test';
      } else {
        // 所有設置已完成
        return '/dinner_reservation';
      }
    } catch (e) {
      debugPrint('獲取用戶設置狀態錯誤: $e');
      return '/profile_setup'; // 發生錯誤時，從基本資料設置開始
    }
  }

  /// 導航到根據用戶當前狀態決定的頁面
  Future<void> navigateToUserStatusPage(BuildContext context) async {
    debugPrint('NavigationService: 開始導航到用戶狀態頁面');

    if (!context.mounted) {
      debugPrint('NavigationService: context已經不再掛載，取消導航');
      return;
    }

    try {
      if (!(await _authService.isLoggedIn())) {
        // 用戶未登入，導航到歡迎頁面
        if (!context.mounted) return;
        final currentRoute = ModalRoute.of(context)?.settings.name;
        debugPrint('NavigationService: 用戶未登入，當前路由: $currentRoute');

        if (currentRoute != '/') {
          debugPrint('NavigationService: 用戶未登入，導航到歡迎頁面');
          if (!context.mounted) return;
          await Navigator.of(context).pushReplacementNamed('/');
        } else {
          debugPrint('NavigationService: 已在歡迎頁面，不需要導航');
        }
        return;
      }

      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        // 無法獲取用戶資訊，導航到歡迎頁面
        debugPrint('NavigationService: 無法獲取用戶資訊，導航到歡迎頁面');
        if (!context.mounted) return;
        await Navigator.of(context).pushReplacementNamed('/');
        return;
      }

      debugPrint('NavigationService: 用戶ID: ${currentUser.id}');

      // 檢查用戶狀態
      String userStatus;
      try {
        userStatus = await _databaseService.getUserStatus(currentUser.id);
        _currentUserStatus = userStatus;
        debugPrint('NavigationService: 獲取到用戶狀態: $_currentUserStatus');
      } catch (e) {
        debugPrint('NavigationService: 獲取用戶狀態失敗: $e，使用默認狀態initial');
        userStatus = 'initial';
        _currentUserStatus = userStatus;
      }

      // 檢查用戶是否已完成設置
      bool hasCompletedSetup;
      try {
        hasCompletedSetup = await _databaseService.hasCompletedSetup(
          currentUser.id,
        );
        debugPrint('NavigationService: 用戶是否完成設置: $hasCompletedSetup');
      } catch (e) {
        debugPrint('NavigationService: 檢查用戶設置狀態出錯: $e，假設未完成設置');
        hasCompletedSetup = false;
      }

      // 確定目標路由
      String targetRoute;
      if (hasCompletedSetup) {
        // 用戶已完成設置，根據狀態導航
        targetRoute = _getRouteByUserStatus(userStatus);
      } else {
        // 用戶未完成設置，導航到設置頁面
        try {
          targetRoute = await _getSetupRoute(currentUser.id);
        } catch (e) {
          debugPrint('NavigationService: 獲取設置路由出錯: $e，使用默認設置路由');
          targetRoute = '/profile_setup';
        }
      }

      // 獲取當前路由
      if (!context.mounted) return;
      final currentRoute = ModalRoute.of(context)?.settings.name;
      debugPrint('NavigationService: 當前路由: $currentRoute, 目標路由: $targetRoute');

      // 只有當當前路由與目標路由不同時才進行導航
      if (currentRoute != targetRoute) {
        debugPrint('NavigationService: 從 $currentRoute 導航到 $targetRoute');

        if (!context.mounted) {
          debugPrint('NavigationService: context已不再掛載，取消導航');
          return;
        }

        // 判斷是否是設置流程的頁面
        if (targetRoute == '/profile_setup' ||
            targetRoute == '/food_preference' ||
            targetRoute == '/personality_test') {
          await Navigator.of(context).pushNamed(targetRoute);
        } else {
          // 對於其他頁面使用pushReplacementNamed
          await Navigator.of(context).pushReplacementNamed(targetRoute);
        }

        debugPrint('NavigationService: 導航完成');
      } else {
        debugPrint('NavigationService: 當前已在目標路由，不需要導航');
      }
    } catch (e) {
      debugPrint('NavigationService: 導航到用戶狀態頁面錯誤: $e');
      // 發生嚴重錯誤時，嘗試導航到歡迎頁面
      try {
        if (!context.mounted) return;
        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (currentRoute != '/') {
          debugPrint('NavigationService: 發生錯誤，重置到歡迎頁面');
          await Navigator.of(context).pushReplacementNamed('/');
        }
      } catch (_) {
        // 忽略最終的錯誤
      }
    }
  }

  /// 在用戶完成設置後導航到晚餐預約頁面
  void navigateToDinnerReservationAfterSetup(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/dinner_reservation', (route) => false);
  }

  /// 處理設置流程頁面之間的導航
  ///
  /// 從 profile_setup -> food_preference -> personality_test
  void navigateToNextSetupStep(BuildContext context, String currentStep) {
    switch (currentStep) {
      case 'profile_setup':
        Navigator.of(context).pushNamed('/food_preference');
        break;
      case 'food_preference':
        Navigator.of(context).pushNamed('/personality_test');
        break;
      case 'personality_test':
        navigateToDinnerReservationAfterSetup(context);
        break;
      default:
        break;
    }
  }

  ///
  /// 從 profile_setup <- food_preference <- personality_test
  void navigateToPreviousSetupStep(BuildContext context, String currentStep) {
    switch (currentStep) {
      case 'food_preference':
        Navigator.of(context).pushNamed('/profile_setup');
        break;
      case 'personality_test':
        Navigator.of(context).pushNamed('/food_preference');
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
    Navigator.of(context).pushReplacementNamed('/dinner_info');
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
