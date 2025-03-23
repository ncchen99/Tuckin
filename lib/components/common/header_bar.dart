import 'package:flutter/material.dart';
import 'package:tuckin/utils/index.dart';

/// 通用頂部導航欄
/// 包含通知鈴鐺圖標和用戶頭像圖標
/// 可以顯示頁面標題
class HeaderBar extends StatelessWidget {
  final String title;
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左側：返回按鈕或空
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
              : title.isNotEmpty
              ? Text(
                title,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color(0xFF23456B),
                  fontWeight: FontWeight.bold,
                ),
              )
              : const SizedBox.shrink(),

          // 右側：通知與個人資料圖標
          Row(
            children: [
              // 通知鈴鐺
              GestureDetector(
                onTap: onNotificationTap,
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(
                      color: const Color(0xFF23456B),
                      width: 2,
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/icon/notification.png',
                    width: 24.w,
                    height: 24.h,
                  ),
                ),
              ),
              SizedBox(width: 15.w),
              // 用戶頭像
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(
                      color: const Color(0xFF23456B),
                      width: 2,
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/icon/user_profile.png',
                    width: 24.w,
                    height: 24.h,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
