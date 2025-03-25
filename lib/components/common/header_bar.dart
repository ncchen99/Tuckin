import 'package:flutter/material.dart';
import 'package:tuckin/utils/index.dart';

/// 通用頂部導航欄
/// 包含通知鈴鐺圖標和用戶頭像圖標
/// 顯示品牌標誌
class HeaderBar extends StatelessWidget {
  final String title; // 保留參數但不再使用
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const HeaderBar({
    super.key,
    this.title = '',
    this.onNotificationTap,
    this.onProfileTap,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    // 計算適當的陰影偏移量
    final adaptiveShadowOffset = 3.h;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左側：返回按鈕或品牌標誌
          showBackButton
              ? GestureDetector(
                onTap: onBackPressed ?? () => Navigator.of(context).pop(),
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(
                      color: const Color(0xFF23456B),
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.arrow_back, color: Color(0xFF23456B)),
                ),
              )
              : _buildBrandLogo(adaptiveShadowOffset),

          // 右側：通知與個人資料圖標
          Row(
            children: [
              // 通知鈴鐺
              _buildIconButton(
                'assets/images/icon/notification.png',
                onNotificationTap,
                adaptiveShadowOffset,
              ),
              SizedBox(width: 15.w),
              // 用戶頭像
              _buildIconButton(
                'assets/images/icon/user_profile.png',
                onProfileTap,
                adaptiveShadowOffset,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 品牌標誌組件
  Widget _buildBrandLogo(double shadowOffset) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 底部陰影層
        Positioned(
          top: shadowOffset,
          child: Image.asset(
            'assets/images/icon/tuckin_t_brand.png',
            height: 34.h,
            fit: BoxFit.contain,
            color: Colors.black.withValues(alpha: .4),
            colorBlendMode: BlendMode.srcIn,
          ),
        ),
        // 主圖層
        Image.asset(
          'assets/images/icon/tuckin_t_brand.png',
          height: 34.h,
          fit: BoxFit.contain,
        ),
      ],
    );
  }

  // 創建帶陰影的圖標按鈕 (無背景版本)
  Widget _buildIconButton(
    String iconPath,
    VoidCallback? onTap,
    double shadowOffset,
  ) {
    // 使用StatefulBuilder以便實現按下效果
    return StatefulBuilder(
      builder: (context, setState) {
        bool isPressed = false;

        return GestureDetector(
          onTapDown: (_) => setState(() => isPressed = true),
          onTapUp: (_) {
            setState(() => isPressed = false);
            if (onTap != null) onTap();
          },
          onTapCancel: () => setState(() => isPressed = false),
          child: SizedBox(
            width: 40.w,
            height: 40.h,
            child: Stack(
              clipBehavior: Clip.none, // 允許子元素超出父容器邊界，解決陰影被裁剪問題
              children: [
                // 底部陰影
                if (!isPressed)
                  Positioned(
                    left: 0,
                    top: shadowOffset,
                    child: Image.asset(
                      iconPath,
                      width: 40.w,
                      height: 40.h,
                      color: Colors.black.withValues(alpha: .4),
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                // 主圖像
                Positioned(
                  top: isPressed ? shadowOffset : 0,
                  left: 0,
                  child: Image.asset(iconPath, width: 40.w, height: 40.h),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
