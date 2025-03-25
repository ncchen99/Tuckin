import 'package:flutter/material.dart';
import 'package:tuckin/utils/index.dart';

/// 通用頂部導航欄
/// 包含用戶頭像圖標
/// 顯示品牌標誌
class HeaderBar extends StatefulWidget {
  final String title; // 保留參數但不再使用
  final VoidCallback? onProfileTap;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final VoidCallback? onBrandTap; // 新增品牌點擊事件

  const HeaderBar({
    super.key,
    this.title = '',
    this.onProfileTap,
    this.showBackButton = false,
    this.onBackPressed,
    this.onBrandTap,
  });

  @override
  State<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends State<HeaderBar> {
  bool _isBrandPressed = false;
  bool _isProfilePressed = false;

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
          widget.showBackButton
              ? GestureDetector(
                onTap:
                    widget.onBackPressed ?? () => Navigator.of(context).pop(),
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

          // 右側：個人資料圖標
          _buildProfileButton(
            'assets/images/icon/user_profile.png',
            widget.onProfileTap,
            adaptiveShadowOffset,
          ),
        ],
      ),
    );
  }

  // 品牌標誌組件 - 添加互動效果
  Widget _buildBrandLogo(double shadowOffset) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isBrandPressed = true),
      onTapUp: (_) {
        setState(() => _isBrandPressed = false);
        if (widget.onBrandTap != null) widget.onBrandTap!();
      },
      onTapCancel: () => setState(() => _isBrandPressed = false),
      child: SizedBox(
        height: 34.h,
        width: 130.w,
        child: Stack(
          alignment: Alignment.topLeft,
          clipBehavior: Clip.none,
          children: [
            // 底部陰影層
            if (!_isBrandPressed)
              Positioned(
                top: shadowOffset,
                left: 0,
                child: Image.asset(
                  'assets/images/icon/tuckin_t_brand.png',
                  height: 34.h,
                  fit: BoxFit.contain,
                  color: Colors.black.withValues(alpha: .4),
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            // 主圖層
            Positioned(
              top: _isBrandPressed ? shadowOffset : 0,
              left: 0,
              child: Image.asset(
                'assets/images/icon/tuckin_t_brand.png',
                height: 34.h,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 創建帶陰影的頭像按鈕
  Widget _buildProfileButton(
    String iconPath,
    VoidCallback? onTap,
    double shadowOffset,
  ) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isProfilePressed = true),
      onTapUp: (_) {
        setState(() => _isProfilePressed = false);
        if (onTap != null) onTap();
      },
      onTapCancel: () => setState(() => _isProfilePressed = false),
      child: SizedBox(
        width: 40.w,
        height: 40.h,
        child: Stack(
          clipBehavior: Clip.none, // 允許子元素超出父容器邊界，解決陰影被裁剪問題
          children: [
            // 底部陰影
            if (!_isProfilePressed)
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
              top: _isProfilePressed ? shadowOffset : 0,
              left: 0,
              child: Image.asset(iconPath, width: 40.w, height: 40.h),
            ),
          ],
        ),
      ),
    );
  }
}
