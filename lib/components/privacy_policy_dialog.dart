import 'package:flutter/material.dart';
import 'image_button.dart';

// 隱私條款對話框
class PrivacyPolicyDialog extends StatelessWidget {
  const PrivacyPolicyDialog({super.key});

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
              // 改為深藍色實心文字，移除邊框
              child: const Text(
                '隱私條款',
                style: TextStyle(
                  fontSize: 24,
                  color: Color(0xFF23456B),
                  fontFamily: 'OtsutomeFont',
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
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
            // 使用自定義的 ImageButton 代替 ElevatedButton
            ImageButton(
              imagePath: 'assets/images/ui/button/blue_m.png',
              text: '我同意',
              width: 130,
              height: 65,
              textStyle: const TextStyle(
                fontSize: 20,
                color: Color(0xFFD1D1D1),
                fontFamily: 'OtsutomeFont',
                fontWeight: FontWeight.bold,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
