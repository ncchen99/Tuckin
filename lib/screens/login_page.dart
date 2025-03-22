import 'package:flutter/material.dart';
import 'package:tuckin/services/auth_service.dart';
import '../components/components.dart';
import '../utils/index.dart'; // 導入自適應佈局工具
import 'profile_setup_page.dart'; // 導入基本資料填寫頁面

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _isNCKUEmail = false; // 添加成大email標記
  bool _showTip = true; // 控制提示框顯示

  @override
  void initState() {
    super.initState();
    // 檢查當前用戶是否已登入
    _checkCurrentUser();

    // 5秒後淡出提示框
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showTip = false;
        });
      }
    });
  }

  // 檢查當前用戶
  void _checkCurrentUser() {
    final currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      // 如果已經登入，直接跳到基本資料填寫頁面
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    const ProfileSetupPage(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(
                begin: begin,
                end: end,
              ).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              return SlideTransition(position: offsetAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      });

      // 如果是成大email，設置標記
      if (currentUser.email != null) {
        setState(() {
          _isNCKUEmail = _authService.isNCKUEmail(currentUser.email);
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 處理 Google 登入
  Future<void> _handleGoogleSignIn() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先同意隱私條款')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _authService.signInWithGoogle(context);

      if (response != null && response.user?.email != null) {
        // 檢查是否為成大email
        setState(() {
          _isNCKUEmail = _authService.isNCKUEmail(response.user!.email);
        });

        // 登入成功，進行下一步操作
        // 導航到基本資料填寫頁面，添加滑動動畫
        if (mounted) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      const ProfileSetupPage(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(
                  begin: begin,
                  end: end,
                ).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(position: offsetAnimation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }

        debugPrint('登入成功: ${response.user?.email}');
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('登入失敗: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 顯示隱私條款並處理同意操作
  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder:
          (context) => PrivacyPolicyDialog(
            onAgree: () {
              // 用戶點擊「我同意」按鈕時自動勾選條款
              setState(() {
                _agreeToTerms = true;
              });
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 設置為false，防止鍵盤彈出時自動調整整個佈局
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background/bg2.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 主要內容
              Column(
                children: [
                  // 上方空白區域 - 增加空間
                  SizedBox(height: 150.h),

                  // 中上部分 - Logo和標語
                  Container(
                    margin: EdgeInsets.only(bottom: 20.h),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // TUCKIN 標誌 - 固定大小
                        Container(
                          width: 220.w,
                          height: 110.h,
                          margin: EdgeInsets.only(bottom: 15.h),
                          child: Stack(
                            children: [
                              // 底部陰影圖片
                              Positioned(
                                left: 0,
                                top: 3,
                                child: Image.asset(
                                  'assets/images/icon/tuckin_t_brand.png',
                                  width: 220.w,
                                  height: 110.h,
                                  fit: BoxFit.contain,
                                  color: Colors.black.withValues(alpha: 0.4),
                                  colorBlendMode: BlendMode.srcIn,
                                ),
                              ),
                              // 圖片主圖層
                              Image.asset(
                                'assets/images/icon/tuckin_t_brand.png',
                                width: 220.w,
                                height: 110.h,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),

                        // 「餐桌相聚 情誼相繫」標題
                        Container(
                          margin: EdgeInsets.only(top: 5.h, bottom: 10.h),
                          child: Text(
                            '餐桌相聚 情誼相繫',
                            style: TextStyle(
                              fontSize: 26.sp,
                              fontFamily: 'OtsutomeFont',
                              color: const Color(0xFF23456B),
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 中間彈性空間
                  Expanded(child: Container()),

                  // 底部登入區域
                  Container(
                    margin: EdgeInsets.only(bottom: 40.h),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 隱私條款勾選 - 先顯示
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 15.h),
                          width: 250.w,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 勾選框
                              CustomCheckbox(
                                value: _agreeToTerms,
                                onChanged: (value) {
                                  setState(() {
                                    _agreeToTerms = value ?? false;
                                  });
                                },
                              ),
                              SizedBox(width: 8.w),
                              // 隱私條款文字
                              GestureDetector(
                                onTap: _showPrivacyPolicy,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '我同意',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        color: const Color(0xFF23456B),
                                        fontFamily: 'OtsutomeFont',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Container(
                                      margin: EdgeInsets.only(left: 2.w),
                                      child: Text(
                                        '隱私條款',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          color: const Color(0xFF23456B),
                                          fontFamily: 'OtsutomeFont',
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                          decorationColor: const Color(
                                            0xFF23456B,
                                          ),
                                          decorationThickness: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Google 登入按鈕 - 後顯示
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.h),
                          child:
                              _isLoading
                                  ? LoadingImage(
                                    width: 60.w,
                                    height: 60.h,
                                    color: const Color(0xFFB33D1C),
                                  )
                                  : GoogleSignInButton(
                                    onPressed: _handleGoogleSignIn,
                                    enabled: _agreeToTerms, // 根據條款勾選狀態決定按鈕是否可用
                                  ),
                        ),

                        // 進度指示器
                        Padding(
                          padding: EdgeInsets.only(top: 60.h, bottom: 20.h),
                          child: const ProgressDotsIndicator(
                            totalSteps: 5,
                            currentStep: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 右上角浮動提示框
              if (_showTip)
                Positioned(
                  top: 20.h,
                  right: 20.w,
                  child: AnimatedOpacity(
                    opacity: _showTip ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 15.w,
                        vertical: 10.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFF23456B),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: const Color(0xFF23456B),
                            size: 20.h,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '用學校Gmail登入即可獲得認證',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF23456B),
                              fontFamily: 'OtsutomeFont',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
