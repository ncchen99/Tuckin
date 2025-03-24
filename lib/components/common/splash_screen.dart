import 'package:flutter/material.dart';
import '../../utils/index.dart';
import '../../services/auth_service.dart';

/// 品牌加載頁面組件
///
/// 在應用啟動時顯示品牌標誌，並在指定時間後淡出
/// 同時檢查用戶狀態並導航到適當頁面
class SplashScreen extends StatefulWidget {
  /// 要顯示的子組件(通常是實際的應用內容)
  final Widget child;

  /// 加載時間(毫秒)，默認為1500毫秒
  final int loadingDuration;

  const SplashScreen({
    Key? key,
    required this.child,
    this.loadingDuration = 1500,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _loadingAnimController;
  late Animation<double> _fadeAnimation;
  final NavigationService _navigationService = NavigationService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    // 初始化加載動畫控制器
    _loadingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _loadingAnimController, curve: Curves.easeOut),
    );

    // 延遲指定時間後隱藏加載頁面
    Future.delayed(Duration(milliseconds: widget.loadingDuration), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _loadingAnimController.forward();

        // 在動畫完成後檢查用戶狀態並導航
        _loadingAnimController.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _checkUserStatusAndNavigate();
          }
        });
      }
    });
  }

  /// 檢查用戶狀態並導航到適當頁面
  Future<void> _checkUserStatusAndNavigate() async {
    if (mounted && ModalRoute.of(context)?.settings.name == '/') {
      // 只在主頁面時進行狀態檢查和導航
      // 避免在子頁面顯示時進行不必要的導航
      if (_authService.isLoggedIn()) {
        await _navigationService.navigateToUserStatusPage(context);
      }
    }
  }

  @override
  void dispose() {
    _loadingAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 實際應用內容
        widget.child,

        // 品牌加載覆蓋層
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Visibility(
              visible: _isLoading || _fadeAnimation.value > 0.01,
              child: Opacity(
                opacity: _fadeAnimation.value,
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
            );
          },
        ),
      ],
    );
  }
}
