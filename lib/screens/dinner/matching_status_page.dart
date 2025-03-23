import 'package:flutter/material.dart';
import 'package:tuckin/components/common/header_bar.dart';
import 'package:tuckin/components/common/image_button.dart';
import 'package:tuckin/utils/index.dart';

class MatchingStatusPage extends StatelessWidget {
  const MatchingStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 計算適當的陰影偏移量
    final adaptiveShadowOffset = 3.h;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background/bg1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 頂部導航欄
              HeaderBar(
                title: '',
                onNotificationTap: () {
                  // 導航到通知頁面
                  Navigator.pushNamed(context, '/notifications');
                },
                onProfileTap: () {
                  // 導航到個人資料頁面
                  Navigator.pushNamed(context, '/user_settings');
                },
              ),

              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 150.h),

                      // 匹配圖示（使用陰影效果，參考HeaderBar）
                      Center(
                        child: SizedBox(
                          width: 150.w,
                          height: 150.h,
                          child: Stack(
                            clipBehavior: Clip.none, // 允許陰影超出容器範圍
                            children: [
                              // 底部陰影
                              Positioned(
                                left: 0,
                                top: adaptiveShadowOffset,
                                child: Image.asset(
                                  'assets/images/icon/match.png',
                                  width: 150.w,
                                  height: 150.h,
                                  color: Colors.black.withOpacity(0.4),
                                  colorBlendMode: BlendMode.srcIn,
                                ),
                              ),
                              // 主圖像
                              Image.asset(
                                'assets/images/icon/match.png',
                                width: 150.w,
                                height: 150.h,
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 30.h),

                      // 提示文字
                      Center(
                        child: Text(
                          '組合成功會跟你說！',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontFamily: 'OtsutomeFont',
                            color: const Color(0xFF23456B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // 將剩餘空間推到底部
                      SizedBox(height: 80.h),

                      // 取消預約按鈕 (使用ImageButton組件)
                      Center(
                        child: ImageButton(
                          text: '取消預約',
                          imagePath: 'assets/images/ui/button/blue_l.png',
                          width: 160.w,
                          height: 68.h,
                          onPressed: () {
                            // 返回預約頁面
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const Spacer(),

                      SizedBox(height: 30.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
