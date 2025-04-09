import 'package:flutter/material.dart';
import 'dart:ui';
import '../common/image_button.dart';
import '../../utils/index.dart'; // 導入自適應佈局工具

// 隱私條款對話框
class PrivacyPolicyDialog extends StatelessWidget {
  final VoidCallback? onAgree;

  const PrivacyPolicyDialog({super.key, this.onAgree});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ), // 使用自適應圓角
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: EdgeInsets.all(20.r), // 使用自適應邊距
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20.r), // 使用自適應圓角
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 1,
                offset: Offset(0, 8.h),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                alignment: Alignment.center,
                child: Text(
                  '隱私條款',
                  style: TextStyle(
                    fontSize: 24.sp, // 使用自適應字體大小
                    color: const Color(0xFF23456B),
                    fontFamily: 'OtsutomeFont',
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 20.h), // 使用自適應高度
              // 使用 Flexible + SingleChildScrollView 處理長文字
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    '非常感謝您使用TUCKIN應用程式。我們十分重視您的隱私保護與個人資料安全。\n\n'
                    '• 我們僅收集必要的資訊以提供服務\n'
                    '• 您的個人資料不會被出售或分享給第三方\n'
                    '• 我們採用現代加密技術保護您的資料\n'
                    '• 您有權限查閱、更正或刪除您的個人資料\n\n'
                    '使用本應用即表示您同意我們的隱私政策條款。',
                    style: TextStyle(
                      fontSize: 16.sp, // 使用自適應字體大小
                      fontFamily: 'OtsutomeFont',
                      height: 1.4, // 進一步增加行高
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20.h), // 使用自適應高度
              // 使用自定義的 ImageButton 代替 ElevatedButton
              ImageButton(
                imagePath: 'assets/images/ui/button/blue_m.png',
                text: '我同意',
                width: 130.w, // 使用自適應寬度
                height: 65.h, // 使用自適應高度
                textStyle: TextStyle(
                  fontSize: 16.sp, // 使用自適應字體大小
                  color: const Color(0xFFD1D1D1),
                  fontFamily: 'OtsutomeFont',
                  fontWeight: FontWeight.bold,
                ),
                onPressed: () {
                  // 先調用同意回調
                  if (onAgree != null) {
                    onAgree!();
                  }
                  // 然後關閉對話框
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
