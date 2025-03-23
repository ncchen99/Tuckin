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
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserStatusAndNavigate();
  }

  Future<void> _checkUserStatusAndNavigate() async {
    if (!mounted) return;

    try {
      // 獲取當前用戶
      final currentUser = _authService.getCurrentUser();
      if (currentUser == null) {
        // 用戶未登入，留在主頁
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 獲取用戶狀態
      final userStatus = await _databaseService.getUserStatus(currentUser.id);

      if (!mounted) return;

      // 根據用戶狀態導航到相應頁面
      switch (userStatus) {
        case 'booking':
          // 聚餐預約狀態 -> 聚餐預約頁面
          Navigator.of(context).pushReplacementNamed('/dinner_reservation');
          break;
        case 'waiting_matching':
          // 等待配對狀態 -> 配對狀態頁面
          Navigator.of(context).pushReplacementNamed('/matching_status');
          break;
        case 'waiting_confirmation':
          // 等待確認狀態 -> 出席確認頁面
          Navigator.of(
            context,
          ).pushReplacementNamed('/attendance_confirmation');
          break;
        case 'waiting_restaurant':
          // 等待餐廳狀態 -> 餐廳選擇頁面
          Navigator.of(context).pushReplacementNamed('/restaurant_selection');
          break;
        case 'waiting_dinner':
          // 等待聚餐狀態 -> 聚餐資訊頁面
          Navigator.of(context).pushReplacementNamed('/dinner_info');
          break;
        case 'rating':
          // 評分狀態 -> 評分頁面
          Navigator.of(context).pushReplacementNamed('/dinner_rating');
          break;
        case 'initial':
        default:
          // 初始狀態或其他狀態，保持在主頁
          setState(() {
            _isLoading = false;
          });
          break;
      }
    } catch (e) {
      debugPrint('獲取用戶狀態出錯: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        padding: EdgeInsets.only(top: 50.h, bottom: 50.h),
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

                      SizedBox(height: 100.h),

                      // 主循環核心功能按鈕
                      Column(
                        children: [
                          ImageButton(
                            text: '預約',
                            imagePath: 'assets/images/ui/button/red_l.png',
                            width: 180.w,
                            height: 85.h,
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pushNamed('/dinner_reservation');
                            },
                          ),
                        ],
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
