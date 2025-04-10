import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/utils/index.dart';

class LowAttendancePage extends StatefulWidget {
  const LowAttendancePage({super.key});

  @override
  State<LowAttendancePage> createState() => _LowAttendancePageState();
}

class _LowAttendancePageState extends State<LowAttendancePage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;
  bool _isProcessing = false; // 追蹤處理操作的狀態
  bool _isPageMounted = false; // 追蹤頁面是否完全掛載

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
    // 確保頁面完全渲染後才設置為掛載狀態
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isPageMounted = true;
        });
        debugPrint('LowAttendancePage 完全渲染');
      }
    });
  }

  @override
  void dispose() {
    _isPageMounted = false;
    super.dispose();
  }

  Future<void> _checkUserStatus() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final status = await _databaseService.getUserStatus(currentUser.id);
        if (status == 'low_attendance') {
          setState(() {
            _isLoading = false;
          });
        } else {
          debugPrint('用戶狀態不是團體出席率過低: $status，導向到適當頁面');
          setState(() {
            _isLoading = false;
          });

          // 根據用戶狀態導向到適當頁面
          if (mounted) {
            _navigationService.navigateToUserStatusPage(context);
          }
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('獲取用戶狀態出錯: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 處理「返回主頁」按鈕點擊
  Future<void> _handleReturnToHome() async {
    // 防誤觸邏輯：確保頁面已完全載入
    if (!_isPageMounted || _isLoading) {
      debugPrint('防止誤觸：頁面未完全掛載或載入中，操作被忽略');
      return;
    }

    try {
      setState(() {
        _isProcessing = true; // 開始處理，顯示loading
      });

      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // 更新用戶狀態為初始狀態
        await _databaseService.updateUserStatus(currentUser.id, 'initial');

        // 操作完成後跳轉到預約頁面
        if (mounted) {
          debugPrint('用戶確認團體出席率過低狀態，導向到預約頁面');
          _navigationService.navigateToDinnerReservation(context);
        }
      }
    } catch (e) {
      debugPrint('處理團體出席率過低時出錯: $e');
      setState(() {
        _isProcessing = false; // 出錯時恢復按鈕狀態
      });
      // 顯示錯誤訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '處理失敗: $e',
              style: TextStyle(fontSize: 15, fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 計算適當的陰影偏移量
    final adaptiveShadowOffset = 4.h;

    if (_isLoading) {
      return WillPopScope(
        onWillPop: () async {
          return false; // 禁用返回按鈕
        },
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background/bg1.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF23456B)),
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        return false; // 禁用返回按鈕
      },
      child: Scaffold(
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
                HeaderBar(title: ''),

                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 130.h),

                        // 提示文字
                        Center(
                          child: Text(
                            '聚餐已取消 (T_T)',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontFamily: 'OtsutomeFont',
                              color: const Color(0xFF23456B),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        SizedBox(height: 25.h),

                        // 圖示
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
                                    'assets/images/icon/low_rate.png',
                                    width: 150.w,
                                    height: 150.h,
                                    color: Colors.black.withOpacity(0.4),
                                    colorBlendMode: BlendMode.srcIn,
                                  ),
                                ),
                                // 主圖像
                                Image.asset(
                                  'assets/images/icon/low_rate.png',
                                  width: 150.w,
                                  height: 150.h,
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 35.h),

                        // 提示文字
                        Center(
                          child: Text(
                            '因出席率過低，聚餐已取消',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontFamily: 'OtsutomeFont',
                              color: const Color(0xFF23456B),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        // 將剩餘空間推到底部
                        SizedBox(height: 80.h),

                        // 按鈕或加載動畫
                        Center(
                          child:
                              _isProcessing
                                  ? LoadingImage(
                                    width: 60.w,
                                    height: 60.h,
                                    color: const Color(0xFF23456B),
                                  )
                                  : ImageButton(
                                    text: '返回首頁',
                                    imagePath:
                                        'assets/images/ui/button/blue_l.png',
                                    width: 160.w,
                                    height: 70.h,
                                    onPressed: () {
                                      // 防止頁面載入期間被點擊
                                      if (_isPageMounted && !_isLoading) {
                                        _handleReturnToHome();
                                      } else {
                                        debugPrint('頁面未完全掛載或載入中，忽略點擊事件');
                                      }
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
      ),
    );
  }
}
