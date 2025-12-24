import 'package:flutter/material.dart';
import '../../utils/index.dart';
import 'package:tuckin/services/services.dart';
import 'dart:async';

/// 原 SplashScreen 轉為 App 狀態轉換組件
///
/// 在應用加載完成後處理用戶狀態檢查並導航到適當頁面
/// 原生啟動畫面由 flutter_native_splash 提供
class SplashScreen extends StatefulWidget {
  /// 要顯示的子組件(通常是實際的應用內容)
  final Widget child;

  /// 檢查用戶狀態的延遲時間(毫秒)，默認為300毫秒
  final int statusCheckDelay;

  const SplashScreen({
    super.key,
    required this.child,
    this.statusCheckDelay = 300,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final NavigationService _navigationService = NavigationService();
  final AuthService _authService = AuthService();
  Timer? _statusCheckTimer; // 狀態檢查計時器

  // 確保檢查用戶狀態的邏輯只執行一次
  bool _hasCheckedUserStatus = false;

  @override
  void initState() {
    super.initState();

    debugPrint(
      'SplashScreen: 初始化開始，頁面路徑: ${ModalRoute.of(context)?.settings.name ?? "unknown"}',
    );

    // 設置狀態檢查計時器
    _statusCheckTimer = Timer(
      Duration(milliseconds: widget.statusCheckDelay),
      () {
        if (mounted) {
          _checkUserStatusIfNeeded();
        }
      },
    );
  }

  // 檢查用戶狀態並進行導航（確保只執行一次）
  void _checkUserStatusIfNeeded() {
    if (_hasCheckedUserStatus) {
      debugPrint('SplashScreen: 已經檢查過用戶狀態，不再重複');
      return;
    }

    _hasCheckedUserStatus = true;
    debugPrint('SplashScreen: 開始檢查用戶狀態');

    // 修改路由檢查邏輯
    final currentRoute = ModalRoute.of(context)?.settings.name;
    debugPrint('SplashScreen: 當前路由: $currentRoute');

    // 移除對路由的限制，總是執行狀態檢查
    if (mounted) {
      _checkUserStatusAndNavigate();
    }
  }

  /// 檢查用戶狀態並導航到適當頁面
  Future<void> _checkUserStatusAndNavigate() async {
    debugPrint('SplashScreen: 執行用戶狀態檢查...');

    try {
      final bool isLoggedIn = await _authService.isLoggedIn();
      debugPrint('SplashScreen: 用戶登入狀態: $isLoggedIn');

      if (isLoggedIn) {
        debugPrint('SplashScreen: 用戶已登入，進行導航');

        // 延遲一小段時間，確保頁面已經穩定
        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) {
          debugPrint('SplashScreen: 組件已卸載，取消導航');
          return;
        }

        await _navigationService.navigateToUserStatusPage(context);
        debugPrint('SplashScreen: 導航完成');
      } else {
        debugPrint('SplashScreen: 用戶未登入，保持在歡迎頁面');
      }
    } catch (e) {
      debugPrint('SplashScreen: 檢查用戶狀態時出錯 - $e');
      // 如果發生錯誤，嘗試登出用戶以重置狀態
      try {
        await _authService.signOut();
        debugPrint('SplashScreen: 已登出用戶');
      } catch (signOutError) {
        debugPrint('SplashScreen: 登出用戶出錯 - $signOutError');
      }
    }
  }

  @override
  void dispose() {
    debugPrint('SplashScreen: 組件銷毀');
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 直接顯示主內容，原生啟動畫面由 flutter_native_splash 處理
    return widget.child;
  }
}
