import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart'; // 包含 NavigationService
import 'dart:async';
import 'package:tuckin/services/user_status_service.dart'; // <-- 引入 UserStatusService
import 'package:provider/provider.dart'; // <-- 引入 Provider

class AttendanceConfirmationPage extends StatefulWidget {
  const AttendanceConfirmationPage({super.key});

  @override
  State<AttendanceConfirmationPage> createState() =>
      _AttendanceConfirmationPageState();
}

class _AttendanceConfirmationPageState
    extends State<AttendanceConfirmationPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;
  bool _isConfirming = false; // 追蹤確認出席操作的狀態
  bool _isPageMounted = false; // 追蹤頁面是否完全掛載

  // 聚餐相關訊息
  DateTime? _dinnerTime;
  DateTime? _confirmDeadline;
  Duration _remainingTime = Duration.zero;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // 延遲加載，確保能獲取到路由參數
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isPageMounted = true;
        });
        debugPrint('AttendanceConfirmationPage 完全渲染');

        // 嘗試從路由參數獲取截止時間
        /* // <-- 移除從路由參數獲取 deadline 的邏輯
        final args =
            ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        if (args != null && args.containsKey('deadline')) {
          setState(() {
            _confirmDeadline = args['deadline'] as DateTime?;
          });
          debugPrint('從路由參數獲取截止時間: $_confirmDeadline');
        }
        */

        // 從 UserStatusService 獲取截止時間 (修改)
        final userStatusService = Provider.of<UserStatusService>(
          context,
          listen: false,
        );
        setState(() {
          _confirmDeadline = userStatusService.replyDeadline;
        });
        debugPrint('從 UserStatusService 獲取截止時間: $_confirmDeadline');

        // 加載聚餐信息
        _loadDinnerInfo();
      }
    });
  }

  @override
  void dispose() {
    _isPageMounted = false;
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDinnerInfo() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final status = await _databaseService.getUserStatus(currentUser.id);
        if (status != 'waiting_confirmation') {
          debugPrint('用戶狀態不是等待確認: $status，導向到適當頁面');
          _redirectBasedOnStatus(status);
          return;
        }

        // 若confirmDeadline仍為null（沒有從路由參數獲取到），設置一個默認值
        if (_confirmDeadline == null) {
          // 設定默認值（現在時間加上7小時）
          final DateTime now = DateTime.now();
          setState(() {
            _confirmDeadline = now.add(const Duration(hours: 7));
          });
          debugPrint('未從路由參數獲取到期限，使用默認值: $_confirmDeadline');
        }

        // 從 UserStatusService 獲取聚餐日期 (修改)
        final userStatusService = Provider.of<UserStatusService>(
          context,
          listen: false,
        );
        final DateTime? dinnerTime = userStatusService.confirmedDinnerTime;
        if (dinnerTime == null) {
          // 如果無法獲取時間，則記錄錯誤並使用預設值
          debugPrint(
            '警告：無法從 UserStatusService 獲取 confirmedDinnerTime，使用當前時間+1天',
          );
          final DateTime now = DateTime.now();
          _dinnerTime = now.add(const Duration(days: 1));
        } else {
          _dinnerTime = dinnerTime;
        }

        setState(() {
          _isLoading = false;
        });

        // 啟動倒數計時
        _startCountdown();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('獲取聚餐資訊出錯: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateRemainingTime();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    if (_confirmDeadline == null || !mounted) return;

    final now = DateTime.now();
    if (now.isBefore(_confirmDeadline!)) {
      setState(() {
        _remainingTime = _confirmDeadline!.difference(now);
      });
    } else {
      // 截止時間已過，但我們不處理截止邏輯，只更新剩餘時間為當前與截止時間的差值
      // 這樣即使截止時間已過，也會顯示剩餘時間（負值），確保按鈕始終可用
      setState(() {
        _remainingTime = _confirmDeadline!.difference(now);
      });
    }
  }

  // 將剩餘時間轉換為小時並四捨五入到小數點第一位
  String _formatRemainingHours() {
    final totalHours = _remainingTime.inSeconds / 3600;
    // 如果是負值（時間已過），顯示為正數
    final absoluteHours = totalHours.abs();
    return '倒數 ${absoluteHours.toStringAsFixed(1)} 小時';
  }

  void _redirectBasedOnStatus(String status) {
    if (!mounted) return;

    if (status == 'booking') {
      debugPrint('用戶處於預約階段，導向到預約頁面');
      _navigationService.navigateToDinnerReservation(context);
    } else if (status == 'waiting_matching') {
      // 修正方法名稱
      _navigationService.navigateToUserStatusPage(context);
    } else if (status == 'waiting_restaurant') {
      _navigationService.navigateToRestaurantSelection(context);
    } else if (status == 'waiting_other_users' ||
        status == 'waiting_attendance') {
      _navigationService.navigateToDinnerInfo(context);
    } else if (status == 'rating') {
      _navigationService.navigateToDinnerRating(context);
    } else {
      _navigationService.navigateToHome(context);
    }
  }

  Future<void> _handleConfirmAttendance() async {
    // 防誤觸邏輯：確保頁面已完全載入
    if (!_isPageMounted || _isLoading) {
      debugPrint('防止誤觸：頁面未完全掛載或載入中，確認操作被忽略');
      return;
    }

    try {
      // 先更新狀態以顯示loading
      setState(() {
        _isConfirming = true;
      });

      debugPrint('開始確認出席操作，顯示loading');

      // 添加足夠長的延遲以便觀察到loading效果
      await Future.delayed(const Duration(milliseconds: 500));

      // 確保頁面仍然掛載
      if (mounted) {
        debugPrint('用戶已確認出席，導向到餐廳選擇頁面');
        // 導航前再延遲一下，確保loading效果可見
        await Future.delayed(const Duration(milliseconds: 200));
        _navigationService.navigateToRestaurantSelection(context);
      }
    } catch (e) {
      debugPrint('確認出席時出錯: $e');
      // 確保頁面仍然掛載
      if (mounted) {
        setState(() {
          _isConfirming = false; // 出錯時恢復按鈕狀態
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '確認失敗: $e',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleCancelAttendance() async {
    // 防誤觸邏輯：確保頁面已完全載入
    if (!_isPageMounted || _isLoading) {
      debugPrint('防止誤觸：頁面未完全掛載或載入中，取消操作被忽略');
      return;
    }

    try {
      // 先更新狀態以顯示loading
      setState(() {
        _isConfirming = true;
      });

      debugPrint('開始取消出席操作，顯示loading');

      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        await _databaseService.updateUserStatus(currentUser.id, 'booking');
      }

      // 確保頁面仍然掛載
      if (mounted) {
        debugPrint('用戶已取消出席，導向到首頁');
        // 導航前再延遲一下，確保loading效果可見
        await Future.delayed(const Duration(milliseconds: 200));
        _navigationService.navigateToHome(context);
      }
    } catch (e) {
      debugPrint('取消出席時出錯: $e');
      // 確保頁面仍然掛載
      if (mounted) {
        setState(() {
          _isConfirming = false; // 出錯時恢復按鈕狀態
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '取消失敗: $e',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
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

    // 格式化聚餐時間
    final dinnerTimeFormatted =
        _dinnerTime != null
            ? '${_dinnerTime!.year}年${_dinnerTime!.month}月${_dinnerTime!.day}日 ${_dinnerTime!.hour}:${_dinnerTime!.minute.toString().padLeft(2, '0')}'
            : '時間待定';

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
                        SizedBox(height: 60.h),

                        // 提示文字
                        Center(
                          child: Text(
                            '找到了！',
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

                        SizedBox(height: 35.h),

                        // 聚餐時間顯示
                        Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 15.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
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
                                Text(
                                  '聚餐時間',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFF23456B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  dinnerTimeFormatted,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFF23456B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 將剩餘空間推到底部
                        SizedBox(height: 70.h),

                        // 確認出席和無法出席按鈕
                        Center(
                          child:
                              _isConfirming
                                  ? Container(
                                    width: 160.w,
                                    height: 75.h,
                                    alignment: Alignment.center,
                                    child: LoadingImage(
                                      width: 60.w,
                                      height: 60.h,
                                    ),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // 無法出席按鈕
                                      ImageButton(
                                        text: '無法出席',
                                        imagePath:
                                            'assets/images/ui/button/blue_m.png',
                                        width: 150.w,
                                        height: 72.h,
                                        textStyle: TextStyle(
                                          fontSize: 18.sp,
                                          color: const Color(0xFFD1D1D1),
                                          fontFamily: 'OtsutomeFont',
                                          fontWeight: FontWeight.bold,
                                        ),
                                        onPressed: () {
                                          // 防止頁面載入期間被點擊
                                          if (_isPageMounted && !_isLoading) {
                                            _handleCancelAttendance();
                                          } else {
                                            debugPrint('頁面未完全掛載或載入中，忽略點擊事件');
                                          }
                                        },
                                      ),

                                      SizedBox(width: 15.w),

                                      // 確認出席按鈕
                                      ImageButtonWithCountdown(
                                        text: '確認出席',
                                        textStyle: TextStyle(
                                          fontSize: 18.sp,
                                          color: const Color(0xFFD1D1D1),
                                          fontFamily: 'OtsutomeFont',
                                          fontWeight: FontWeight.bold,
                                        ),
                                        countdownText: _formatRemainingHours(),
                                        imagePath:
                                            'assets/images/ui/button/red_l.png',
                                        width: 150.w,
                                        height: 70.h,
                                        countdownTextStyle: TextStyle(
                                          fontSize: 11.sp,
                                          color: const Color(0xFFFFD9B3),
                                          fontFamily: 'OtsutomeFont',
                                          fontWeight: FontWeight.bold,
                                        ),
                                        onPressed: () {
                                          // 防止頁面載入期間被點擊
                                          if (_isPageMounted && !_isLoading) {
                                            _handleConfirmAttendance();
                                          } else {
                                            debugPrint('頁面未完全掛載或載入中，忽略點擊事件');
                                          }
                                        },
                                      ),
                                    ],
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
