import 'package:flutter/material.dart';
import 'package:stroke_text/stroke_text.dart';

void main() {
  runApp(const MyApp());
}

// 自定義文字元件（帶邊框）
class StrokeTextWidget extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color textColor;
  final Color strokeColor;
  final TextAlign textAlign;
  final EdgeInsets padding;
  final TextOverflow overflow;
  final int? maxLines;

  const StrokeTextWidget({
    Key? key,
    required this.text,
    this.fontSize = 16.0,
    this.textColor = const Color(0xFFD1D1D1),
    this.strokeColor = const Color(0xFF23456B),
    this.textAlign = TextAlign.left,
    this.padding = EdgeInsets.zero,
    this.overflow = TextOverflow.visible,
    this.maxLines,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: StrokeText(
        text: text,
        textStyle: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontFamily: 'OtsutomeFont',
          fontWeight: FontWeight.bold,
          height: 1.4, // 進一步增加行高，使文字下移
          overflow: overflow,
        ),
        strokeColor: strokeColor,
        strokeWidth: 3,
        textAlign: textAlign,
        maxLines: maxLines,
      ),
    );
  }
}

// 自定義輸入框元件（不帶陰影）
class IconTextInput extends StatelessWidget {
  final String hintText;
  final String iconPath;
  final TextEditingController controller;
  final bool obscureText;

  const IconTextInput({
    Key? key,
    required this.hintText,
    required this.iconPath,
    required this.controller,
    this.obscureText = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      width: MediaQuery.of(context).size.width * 0.8,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF23456B), width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              style: const TextStyle(
                fontFamily: 'OtsutomeFont',
                fontSize: 16,
                height: 1.4, // 進一步增加行高
              ),
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  color: Colors.grey,
                  fontFamily: 'OtsutomeFont',
                  height: 1.4, // 增加行高
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10,
                ), // 調整為上下對稱填充，使文字垂直居中
                isCollapsed: false, // 確保文字居中顯示
                alignLabelWithHint: true, // 讓提示文字與輸入文字對齊
              ),
              textAlignVertical: TextAlignVertical.center, // 設置文字垂直對齊為居中
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Image.asset(
              iconPath,
              width: 30,
              height: 30,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

// 自定義勾選框元件
class CustomCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const CustomCheckbox({Key? key, required this.value, required this.onChanged})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onChanged(!value);
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF23456B), width: 2),
        ),
        // 當選中時，內部顯示一個有邊距的橘色小方塊
        child:
            value
                ? Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFB33D1C),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )
                : null,
      ),
    );
  }
}

