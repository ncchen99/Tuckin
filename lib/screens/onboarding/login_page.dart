import 'package:flutter/material.dart';
import 'package:tuckin/services/auth_service.dart';
import '../../components/components.dart';
import '../../../utils/index.dart'; // 導入自適應佈局工具和NavigationService
import 'profile_setup_page.dart'; // 導入基本資料填寫頁面
import '../../../services/database_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
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
  Future<void> _checkCurrentUser() async {
    final currentUser = await _authService.getCurrentUser();
    if (currentUser != null) {
      // 如果已經登入，使用NavigationService來導航，確保設置正確的導航流程
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 使用NavigationService來處理導航，這樣可以確保按照流程順序
        final navigationService = NavigationService();
        // 根據用戶設置狀態導航到適當頁面
        navigationService.navigateToUserStatusPage(context);
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
        // 設置成大標記
        _isNCKUEmail = _authService.isNCKUEmail(response.user!.email);

        // 登入成功，使用NavigationService來處理導航
        if (mounted) {
          final navigationService = NavigationService();
          // 根據用戶設置狀態導航到適當頁面
          await navigationService.navigateToUserStatusPage(context);
        }

        debugPrint('登入成功: ${response.user?.email}');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登入失敗: $error')));
      }
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
                              Padding(
                                padding: EdgeInsets.only(bottom: 2.h),
                                child: CustomCheckbox(
                                  value: _agreeToTerms,
                                  onChanged: (value) {
                                    setState(() {
                                      _agreeToTerms = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 8.w),
                              // 隱私條款文字
                              GestureDetector(
                                onTap: _showPrivacyPolicy,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '我同意',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        color: const Color(0xFF23456B),
                                        fontFamily: 'OtsutomeFont',
                                        fontWeight: FontWeight.w500,
                                        height: 1.2,
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
                                          height: 1.2,
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
                  child: InfoTipBox(
                    message: '用學校Gmail登入即可獲得認證',
                    show: _showTip,
                    onHide: () {
                      // 提示框完全隱藏後的回調
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
