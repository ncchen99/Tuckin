import 'package:flutter/material.dart';
import '../common/image_button.dart';

/// 自定義 Apple 登入按鈕組件
///
/// 這個組件基於現有的 [ImageButton] 創建，僅在 iOS 設備上顯示，使用圖片按鈕不含文字
///
/// 使用示例:
/// ```dart
/// AppleSignInButton(
///   width: 240.w,
///   height: 70.h,
///   enabled: true,
///   onPressed: () {
///     // 處理登入邏輯
///   },
/// )
/// ```
///
/// [onPressed] 當按鈕被點擊時的回調函數
/// [width] 按鈕寬度，預設為 250
/// [height] 按鈕高度，預設為 80
/// [enabled] 按鈕是否啟用，為 false 時按鈕將顯示為灰色且無法點擊
class AppleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double width;
  final double height;
  final bool enabled;

  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.width = 160,
    this.height = 70,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // 使用 ImageButton 的 isEnabled 參數實現完全禁用功能
    return ImageButton(
      imagePath: 'assets/images/ui/button/apple_m.webp',
      text: '', // 移除文字
      width: width,
      height: height,
      onPressed: onPressed,
      // 使用新的 isEnabled 參數，完全禁止點擊
      isEnabled: enabled,
    );
  }
}
