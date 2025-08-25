import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/utils/index.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuckin/services/notification_service.dart';

import 'package:provider/provider.dart';
import 'package:tuckin/services/user_status_service.dart';

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
            } else if (status == 'waiting_restaurant') {
              _navigationService.navigateToRestaurantSelection(context);
            } else if (status == 'waiting_attendance') {
              _navigationService.navigateToDinnerInfoAttendance(context);
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

      // 取消排程的提醒通知
      await _cancelDinnerReminderNotification();

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
            backgroundColor: const Color(0xFFB33D1C), // 深橘色背景
            content: Text(
              '取消失敗: $e',
              style: const TextStyle(
                fontFamily: 'OtsutomeFont',
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    }
  }

  // 取消排程的提醒通知
  Future<void> _cancelDinnerReminderNotification() async {
    try {
      // 從 SharedPreferences 取得通知 ID
      final prefs = await SharedPreferences.getInstance();
      final notificationId = prefs.getInt('dinner_reminder_notification_id');

      if (notificationId != null) {
        debugPrint('取消聚餐提醒通知，ID: $notificationId');

        // 使用 NotificationService 取消通知
        await NotificationService().cancelNotification(notificationId);

        // 清除存儲的通知 ID
        await prefs.remove('dinner_reminder_notification_id');

        debugPrint('聚餐提醒通知已成功取消');
      } else {
        debugPrint('沒有找到要取消的聚餐提醒通知ID');
      }
    } catch (e) {
      debugPrint('取消聚餐提醒通知時出錯: $e');
    }
  }

  // 構建預約成功卡片
  Widget _buildSuccessCard() {
    // 計算適當的陰影偏移量
    final adaptiveShadowOffset = 3.h;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: 30.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        children: [
          // 圖片及陰影（參考dinner_reservation_page的設計）
          SizedBox(
            width: 70.w,
            height: 70.h,
            child: Stack(
              clipBehavior: Clip.none, // 允許陰影超出容器範圍
              children: [
                // 底部陰影
                Positioned(
                  left: 0,
                  top: adaptiveShadowOffset,
                  child: Image.asset(
                    'assets/images/icon/notification.webp',
                    width: 70.w,
                    height: 70.h,
                    color: Colors.black.withOpacity(0.4),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
                // 主圖像
                Image.asset(
                  'assets/images/icon/notification.webp',
                  width: 70.w,
                  height: 70.h,
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // 星期幾文字（使用 UserStatusService）
          Consumer<UserStatusService>(
            builder: (context, userStatusService, child) {
              return Text(
                userStatusService.weekdayText,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color(0xFF23456B),
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),

          SizedBox(height: 8.h),

          // 聚餐日期顯示（使用 UserStatusService）
          Consumer<UserStatusService>(
            builder: (context, userStatusService, child) {
              return Text(
                userStatusService.formattedDinnerDate,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color(0xFF23456B),
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),

          SizedBox(height: 8.h),

          // 聚餐時間顯示（使用 UserStatusService）
          Consumer<UserStatusService>(
            builder: (context, userStatusService, child) {
              return Text(
                userStatusService.formattedDinnerTimeOnly,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color(0xFF23456B),
                ),
              );
            },
          ),

          SizedBox(height: 20.h),

          // 分隔線
          Container(
            height: 1,
            color: Colors.grey[300],
            margin: EdgeInsets.symmetric(horizontal: 15.w),
          ),

          SizedBox(height: 20.h),

          // 取消截止時間資訊（使用 UserStatusService）
          Consumer<UserStatusService>(
            builder: (context, userStatusService, child) {
              return Text(
                userStatusService.cancelDeadlineDescription,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color(0xFF666666),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),

          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  // 構建配對失敗的原始界面
  Widget _buildFailedInterface() {
    // 計算適當的陰影偏移量
    final adaptiveShadowOffset = 4.h;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 100.h),

        // 提示文字
        Center(
          child: Text(
            '很抱歉 <(__)>',
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
                    'assets/images/icon/sorry.webp',
                    width: 150.w,
                    height: 150.h,
                    color: Colors.black.withOpacity(0.4),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
                // 主圖像
                Image.asset(
                  'assets/images/icon/sorry.webp',
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
            '沒有找到一起吃飯的朋友',
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

        // 預約下次按鈕
        Center(
          child:
              _isCancelling
                  ? LoadingImage(
                    width: 60.w,
                    height: 60.h,
                    color: const Color(0xFF23456B),
                  )
                  : ImageButton(
                    text: '預約下次',
                    imagePath: 'assets/images/ui/button/blue_l.webp',
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return WillPopScope(
        onWillPop: () async {
          return false; // 禁用返回按鈕
        },
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background/bg2.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: LoadingImage(
                width: 60.w,
                height: 60.h,
                color: const Color(0xFF23456B),
              ),
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
              image: AssetImage('assets/images/background/bg2.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 頂部導航欄
                HeaderBar(title: ''),

                Expanded(
                  child:
                      _userStatus == 'waiting_matching'
                          ? // 預約成功的新界面設計
                          SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 20.h),

                                  // 標題在左上角
                                  Text(
                                    '預約成功！',
                                    style: TextStyle(
                                      fontSize: 24.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  SizedBox(height: 30.h),

                                  // 預約成功卡片
                                  _buildSuccessCard(),

                                  SizedBox(height: 60.h),

                                  // 取消預約按鈕
                                  Center(
                                    child:
                                        _isCancelling
                                            ? LoadingImage(
                                              width: 60.w,
                                              height: 60.h,
                                              color: const Color(0xFF23456B),
                                            )
                                            : ImageButton(
                                              text: '取消預約',
                                              imagePath:
                                                  'assets/images/ui/button/blue_l.webp',
                                              width: 160.w,
                                              height: 70.h,
                                              onPressed: () {
                                                // 防止頁面載入期間被點擊
                                                if (_isPageMounted &&
                                                    !_isLoading) {
                                                  _handleCancelReservation();
                                                } else {
                                                  debugPrint(
                                                    '頁面未完全掛載或載入中，忽略點擊事件',
                                                  );
                                                }
                                              },
                                            ),
                                  ),

                                  SizedBox(height: 30.h),
                                ],
                              ),
                            ),
                          )
                          : // 配對失敗的原始界面
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            child: _buildFailedInterface(),
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
