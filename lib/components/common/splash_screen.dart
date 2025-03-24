import 'package:flutter/material.dart';
import '../../utils/index.dart';
import '../../services/auth_service.dart';
import 'dart:async';

/// 品牌加載頁面組件
///
/// 在應用啟動時顯示品牌標誌，並在指定時間後淡出
/// 同時檢查用戶狀態並導航到適當頁面
class SplashScreen extends StatefulWidget {
  /// 要顯示的子組件(通常是實際的應用內容)
  final Widget child;

  /// 加載時間(毫秒)，默認為1500毫秒
  final int loadingDuration;

  /// 淡出動畫持續時間(毫秒)，默認為800毫秒
  final int fadeOutDuration;

  /// 額外的過渡延遲時間(毫秒)，默認為500毫秒
  final int transitionDelay;

  const SplashScreen({
    Key? key,
    required this.child,
    this.loadingDuration = 1500,
    this.fadeOutDuration = 400,
    this.transitionDelay = 400,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // 簡化狀態管理，只使用一個狀態變量
  bool _showSplash = true;
  late AnimationController _loadingAnimController;
  late Animation<double> _fadeAnimation;
  final NavigationService _navigationService = NavigationService();
  final AuthService _authService = AuthService();
  Timer? _timeoutTimer; // 超時計時器
  Timer? _forceShowContentTimer; // 強制顯示內容計時器

  // 確保檢查用戶狀態的邏輯只執行一次
  bool _hasCheckedUserStatus = false;

  @override
  void initState() {
    super.initState();

    debugPrint(
      'SplashScreen: 初始化開始，頁面路徑: ${ModalRoute.of(context)?.settings.name ?? "unknown"}',
    );

    // 初始化加載動畫控制器
    _loadingAnimController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.fadeOutDuration),
    );

    // 使用簡單的線性動畫
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_loadingAnimController);

    // 設置兩級超時機制
    // 1秒後強制開始淡出
    Timer(const Duration(seconds: 2), () {
      if (mounted && _showSplash) {
        debugPrint('SplashScreen: 2秒超時，強制開始淡出');
        _dismissSplash();
      }
    });

    // 3秒後強制關閉啟動頁面（無論如何）
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _showSplash) {
        debugPrint('SplashScreen: 5秒超時，強制結束啟動畫面');
        _forceDismissSplash();
      }
    });

    // 在正常情況下，啟動頁面會在預設時間後開始淡出
    Future.delayed(Duration(milliseconds: widget.loadingDuration), () {
      if (mounted && _showSplash) {
        debugPrint('SplashScreen: 啟動頁面淡出開始');
        _dismissSplash();
      }
    });
  }

  // 正常的淡出處理
  void _dismissSplash() {
    if (!mounted || !_showSplash) return;

    debugPrint('SplashScreen: 執行淡出動畫');
    _loadingAnimController
        .forward()
        .then((_) {
          debugPrint('SplashScreen: 淡出動畫完成');
          if (mounted) {
            _onFadeOutComplete();
          }
        })
        .catchError((e) {
          debugPrint('SplashScreen: 淡出動畫失敗: $e');
          if (mounted) {
            _forceDismissSplash();
          }
        });
  }

  // 強制關閉啟動頁面，不依賴動畫
  void _forceDismissSplash() {
    if (!mounted || !_showSplash) return;

    debugPrint('SplashScreen: 強制關閉啟動頁面');
    setState(() {
      _showSplash = false;
    });
    _checkUserStatusIfNeeded();
  }

  // 動畫完成後的處理
  void _onFadeOutComplete() {
    if (!mounted) return;

    debugPrint('SplashScreen: 設置_showSplash=false，顯示主內容');
    setState(() {
      _showSplash = false;
    });

    // 延遲一個幀再檢查用戶狀態，確保UI已經更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserStatusIfNeeded();
    });
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
      final bool isLoggedIn = _authService.isLoggedIn();
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
    _timeoutTimer?.cancel();
    _forceShowContentTimer?.cancel();
    _loadingAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 主內容始終顯示在底層
        widget.child,

        // 品牌加載覆蓋層（只在需要時顯示）
        if (_showSplash)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: const Color(0xFFF5F5F5), // 淺灰色背景
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 品牌標誌（添加陰影效果）
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // 底部陰影層
                        Positioned(
                          top: 3.h, // 陰影偏移
                          child: Image.asset(
                            'assets/images/icon/tuckin_t_brand.png',
                            width: 200.w,
                            height: 200.w,
                            fit: BoxFit.contain,
                            color: Colors.black.withOpacity(0.4),
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                        // 主圖層
                        Image.asset(
                          'assets/images/icon/tuckin_t_brand.png',
                          width: 200.w,
                          height: 200.w,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
