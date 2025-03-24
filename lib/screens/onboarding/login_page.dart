import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/components.dart';
import '../../utils/index.dart';
import '../../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 處理登入
  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = '請輸入電子郵件和密碼';
          _isLoading = false;
        });
        return;
      }

      final success = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );

      if (!mounted) return;

      if (success) {
        // 使用導航服務處理登入後的導航
        await _navigationService.navigateToUserStatusPage(context);
      } else {
        setState(() {
          _errorMessage = '登入失敗，請檢查郵箱和密碼';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '發生錯誤: $e';
          _isLoading = false;
        });
      }
    }
  }

  // 處理註冊
  Future<void> _handleSignUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage = '請輸入電子郵件和密碼';
          _isLoading = false;
        });
        return;
      }

      final success = await _authService.signUpWithEmailAndPassword(
        email,
        password,
      );

      if (!mounted) return;

      if (success) {
        // 使用導航服務處理註冊後的導航
        _navigationService.navigateToNextSetupStep(context, 'profile_setup');
      } else {
        setState(() {
          _errorMessage = '註冊失敗，郵箱可能已被使用';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '發生錯誤: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background/bg1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 返回按鈕
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.black54,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // 應用標誌
                  Padding(
                    padding: EdgeInsets.only(top: 20.h, bottom: 50.h),
                    child: Image.asset(
                      'assets/images/icon/tuckin_t_brand.png',
                      width: 150.w,
                    ),
                  ),

                  // 登入表單
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15.r),
                      border: Border.all(
                        color: const Color(0xFF23456B),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '登入 / 註冊',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontFamily: 'OtsutomeFont',
                            color: const Color(0xFF23456B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 20.h),

                        // 郵箱輸入框
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: '電子郵件',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            prefixIcon: const Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: 15.h),

                        // 密碼輸入框
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: '密碼',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            prefixIcon: const Icon(Icons.lock),
                          ),
                          obscureText: true,
                        ),

                        // 錯誤訊息
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 15.h),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),

                        SizedBox(height: 30.h),

                        // 登入按鈕
                        ImageButton(
                          text: '登入',
                          imagePath: 'assets/images/ui/button/blue_m.png',
                          width: 150.w,
                          height: 70.h,
                          onPressed:
                              _isLoading
                                  ? () {} // 空函數，禁用按鈕
                                  : () {
                                    _handleLogin(); // 不使用 await
                                  },
                        ),

                        SizedBox(height: 15.h),

                        // 註冊按鈕
                        ImageButton(
                          text: '註冊',
                          imagePath: 'assets/images/ui/button/red_m.png',
                          width: 150.w,
                          height: 70.h,
                          onPressed:
                              _isLoading
                                  ? () {} // 空函數，禁用按鈕
                                  : () {
                                    _handleSignUp(); // 不使用 await
                                  },
                        ),

                        // 加載指示器
                        if (_isLoading)
                          Padding(
                            padding: EdgeInsets.only(top: 15.h),
                            child: const CircularProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
