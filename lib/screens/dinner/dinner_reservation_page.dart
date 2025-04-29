import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/utils/index.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/matching_service.dart';
import 'package:tuckin/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:tuckin/services/user_status_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DinnerReservationPage extends StatefulWidget {
  const DinnerReservationPage({super.key});

  @override
  State<DinnerReservationPage> createState() => _DinnerReservationPageState();
}

class _DinnerReservationPageState extends State<DinnerReservationPage>
    with WidgetsBindingObserver {
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
  final MatchingService _matchingService = MatchingService();
  String _username = ''; // 用戶名稱
  // 添加一個計時器來處理整點更新
  Timer? _hourlyTimer;

  // 使用DinnerTimeInfo存儲聚餐時間信息
  DinnerTimeInfo? _dinnerTimeInfo;

  // 按鈕文字
  late String _buttonText;
  // 說明文字
  late String _descriptionText;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _checkIfNewUser();
    // 確保 Provider 中的數據加載完成後再計算日期
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _calculateDates();
      }
    });
    _loadUserPreferences();
    _checkUserEmail();
    _scheduleHourlyUpdate(); // 啟動計時器調度
    WidgetsBinding.instance.addObserver(this); // 註冊 observer
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 應用程式回到前景時，重新計算日期和階段
      debugPrint('應用程式回到前景：重新計算日期和階段...');
      setState(() {
        _calculateDates();
      });
      // 重新安排計時器
      _scheduleHourlyUpdate();
    }
  }

  // 安排下一次整點更新
  void _scheduleHourlyUpdate() {
    final now = DateTime.now();
    // 計算到下一個整點的時間
    final nextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    final durationUntilNextHour = nextHour.difference(now);

    // 取消任何現有的計時器
    _hourlyTimer?.cancel();

    // 設定一個新的計時器，在下一個整點觸發
    _hourlyTimer = Timer(durationUntilNextHour, () {
      // 確保 widget 仍然存在
      if (mounted) {
        debugPrint('整點觸發：重新計算日期和階段...');
        // 重新計算日期和階段，並更新 UI
        setState(() {
          _calculateDates();
        });
        // 再次安排下一次更新
        _scheduleHourlyUpdate();
      }
    });
    debugPrint(
      '已安排下次整點更新於: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(nextHour)} (延遲: ${durationUntilNextHour.inMinutes} 分鐘)',
    );
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

  // 使用DinnerTimeUtils計算日期並決定當前階段
  void _calculateDates() async {
    try {
      // 獲取當前用戶的狀態
      String? userStatus;
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        userStatus = await _databaseService.getUserStatus(currentUser.id);
      }

      // 使用DinnerTimeUtils計算聚餐時間信息
      _dinnerTimeInfo = DinnerTimeUtils.calculateDinnerTimeInfo(
        userStatus: userStatus,
      );

      // 設定按鈕文字和說明文字
      _updateTextsBasedOnStage();

      // 使用 Provider 將聚餐時間和取消截止日期儲存到 UserStatusService 中
      if (mounted) {
        final userStatusService = Provider.of<UserStatusService>(
          context,
          listen: false,
        );
        userStatusService.updateStatus(
          confirmedDinnerTime: _dinnerTimeInfo!.nextDinnerTime,
          cancelDeadline: _dinnerTimeInfo!.cancelDeadline,
        );
        debugPrint(
          '儲存聚餐時間到 UserStatusService: ${_dinnerTimeInfo!.nextDinnerTime}',
        );
        debugPrint(
          '儲存取消截止時間到 UserStatusService: ${_dinnerTimeInfo!.cancelDeadline}',
        );
      }

      // 強制刷新UI
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('計算日期錯誤: $error');
    }
  }

  // 更新按鈕文字和說明文字
  void _updateTextsBasedOnStage() {
    switch (_dinnerTimeInfo!.currentStage) {
      case DinnerPageStage.reserve:
        _buttonText = '預約';
        _descriptionText = '下次活動在${_dinnerTimeInfo!.weekdayText}舉行，歡迎預約參加';
        break;
      case DinnerPageStage.nextWeek:
        _buttonText = '預約';
        _descriptionText = '本週聚餐預約已結束，您可以預約下週聚餐';
        break;
    }
  }

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

  // 處理通知按鈕點擊
  void _handleNotificationTap() {
    Navigator.pushNamed(context, '/notifications');
  }

  // 處理用戶頭像點擊
  void _handleUserProfileTap() {
    _navigationService.navigateToProfile(context);
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

      // 在處理任何操作前，獲取 UserStatusService 實例
      // 使用 Provider 獲取 UserStatusService 實例
      final userStatusService = Provider.of<UserStatusService>(
        context,
        listen: false,
      );

      // 只更新聚餐時間，不覆蓋其他值
      userStatusService.updateStatus(
        confirmedDinnerTime: _dinnerTimeInfo!.nextDinnerTime,
      );
      debugPrint('確認聚餐時間: ${_dinnerTimeInfo!.nextDinnerTime}');

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
      await Future.delayed(const Duration(seconds: 1));
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
      // 確保取消截止時間存在
      if (_dinnerTimeInfo?.cancelDeadline == null) {
        debugPrint('無法設置提醒通知：取消截止時間未定義');
        return;
      }

      // 計算提醒時間（取消截止時間前12小時）
      DateTime reminderTime = _dinnerTimeInfo!.cancelDeadline.subtract(
        const Duration(hours: 12),
      );
      final DateTime now = DateTime.now();

      // 如果提醒時間已經過去，則使用當前時間和取消截止時間的中間點
      if (reminderTime.isBefore(now)) {
        debugPrint('原提醒時間已過，計算新的提醒時間');

        // 確保取消截止時間還未到
        if (_dinnerTimeInfo!.cancelDeadline.isBefore(now)) {
          debugPrint('取消截止時間也已過，不設置通知');
          return;
        }

        // 計算當前時間到取消截止時間的中間點
        final int totalMinutes =
            _dinnerTimeInfo!.cancelDeadline.difference(now).inMinutes;
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
          _dinnerTimeInfo!.nextDinnerTime.millisecondsSinceEpoch.hashCode;

      // 在生產環境中：如果已經在測試時間內，使用3分鐘後的時間作為測試
      final DateTime actualReminderTime =
          reminderTime.isBefore(DateTime.now().add(const Duration(minutes: 3)))
              ? DateTime.now().add(const Duration(minutes: 3))
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
            style: TextStyle(fontSize: 15.sp, fontFamily: 'OtsutomeFont'),
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
            content: Text(
              '設定提醒功能暫時無法使用，但您的預約已成功',
              style: TextStyle(fontSize: 15.sp, fontFamily: 'OtsutomeFont'),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dinnerTimeInfo == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return WillPopScope(
      onWillPop: () async {
        return false; // 禁用返回按鈕
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background/bg2.png'),
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
                              // 說明文字
                              Text(
                                _descriptionText,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontFamily: 'OtsutomeFont',
                                  color: const Color(0xFF23456B),
                                ),
                              ),
                              SizedBox(height: 25.h),

                              // 日期卡片（單周星期一或雙周星期四）
                              () {
                                // 使用 IIFE (Immediately Invoked Function Expression) 來計算 iconPath
                                String iconPath =
                                    _dinnerTimeInfo!.nextDinnerDate.weekday ==
                                            DateTime.monday
                                        ? 'assets/images/icon/mon.png'
                                        : 'assets/images/icon/thu.png';
                                return _buildDateCard(
                                  context,
                                  _dinnerTimeInfo!.weekdayText,
                                  iconPath,
                                  '19:00',
                                  DateFormat(
                                    'MM/dd',
                                  ).format(_dinnerTimeInfo!.nextDinnerDate),
                                );
                              }(), // 立即調用此函數

                              SizedBox(height: 60.h),

                              // 按鈕（預約或參加）
                              Center(
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
                                              'assets/images/ui/button/red_l.png',
                                          width: 160.w,
                                          height: 70.h,
                                          onPressed: _handleButtonClick,
                                          isEnabled:
                                              _dinnerTimeInfo!.currentStage !=
                                                  DinnerPageStage.nextWeek ||
                                              _dinnerTimeInfo!.nextDinnerDate
                                                  .isAfter(
                                                    DateTime.now(),
                                                  ), // 如果是nextWeek階段且已過下週日期，則禁用
                                        ),
                              ),

                              // 顯示預約狀態提示（如果不能預約）
                              if (_dinnerTimeInfo!.currentStage ==
                                      DinnerPageStage.nextWeek &&
                                  !_dinnerTimeInfo!.nextDinnerDate.isAfter(
                                    DateTime.now(),
                                  ))
                                Padding(
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
              fontSize: 18.sp,
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
    _hourlyTimer?.cancel(); // 在 widget 銷毀時取消計時器
    WidgetsBinding.instance.removeObserver(this); // 移除 observer
    super.dispose();
  }
}