// 隱私條款對話框
class PrivacyPolicyDialog extends StatelessWidget {
  const PrivacyPolicyDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF23456B), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: const StrokeTextWidget(
                text: '隱私條款',
                fontSize: 24,
                textAlign: TextAlign.center,
                padding: EdgeInsets.only(bottom: 4), // 調整文字位置
              ),
            ),
            const SizedBox(height: 20),
            // 使用 Flexible + SingleChildScrollView 處理長文字
            Flexible(
              child: SingleChildScrollView(
                child: const Text(
                  '非常感謝您使用TUCKIN應用程式。我們十分重視您的隱私保護與個人資料安全。\n\n'
                  '• 我們僅收集必要的資訊以提供服務\n'
                  '• 您的個人資料不會被出售或分享給第三方\n'
                  '• 我們採用現代加密技術保護您的資料\n'
                  '• 您有權限查閱、更正或刪除您的個人資料\n\n'
                  '使用本應用即表示您同意我們的隱私政策條款。',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'OtsutomeFont',
                    height: 1.4, // 進一步增加行高
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF23456B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                '我已了解',
                style: TextStyle(
                  fontFamily: 'OtsutomeFont',
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 圖片按鈕元件
class ImageButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final String imagePath;
  final double width;
  final double height;
  final TextStyle textStyle;

  const ImageButton({
    Key? key,
    required this.onPressed,
    required this.text,
    required this.imagePath,
    this.width = 200,
    this.height = 100,
    this.textStyle = const TextStyle(
      fontSize: 24,
      color: Color(0xFFD1D1D1),
      fontFamily: 'OtsutomeFont',
      fontWeight: FontWeight.bold,
    ),
  }) : super(key: key);

  @override
  _ImageButtonState createState() => _ImageButtonState();
}

class _ImageButtonState extends State<ImageButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: SizedBox(
        width: widget.width,
        height: widget.height + 10, // 增加高度以確保陰影可見
        child: Stack(
          children: [
            // 底部陰影圖片 - 使用相同的圖片但僅向下偏移
            if (!_isPressed)
              Positioned(
                left: 0,
                top: 5,
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(color: Colors.transparent),
                  child: Image.asset(
                    widget.imagePath,
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.contain,
                    color: Colors.black.withOpacity(0.4),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),

            // 按鈕主圖層
            Positioned(
              top: _isPressed ? 6 : 0,
              child: Container(
                decoration: const BoxDecoration(color: Colors.transparent),
                child: Image.asset(
                  widget.imagePath,
                  width: widget.width,
                  height: widget.height,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // 按鈕文字 - 使用 StrokeText 組件
            Positioned(
              top: _isPressed ? 9 : 3, // 稍微下移文字
              left: 0,
              right: 0,
              bottom: 10, // 調整文字位置，避免被底部切斷
              child: Center(
                child: StrokeText(
                  text: widget.text,
                  textStyle: widget.textStyle.copyWith(
                    letterSpacing: 1.0,
                    height: 1.4, // 進一步增加行高
                  ),
                  strokeColor: const Color(0xFF23456B), // 修改為深藍色
                  strokeWidth: 4,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 進度指示器元件 - 修改為使用橘色和藍色點，沒有連線
class ProgressDotsIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;

  const ProgressDotsIndicator({
    Key? key,
    required this.totalSteps,
    required this.currentStep,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFB33D1C) : const Color(0xFF23456B),
            shape: BoxShape.circle,
            border:
                isActive
                    ? Border.all(color: const Color(0xFF23456B), width: 1.5)
                    : null, // 為活動點添加藍色邊框
          ),
        );
      }),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tuckin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false, // 移除調試標記
    );
  }
}

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
    print('登入按鈕被點擊，Email: ${_emailController.text}, 同意條款: $_agreeToTerms');
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => const PrivacyPolicyDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // TUCKIN 標誌 - 調整間距
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20, top: 40),
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
                              color: Colors.black.withOpacity(0.4),
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

                    // 「以食會友」標題 - 調整間距
                    const Padding(
                      padding: EdgeInsets.only(bottom: 30),
                      child: StrokeTextWidget(
                        text: '以食會友',
                        fontSize: 30,
                        textAlign: TextAlign.center,
                      ),
                    ),

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
                      padding: const EdgeInsets.only(top: 20, bottom: 30),
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
                                const SizedBox(width: 10),
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
                                        // 隱私條款文字
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 3,
                                          ), // 添加頂部padding使文字垂直對齊
                                          child: StrokeTextWidget(
                                            text: '我同意 隱私條款',
                                            fontSize: 16,
                                            textColor: Color(0xFFD1D1D1),
                                            textAlign: TextAlign.left,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        // 底線僅放在隱私條款下方，精確定位
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 53, // 調整位置，讓底線只在「隱私條款」下方
                                          ),
                                          child: Container(
                                            width: 64,
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

                    // 一鍵登入按鈕 - 調整間距
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 30),
                      child: ImageButton(
                        imagePath: 'assets/images/ui/button/red_l.png',
                        text: '開始',
                        width: 150,
                        height: 80,
                        onPressed: _login,
                      ),
                    ),

                    // 進度指示器 - 調整位置使其更接近底部
                    const Padding(
                      padding: EdgeInsets.only(top: 40, bottom: 10),
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
