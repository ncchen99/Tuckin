import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 簡化為使用導航服務檢查用戶狀態
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    if (!mounted) return;

    try {
      // 只使用導航服務檢查並導航到適當的頁面
      await _navigationService.navigateToUserStatusPage(context);

      // 如果導航服務決定留在主頁，則更新加載狀態
      if (mounted && ModalRoute.of(context)?.settings.name == '/home') {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('檢查用戶狀態出錯: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false; // 禁用返回按鈕
      },
      child: Scaffold(
        body:
            _isLoading
                ? Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/background/bg1.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF23456B)),
                  ),
                )
                : Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/background/bg1.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 25.h, bottom: 50.h),
                          child: Image.asset(
                            'assets/images/icon/tuckin_t_brand.png',
                            width: 140.w,
                          ),
                        ),
                        SizedBox(height: 150.h),
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
                                  '歡迎使用Tuckin',
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFF23456B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  '每次相遇都是生命中的美好\n現在就點擊預約吧！',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFF23456B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),

                        Expanded(child: Container()),

                        // 主循環核心功能按鈕
                        Column(
                          children: [
                            ImageButton(
                              text: '預約',
                              imagePath: 'assets/images/ui/button/red_l.png',
                              width: 180.w,
                              height: 75.h,
                              onPressed: () async {
                                final currentUser =
                                    await _authService.getCurrentUser();
                                if (currentUser != null) {
                                  final databaseService = DatabaseService();
                                  await databaseService.updateUserStatus(
                                    currentUser.id,
                                    'booking',
                                  );
                                }
                                Navigator.of(
                                  context,
                                ).pushNamed('/dinner_reservation');
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 60.h),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
