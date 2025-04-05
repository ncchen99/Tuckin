import 'package:flutter/material.dart';
import 'package:tuckin/components/common/image_button.dart'; // 導入圖片按鈕元件
import '../../utils/index.dart';

class ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isServerError;
  final bool showButton; // 是否顯示按鈕

  const ErrorScreen({
    super.key,
    required this.message,
    required this.onRetry,
    this.isServerError = true,
    this.showButton = true, // 預設顯示按鈕
  });

  // 簡化錯誤訊息
  String _getSimplifiedMessage() {
    if (message.contains('AuthService') || message.contains('認證')) {
      return '認證服務初始化失敗';
    } else if (message.contains('網絡') ||
        message.contains('網路') ||
        message.contains('連接') ||
        message.contains('連線')) {
      return '網路連線中斷';
    } else if (message.contains('超時') || message.contains('timeout')) {
      return '連線超時，請稍後再試';
    } else if (message.contains('伺服器')) {
      return '伺服器暫時無法連線';
    }
    return '發生錯誤，請稍後再試';
  }

  @override
  Widget build(BuildContext context) {
    final simplifiedMessage = _getSimplifiedMessage();

    return WillPopScope(
      // 防止使用系統返回鍵
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 222, 222, 222),
        body: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20), // 頂部間距
                  // 錯誤圖標 (如果顯示在截圖中有問題，可以考慮暫時移除)
                  if (true) // 改為 false 可以暫時禁用圖標
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // 底部陰影層
                        Positioned(
                          top: 3,
                          child: Image.asset(
                            'assets/images/icon/no_connection.png',
                            width: 120, // 縮小圖標尺寸
                            height: 120,
                            color: Colors.black.withOpacity(0.4),
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                        // 主圖層
                        Image.asset(
                          'assets/images/icon/no_connection.png',
                          width: 120, // 縮小圖標尺寸
                          height: 120,
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),

                  // 錯誤標題
                  Text(
                    isServerError ? '伺服器連接錯誤' : '網路連線中斷',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB33D1C),
                      fontFamily: 'OtsutomeFont',
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 錯誤詳細訊息
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      simplifiedMessage, // 使用簡化的錯誤訊息
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color.fromARGB(255, 74, 74, 74),
                        fontFamily: 'OtsutomeFont',
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // 只在需要時顯示按鈕
                  if (showButton) ...[
                    const SizedBox(height: 60),
                    // 使用 ImageButton 作為 OK 按鈕
                    ImageButton(
                      text: 'OK',
                      imagePath:
                          'assets/images/ui/button/red_m.png', // 使用橘紅色中等大小按鈕
                      width: 125.w, // 設置合適的寬度
                      height: 70.h, // 設置合適的高度
                      onPressed: () {
                        // 只執行回調，不進行任何額外的動作來關閉螢幕
                        // 防止按鈕點擊直接關閉錯誤畫面
                        debugPrint('ErrorScreen: 按鈕被點擊，執行回調');
                        onRetry();
                      },
                    ),
                  ],

                  const SizedBox(height: 20), // 底部間距
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
