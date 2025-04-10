import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/utils/index.dart';
import 'dart:async';

class MatchingStatusPage extends StatefulWidget {
  const MatchingStatusPage({super.key});

  @override
  State<MatchingStatusPage> createState() => _MatchingStatusPageState();
}

class _MatchingStatusPageState extends State<MatchingStatusPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;
  bool _isCancelling = false; // 追蹤取消預約操作的狀態
  String _userStatus = 'waiting_matching'; // 預設為等待配對狀態
  bool _isPageMounted = false; // 追蹤頁面是否完全掛載

  @override
  void initState() {
    super.initState();
    _loadUserStatus();
    // 使用延遲來確保頁面完全渲染後才設置為掛載狀態
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isPageMounted = true;
        });
        debugPrint('MatchingStatusPage 完全渲染');
      }
    });
  }

  @override
  void dispose() {
    _isPageMounted = false;
    super.dispose();
  }

  Future<void> _loadUserStatus() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final status = await _databaseService.getUserStatus(currentUser.id);
        // 只有當狀態是 waiting_matching 或 matching_failed 時才更新狀態
        if (status == 'waiting_matching' || status == 'matching_failed') {
          setState(() {
            _userStatus = status;
            _isLoading = false;
          });
        } else {
          debugPrint('用戶狀態不是等待配對或配對失敗: $status，導向到適當頁面');
          setState(() {
            _isLoading = false;
          });

          // 根據用戶狀態導向到適當頁面
          if (mounted) {
            if (status == 'booking') {
              debugPrint('用戶處於預約階段，導向到預約頁面');
              _navigationService.navigateToDinnerReservation(context);
            } else if (status == 'waiting_confirmation') {
              _navigationService.navigateToAttendanceConfirmation(context);
            } else if (status == 'waiting_restaurant') {
              _navigationService.navigateToRestaurantSelection(context);
            } else if (status == 'waiting_dinner') {
              _navigationService.navigateToDinnerInfo(context);
            } else if (status == 'rating') {
              _navigationService.navigateToDinnerRating(context);
            } else {
              _navigationService.navigateToHome(context);
            }
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

  Future<void> _handleCancelReservation() async {
    // 防誤觸邏輯：確保頁面已完全載入並且用戶狀態為預期狀態
    if (!_isPageMounted ||
        _isLoading ||
        !(_userStatus == 'waiting_matching' ||
            _userStatus == 'matching_failed')) {
      debugPrint('防止誤觸：頁面未完全掛載或載入中或用戶狀態不正確，取消操作被忽略');
      return;
    }

    try {
      setState(() {
        _isCancelling = true; // 開始取消操作，顯示loading
      });

      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // 更新用戶狀態為預約階段
        await _databaseService.updateUserStatus(currentUser.id, 'booking');

        // 操作完成後跳轉到預約頁面
        if (mounted) {
          debugPrint('用戶主動取消預約，導向到預約頁面');
          _navigationService.navigateToDinnerReservation(context);
        }
      }
    } catch (e) {
      debugPrint('取消預約時出錯: $e');
      setState(() {
        _isCancelling = false; // 出錯時恢復按鈕狀態
      });
      // 顯示錯誤訊息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '取消失敗: $e',
              style: TextStyle(fontSize: 15, fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  // 在通知圖標點擊處理函數中使用導航服務
  void _handleNotificationTap() {
    _navigationService.navigateToNotifications(context);
  }

  // 處理用戶頭像點擊
  void _handleProfileTap() {
    _navigationService.navigateToProfile(context);
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

                        // 提示文字 - 根據用戶狀態顯示不同的文字
                        Center(
                          child: Text(
                            _userStatus == 'matching_failed'
                                ? '很抱歉 <(__)>'
                                : '預約成功！',
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

                        // 圖示 - 根據用戶狀態顯示不同的圖示
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
                                    _userStatus == 'matching_failed'
                                        ? 'assets/images/icon/sorry.png'
                                        : 'assets/images/icon/notification.png',
                                    width: 150.w,
                                    height: 150.h,
                                    color: Colors.black.withOpacity(0.4),
                                    colorBlendMode: BlendMode.srcIn,
                                  ),
                                ),
                                // 主圖像
                                Image.asset(
                                  _userStatus == 'matching_failed'
                                      ? 'assets/images/icon/sorry.png'
                                      : 'assets/images/icon/notification.png',
                                  width: 150.w,
                                  height: 150.h,
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 35.h),

                        // 提示文字 - 根據用戶狀態顯示不同的文字
                        Center(
                          child: Text(
                            _userStatus == 'matching_failed'
                                ? '沒有找到一起吃飯的朋友'
                                : '找到再跟你說',
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

                        // 取消預約按鈕或加載動畫
                        Center(
                          child:
                              _isCancelling
                                  ? LoadingImage(
                                    width: 60.w,
                                    height: 60.h,
                                    color: const Color(0xFF23456B),
                                  )
                                  : ImageButton(
                                    text:
                                        _userStatus == 'matching_failed'
                                            ? '預約下次'
                                            : '取消預約',
                                    imagePath:
                                        'assets/images/ui/button/blue_l.png',
                                    width: 160.w,
                                    height: 70.h,
                                    onPressed: () {
                                      // 防止頁面載入期間被點擊
                                      if (_isPageMounted && !_isLoading) {
                                        _handleCancelReservation();
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
