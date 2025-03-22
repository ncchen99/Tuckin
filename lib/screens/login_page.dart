import 'package:flutter/material.dart';
import '../components/components.dart';
import '../utils/index.dart'; // 導入自適應佈局工具

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _agreeToTerms = false;
  final FocusNode _emailFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.removeListener(_onFocusChange);
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      // 僅更新狀態以觸發UI重建
    });
  }

  void _login() {
    // 這裡處理登入邏輯
    // print('登入按鈕被點擊，Email: ${_emailController.text}, 同意條款: $_agreeToTerms');
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => const PrivacyPolicyDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 檢測輸入框是否獲得焦點
    final bool isInputFocused = _emailFocusNode.hasFocus;

    // 檢測鍵盤是否顯示
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      // 點擊空白處收起鍵盤
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
            child: Column(
              children: [
                // 上方留白區域 - 隨鍵盤狀態動態調整高度
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: isInputFocused || isKeyboardVisible ? 30.h : 120.h,
                  curve: Curves.easeOutQuad,
                ),

                // TUCKIN 標誌 - 隨鍵盤狀態動態調整大小
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isInputFocused || isKeyboardVisible ? 150.w : 200.w,
                  height: isInputFocused || isKeyboardVisible ? 75.h : 100.h,
                  curve: Curves.easeOutQuad,
                  child: Stack(
                    children: [
                      // 底部陰影圖片
                      Positioned(
                        left: 0,
                        top: 3,
                        child: Image.asset(
                          'assets/images/icon/tuckin_t_brand.png',
                          width:
                              isInputFocused || isKeyboardVisible
                                  ? 150.w
                                  : 200.w,
                          height:
                              isInputFocused || isKeyboardVisible
                                  ? 75.h
                                  : 100.h,
                          fit: BoxFit.contain,
                          color: Colors.black.withValues(alpha: 0.4),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                      // 圖片主圖層
                      Image.asset(
                        'assets/images/icon/tuckin_t_brand.png',
                        width:
                            isInputFocused || isKeyboardVisible ? 150.w : 200.w,
                        height:
                            isInputFocused || isKeyboardVisible ? 75.h : 100.h,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),

                // 「餐桌相聚 情誼相繫」標題 - 隨鍵盤狀態動態調整大小和可見性
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: isInputFocused || isKeyboardVisible ? 0 : 65.h,
                  curve: Curves.easeOutQuad,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isInputFocused || isKeyboardVisible ? 0.0 : 1.0,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 20.h, top: 15.h),
                      child: Text(
                        '餐桌相聚 情誼相繫',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontFamily: 'OtsutomeFont',
                          color: const Color(0xFF23456B),
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

                // 中間彈性空間 - 動態調整以適應各種螢幕尺寸
                Expanded(
                  flex: isInputFocused || isKeyboardVisible ? 1 : 3,
                  child: Container(),
                ),

                // 輸入框
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: IconTextInput(
                    hintText: '請輸入您的電子郵件',
                    iconPath: 'assets/images/icon/email.png',
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                  ),
                ),

                // 隱私條款勾選和底線整體包裝
                Padding(
                  padding: sizeConfig.getAdaptivePadding(top: 10, bottom: 15),
                  child: Center(
                    child: Column(
                      children: [
                        // 勾選框和文字在同一行，確保置中
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CustomCheckbox(
                              value: _agreeToTerms,
                              onChanged: (value) {
                                setState(() {
                                  _agreeToTerms = value ?? false;
                                });
                              },
                            ),
                            SizedBox(width: 4.w),
                            GestureDetector(
                              onTap: _showPrivacyPolicy,
                              child: SizedBox(
                                width: context.widthPercent(0.35),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 隱私條款文字
                                    Padding(
                                      padding: EdgeInsets.only(top: 5.h),
                                      child: Text(
                                        '我同意隱私條款',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          color: const Color(0xFF23456B),
                                          fontFamily: 'OtsutomeFont',
                                          fontWeight: FontWeight.bold,
                                          height: 1,
                                        ),
                                        textAlign: TextAlign.left,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    // 底線僅放在隱私條款下方，精確定位
                                    Padding(
                                      padding: EdgeInsets.only(left: 50.w),
                                      child: Container(
                                        width: 65.w,
                                        height: 2.h,
                                        margin: EdgeInsets.only(top: 1.h),
                                        color: const Color(0xFF23456B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 按鈕和進度指示器區域 - 確保足夠空間容納鍵盤
                SizedBox(
                  height: isInputFocused || isKeyboardVisible ? 20.h : 80.h,
                ),

                // 一鍵登入按鈕
                Padding(
                  padding: EdgeInsets.only(bottom: 40.h),
                  child: ImageButton(
                    imagePath: 'assets/images/ui/button/red_l.png',
                    text: '開始',
                    width: 140.w,
                    height: 70.h,
                    onPressed: _login,
                    textStyle: TextStyle(
                      fontSize: 22,
                      color: const Color(0xFFD1D1D1),
                      fontFamily: 'OtsutomeFont',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // 進度指示器
                Padding(
                  padding: EdgeInsets.only(bottom: 20.h),
                  child: const ProgressDotsIndicator(
                    totalSteps: 5,
                    currentStep: 1,
                  ),
                ),

                // 確保鍵盤彈出時有足夠空間
                SizedBox(
                  height:
                      isKeyboardVisible
                          ? MediaQuery.of(context).viewInsets.bottom
                          : 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
