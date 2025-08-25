import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/utils/index.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:tuckin/services/user_status_service.dart';
import 'package:provider/provider.dart';
import 'package:tuckin/services/time_service.dart';

class DinnerReservationPage extends StatefulWidget {
  const DinnerReservationPage({super.key});

  @override
  State<DinnerReservationPage> createState() => _DinnerReservationPageState();
}

class _DinnerReservationPageState extends State<DinnerReservationPage> {
  // 是否僅限成大學生參與
  bool _onlyNckuStudents = true;
  // 控制提示框顯示
  bool _showWelcomeTip = false;
  // 是否為新用戶
  bool _isNewUser = false;
  // 操作進行中
  bool _isProcessing = false;
  // 是否為校內email
  bool _isSchoolEmail = false;
  // 添加服務
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  String _username = ''; // 用戶名稱
  // 已移除本地時間計算與整點更新計時器，改由 UserStatusService 統一處理

  // 按鈕文字
  String _buttonText = '預約';
  // 整點更新計時器
  Timer? _hourlyTimer;

  @override
  void initState() {
    super.initState();
    _checkIfNewUser();
    // 初始化時由 UserStatusService 統一更新聚餐時間
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final userStatusService = Provider.of<UserStatusService>(
        context,
        listen: false,
      );
      userStatusService.updateDinnerTimeByUserStatus();
    });
    _loadUserPreferences();
    _checkUserEmail();
    _scheduleHourlyUpdate(); // 啟動整點更新計時器
  }

  // 檢查用戶email是否為校內email
  Future<void> _checkUserEmail() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null && currentUser.email != null) {
        setState(() {
          _isSchoolEmail = _authService.isNCKUEmail(currentUser.email);
        });
      }
    } catch (error) {
      debugPrint('檢查用戶Email錯誤: $error');
    }
  }

  // 安排下一次整點更新，並在整點時由 UserStatusService 更新聚餐時間
  void _scheduleHourlyUpdate() {
    final now = TimeService().now();
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final durationUntilNextHour = nextHour.difference(now);

    _hourlyTimer?.cancel();
    _hourlyTimer = Timer(durationUntilNextHour, () async {
      if (!mounted) return;
      debugPrint('整點觸發：由 UserStatusService 更新聚餐時間');
      final userStatusService = Provider.of<UserStatusService>(
        context,
        listen: false,
      );
      userStatusService.updateDinnerTimeByUserStatus();
      _scheduleHourlyUpdate();
    });
    debugPrint(
      '已安排下次整點更新於: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(nextHour)} (延遲: ${durationUntilNextHour.inMinutes} 分鐘)',
    );
  }

  // 說明文字改由 Consumer 動態取得，不再在本地狀態中維護

  // 從資料庫加載用戶的配對偏好
  Future<void> _loadUserPreferences() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final preferSchoolOnly = await _databaseService
            .getUserMatchingPreference(currentUser.id);
        setState(() {
          _onlyNckuStudents = preferSchoolOnly ?? false;
        });
      }
    } catch (error) {
      debugPrint('加載用戶配對偏好錯誤: $error');
    }
  }

  // 檢查是否為新用戶
  Future<void> _checkIfNewUser() async {
    try {
      // 檢查 SharedPreferences 中的新用戶標誌
      final prefs = await SharedPreferences.getInstance();
      final isNewUser = prefs.getBool('is_new_user') ?? false;

      if (isNewUser) {
        // 獲取當前用戶
        final currentUser = await _authService.getCurrentUser();
        if (currentUser != null) {
          // 獲取用戶資料
          final userData = await _databaseService.getUserProfile(
            currentUser.id,
          );
          if (userData != null && userData.isNotEmpty) {
            setState(() {
              _username = userData['nickname'] ?? ''; // 獲取用戶暱稱
              _isNewUser = true;
              _showWelcomeTip = true;
            });

            // 清除新用戶標誌，這樣下次就不會顯示歡迎提示了
            await prefs.setBool('is_new_user', false);

            // 5秒後自動隱藏提示
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() {
                  _showWelcomeTip = false;
                });
              }
            });
          }
        }
      }
    } catch (error) {
      debugPrint('檢查新用戶狀態錯誤: $error');
    }
  }

  // 導航到匹配狀態頁面
  Future<void> _navigateToMatchingStatus() async {
    // 使用 NavigationService 導航到匹配狀態頁面
    _navigationService.navigateToUserStatusPage(context);
  }

  // 處理用戶配對偏好切換
  void _handlePreferenceChange(bool? value) {
    if (value != null) {
      setState(() {
        _onlyNckuStudents = value;
      });
    }
  }

  // 處理按鈕點擊事件
  Future<void> _handleButtonClick() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('用戶未登入');
      }

      // 已移除：由元件更新聚餐時間，統一改由 UserStatusService 控管

      // 無論是哪種階段，都使用相同的預約邏輯
      // 儲存用戶的配對偏好
      await _databaseService.updateUserMatchingPreference(
        currentUser.id,
        _isSchoolEmail ? _onlyNckuStudents : false,
      );

      // 更新用戶狀態為等待配對階段
      await _databaseService.updateUserStatus(
        currentUser.id,
        'waiting_matching',
      );

      // 排程聚餐提醒通知 - 在取消期限前12小時提醒
      await _scheduleDinnerReminder();

      // 延遲一下導航到配對狀態頁面
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 100));
      await _navigateToMatchingStatus();
    } catch (e) {
      debugPrint('預約時出錯: $e');
      // 出錯時恢復狀態
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '預約失敗: $e',
              style: TextStyle(fontSize: 15, fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  // 排程聚餐提醒通知
  Future<void> _scheduleDinnerReminder() async {
    try {
      final userStatusService = Provider.of<UserStatusService>(
        context,
        listen: false,
      );
      // 確保取消截止時間存在
      if (userStatusService.cancelDeadline == null) {
        debugPrint('無法設置提醒通知：取消截止時間未定義');
        return;
      }

      // 計算提醒時間（取消截止時間前12小時）
      DateTime reminderTime = userStatusService.cancelDeadline!.subtract(
        const Duration(hours: 12),
      );
      final DateTime now = TimeService().now();

      // 如果提醒時間已經過去，則使用當前時間和取消截止時間的中間點
      if (reminderTime.isBefore(now)) {
        debugPrint('原提醒時間已過，計算新的提醒時間');

        // 確保取消截止時間還未到
        if (userStatusService.cancelDeadline!.isBefore(now)) {
          debugPrint('取消截止時間也已過，不設置通知');
          return;
        }

        // 計算當前時間到取消截止時間的中間點
        final int totalMinutes =
            userStatusService.cancelDeadline!.difference(now).inMinutes;
        final int halfwayMinutes = totalMinutes ~/ 2;

        // 如果剩餘時間太短（少於10分鐘），則設為5分鐘後
        if (halfwayMinutes < 10) {
          reminderTime = now.add(const Duration(minutes: 5));
          debugPrint('剩餘時間較短，設置為5分鐘後提醒');
        } else {
          reminderTime = now.add(Duration(minutes: halfwayMinutes));
          debugPrint('設置為當前時間和截止時間的中間點提醒: $halfwayMinutes 分鐘後');
        }
      }

      debugPrint(
        '設置聚餐提醒通知，提醒時間: ${DateFormat('yyyy-MM-dd HH:mm').format(reminderTime)}',
      );

      // 設置通知ID，使用聚餐時間的哈希碼確保唯一性和可重複性（用於取消）
      final int notificationId =
          (userStatusService.confirmedDinnerTime ?? TimeService().now())
              .millisecondsSinceEpoch
              .hashCode;

      // 在生產環境中：如果已經在測試時間內，使用3分鐘後的時間作為測試
      final DateTime actualReminderTime =
          reminderTime.isBefore(
                TimeService().now().add(const Duration(minutes: 3)),
              )
              ? TimeService().now().add(const Duration(minutes: 3))
              : reminderTime;

      if (actualReminderTime != reminderTime) {
        debugPrint('提醒時間太近，調整為3分鐘後');
      }

      // 使用 NotificationService 排程通知
      await NotificationService().scheduleReservationReminder(
        id: notificationId,
        title: '聚餐提醒',
        body: '您已報名這週的聚餐活動，如果不方便參加，請立即開啟APP取消',
        scheduledTime: actualReminderTime,
      );

      // 儲存通知ID到SharedPreferences，用於後續可能的取消
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dinner_reminder_notification_id', notificationId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '將會在 ${DateFormat('MM/dd HH:mm').format(actualReminderTime)} 提醒您確認參加',
            style: TextStyle(fontFamily: 'OtsutomeFont'),
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      debugPrint('聚餐提醒通知已成功排程，ID: $notificationId');
    } catch (e) {
      debugPrint('設置聚餐提醒通知失敗: $e');

      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB33D1C), // 深橘色背景
            content: Text(
              '設定提醒功能暫時無法使用，但您的預約已成功',
              style: TextStyle(fontFamily: 'OtsutomeFont', color: Colors.white),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
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
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background/bg2.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // 頂部導航欄
                    HeaderBar(title: '聚餐預約'),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 20.h),
                              // 標題
                              Text(
                                '預約聚餐',
                                style: TextStyle(
                                  fontSize: 24.sp,
                                  fontFamily: 'OtsutomeFont',
                                  color: const Color(0xFF23456B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              // 說明文字（由 UserStatusService 動態提供）
                              Consumer<UserStatusService>(
                                builder: (context, userStatusService, _) {
                                  final description =
                                      '下次活動在${userStatusService.weekdayText}舉行，歡迎預約參加';
                                  return Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 25.h),

                              // 日期卡片（使用 Consumer 來監聽 UserStatusService）
                              Consumer<UserStatusService>(
                                builder: (context, userStatusService, child) {
                                  // 根據聚餐時間判斷圖標
                                  String iconPath =
                                      'assets/images/icon/thu.webp';
                                  if (userStatusService.confirmedDinnerTime !=
                                      null) {
                                    iconPath =
                                        userStatusService
                                                    .confirmedDinnerTime!
                                                    .weekday ==
                                                DateTime.monday
                                            ? 'assets/images/icon/mon.webp'
                                            : 'assets/images/icon/thu.webp';
                                  }

                                  return _buildDateCard(
                                    context,
                                    userStatusService.weekdayText,
                                    iconPath,
                                    userStatusService.formattedDinnerTimeOnly,
                                    userStatusService.formattedDinnerDate,
                                  );
                                },
                              ),

                              SizedBox(height: 60.h),

                              // 按鈕（預約或參加）
                              Consumer<UserStatusService>(
                                builder: (context, userStatusService, _) {
                                  final String? status =
                                      userStatusService.userStatus;
                                  final bool isNextWeekStage =
                                      status != 'booking';
                                  final bool isFuture =
                                      (userStatusService.confirmedDinnerTime
                                          ?.isAfter(TimeService().now())) ??
                                      true;
                                  return Center(
                                    child:
                                        _isProcessing
                                            ? LoadingImage(
                                              width: 60.w,
                                              height: 60.h,
                                              color: const Color(0xFFB33D1C),
                                            )
                                            : ImageButton(
                                              text: _buttonText,
                                              imagePath:
                                                  'assets/images/ui/button/red_l.webp',
                                              width: 160.w,
                                              height: 70.h,
                                              onPressed: _handleButtonClick,
                                              isEnabled:
                                                  !isNextWeekStage || isFuture,
                                            ),
                                  );
                                },
                              ),

                              // 顯示預約狀態提示（如果不能預約）
                              Consumer<UserStatusService>(
                                builder: (context, userStatusService, _) {
                                  final String? status =
                                      userStatusService.userStatus;
                                  final bool isNextWeekStage =
                                      status != 'booking';
                                  final bool isFuture =
                                      (userStatusService.confirmedDinnerTime
                                          ?.isAfter(TimeService().now())) ??
                                      false;
                                  final bool showClosedTip =
                                      isNextWeekStage && !isFuture;
                                  if (!showClosedTip) return const SizedBox();
                                  return Padding(
                                    padding: EdgeInsets.only(top: 15.h),
                                    child: Center(
                                      child: Text(
                                        '當前聚餐活動預約已截止',
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontFamily: 'OtsutomeFont',
                                          color: const Color(0xFFB33D1C),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              SizedBox(height: 30.h),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // 右上角歡迎提示框 - 只對新用戶顯示
                if (_showWelcomeTip && _isNewUser && _username.isNotEmpty)
                  Positioned(
                    top: 18.h,
                    right: 20.w,
                    child: InfoTipBox(
                      message: '嗨囉 $_username！',
                      show: _showWelcomeTip,
                      onHide: () {
                        // 提示框完全隱藏後的回調
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 構建日期卡片
  Widget _buildDateCard(
    BuildContext context,
    String day,
    String iconPath,
    String time,
    String formattedDate,
  ) {
    // 計算適當的陰影偏移量
    final adaptiveShadowOffset = 3.h;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: 24.h),
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
          // 圖片及陰影
          SizedBox(
            width: 80.w,
            height: 80.h,
            child: Stack(
              clipBehavior: Clip.none, // 允許陰影超出容器範圍
              children: [
                // 底部陰影
                Positioned(
                  left: 0,
                  top: adaptiveShadowOffset,
                  child: Image.asset(
                    iconPath,
                    width: 80.w,
                    height: 80.h,
                    color: Colors.black.withOpacity(0.4),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
                // 主圖像
                Image.asset(iconPath, width: 80.w, height: 80.h),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          // 日期文字
          Text(
            day,
            style: TextStyle(
              fontSize: 22.sp,
              fontFamily: 'OtsutomeFont',
              color: const Color(0xFF23456B),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          // 具體日期 (MM/DD)
          Text(
            formattedDate,
            style: TextStyle(
              fontSize: 20.sp,
              fontFamily: 'OtsutomeFont',
              color: const Color(0xFF23456B),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          // 時間文字
          Text(
            time,
            style: TextStyle(
              fontSize: 20.sp,
              fontFamily: 'OtsutomeFont',
              color: const Color(0xFF23456B),
            ),
          ),

          // 只有校內email用戶才顯示分隔線和配對偏好選項
          if (_isSchoolEmail) ...[
            SizedBox(height: 20.h),
            // 分隔線
            Container(
              height: 1,
              color: Colors.grey[300],
              margin: EdgeInsets.symmetric(horizontal: 15.w),
            ),
            // 校內同學配對選項
            GestureDetector(
              onTap: () {
                setState(() {
                  _onlyNckuStudents = !_onlyNckuStudents;
                });
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 15.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 勾選框
                    CustomCheckbox(
                      value: _onlyNckuStudents,
                      onChanged: _handlePreferenceChange,
                    ),
                    SizedBox(width: 10.w),
                    // 文字說明
                    Text(
                      '想與校內同學聚餐',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontFamily: 'OtsutomeFont',
                        color: const Color(0xFF23456B),
                        fontWeight: FontWeight.bold,
                        height: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!_isSchoolEmail)
            // 非校內用戶增加底部padding以保持美觀
            SizedBox(height: _isSchoolEmail ? 0 : 25.h),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hourlyTimer?.cancel();
    super.dispose();
  }
}
