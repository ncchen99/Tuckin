import 'package:flutter/material.dart';
import '../components/components.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background/bg2.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: SizedBox(
                height: screenHeight * 0.88, // 設置一個固定高度
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // TUCKIN 標誌 - 調整間距
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 15,
                        top: 120,
                      ), // 減少底部間距
                      child: Stack(
                        children: [
                          // 底部陰影圖片
                          Positioned(
                            left: 0,
                            top: 3,
                            child: Image.asset(
                              'assets/images/icon/tuckin_t_brand.png',
                              width: 200,
                              height: 100,
                              fit: BoxFit.contain,
                              color: Colors.black.withValues(alpha: 0.4),
                              colorBlendMode: BlendMode.srcIn,
                            ),
                          ),
                          // 圖片主圖層
                          Image.asset(
                            'assets/images/icon/tuckin_t_brand.png',
                            width: 200,
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),

                    // 「餐桌相聚 情誼相繫」標題 - 移除框線效果，改為普通深藍色文字
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20), // 減少底部間距
                      child: Text(
                        '餐桌相聚 情誼相繫',
                        style: TextStyle(
                          fontSize: 24,
                          fontFamily: 'OtsutomeFont',
                          color: Color(0xFF23456B),
                          fontWeight: FontWeight.bold,
                          height: 1.4, // 保持行高一致
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // 增加一個彈性空間，使得輸入框和下方元素往下移
                    SizedBox(height: screenHeight * 0.08),

                    // 輸入框 - 調整間距使其與截圖一致
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: IconTextInput(
                        hintText: '請輸入您的電子郵件',
                        iconPath: 'assets/images/icon/email.png',
                        controller: _emailController,
                      ),
                    ),

                    // 隱私條款勾選和底線整體包裝 - 調整間距
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 15,
                        bottom: 25,
                      ), // 微調間距
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
                                const SizedBox(width: 4), // 縮小間距
                                GestureDetector(
                                  onTap: _showPrivacyPolicy,
                                  child: SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width *
                                        0.35,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 隱私條款文字 - 移除框線效果，改為普通深藍色文字
                                        const Padding(
                                          padding: EdgeInsets.only(
                                            top: 5,
                                          ), // 微調頂部間距
                                          child: Text(
                                            '我同意隱私條款',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Color(0xFF23456B),
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
                                          padding: const EdgeInsets.only(
                                            left: 56, // 調整位置，讓底線只在「隱私條款」下方
                                          ),
                                          child: Container(
                                            width: 75,
                                            height: 2,
                                            margin: const EdgeInsets.only(
                                              top: 1,
                                            ),
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

                    // 一鍵登入按鈕 - 縮小按鈕大小並使用小號按鈕圖片
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 20,
                        bottom: 20,
                      ), // 微調間距
                      child: ImageButton(
                        imagePath: 'assets/images/ui/button/red_l.png',
                        text: '開始',
                        width: 140,
                        height: 70,
                        onPressed: _login,
                      ),
                    ),

                    // 增加一個撐大的彈性空間，使指示器儘量往底部靠
                    const Spacer(),

                    // 進度指示器 - 移至靠近底部位置
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10), // 增加底部間距
                      child: ProgressDotsIndicator(
                        totalSteps: 5,
                        currentStep: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
