import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/utils/index.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
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
              Padding(
                padding: EdgeInsets.only(top: 50.h, bottom: 20.h),
                child: Image.asset(
                  'assets/images/icon/tuckin_t_brand.png',
                  width: 150.w,
                ),
              ),

              // 歡迎訊息
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15.r),
                    border: Border.all(
                      color: const Color(0xFF23456B),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '設定完成！',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontFamily: 'OtsutomeFont',
                          color: const Color(0xFF23456B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        '感謝您完成所有設定！\n您現在可以開始使用 Tuckin 了！',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontFamily: 'OtsutomeFont',
                          color: const Color(0xFF23456B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20.h),
                      ImageButton(
                        text: '開始探索',
                        imagePath: 'assets/images/ui/button/blue_l.png',
                        width: 150.w,
                        height: 75.h,
                        onPressed: () {
                          // TODO: 實現主功能頁面導航
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('即將推出更多功能，敬請期待！')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(child: Container()),

              // 登出按鈕
              Padding(
                padding: EdgeInsets.only(bottom: 30.h),
                child: ImageButton(
                  text: '登出',
                  imagePath: 'assets/images/ui/button/blue_m.png',
                  width: 120.w,
                  height: 60.h,
                  onPressed: () async {
                    await _authService.signOut();
                    if (mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
