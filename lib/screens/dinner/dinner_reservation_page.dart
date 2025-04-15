import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/utils/index.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/matching_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // <--- 新增導入
import 'package:flutter/rendering.dart'; // <--- 新增導入

// 頁面階段狀態
enum PageStage {
  reserve, // 預約階段
  join, // 參加階段 (週二6:00至週三6:00)
  nextWeek, // 顯示下週聚餐
}

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
  // 添加一個狀態來控制"正在尋找中"的提示框 (新增)
  bool _showSearchingTip = false;
  // 添加服務
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  final MatchingService _matchingService = MatchingService();
  String _username = ''; // 用戶名稱
  // 添加一個計時器來處理整點更新
  Timer? _hourlyTimer; // <--- 新增計時器變數

  // 下次聚餐日期
  late DateTime _nextDinnerDate;
  // 聚餐時間
  late DateTime _nextDinnerTime;
  // 是否為單周（顯示星期一）
  late bool _isSingleWeek;
  // 顯示星期幾文字
  late String _weekdayText;

  // 當前頁面階段
  late PageStage _currentStage;
  // 按鈕文字
  late String _buttonText;
  // 說明文字
  late String _descriptionText;

  // Helper function to calculate ISO 8601 week number
  int _getIsoWeekNumber(DateTime date) {
    int dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    int dayOfWeek = date.weekday; // Monday = 1, Sunday = 7

    // Formula based on ISO 8601 standard
    int weekNumber = ((dayOfYear - dayOfWeek + 10) / 7).floor();

    if (weekNumber < 1) {
      // Belongs to the last week of the previous year.
      DateTime lastDayOfPrevYear = DateTime(date.year - 1, 12, 31);
      return _getIsoWeekNumber(
        lastDayOfPrevYear,
      ); // Recurse for previous year's last week
    } else if (weekNumber == 53) {
      // Check if it should actually be week 1 of the next year.
      // This happens if Jan 1 of next year is a Monday, Tuesday, Wednesday, or Thursday.
      DateTime jan1NextYear = DateTime(date.year + 1, 1, 1);
      if (jan1NextYear.weekday >= DateTime.monday &&
          jan1NextYear.weekday <= DateTime.thursday) {
        // It's week 1 of the next year.
        return 1;
      } else {
        // It's genuinely week 53.
        return 53;
      }
    } else {
      // It's a regular week number (1-52).
      return weekNumber;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkIfNewUser();
    _calculateDates();
    _loadUserPreferences();
    _checkUserEmail();
    _scheduleHourlyUpdate(); // <--- 啟動計時器調度
    WidgetsBinding.instance.addObserver(this); // <--- 註冊 observer
  }

  // <--- 新增 didChangeAppLifecycleState 方法
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
  } // <--- 新增計時器調度方法

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

  // 計算日期並決定當前階段
  void _calculateDates() {
    final now = DateTime.now();
    final currentDay = now.weekday;

    // 計算當前是第幾週（使用 ISO 8601 標準）
    final int weekNumber = _getIsoWeekNumber(now);
    // final int weekNumber =
    //     (now.difference(DateTime(now.year, 1, 1)).inDays / 7).floor() + 1;

    // 判斷當前週是單數週還是雙數週
    _isSingleWeek = weekNumber % 2 == 1;

    // 計算本週的聚餐日期 (先計算本週的開始日期，然後加上對應的天數)
    final int targetWeekday =
        _isSingleWeek ? DateTime.monday : DateTime.thursday;

    // 計算本週日期 (回到本週日，然後加上目標天數)
    // 先計算到本週日的天數 (週日是7，週一是1，所以用7減週幾)
    int daysToSunday =
        currentDay == DateTime.sunday ? 0 : (DateTime.sunday - currentDay);

    // 本週日的日期
    DateTime thisWeekSunday = now.subtract(Duration(days: 7 - daysToSunday));

    // 本週的目標聚餐日
    DateTime thisWeekTarget = thisWeekSunday.add(Duration(days: targetWeekday));

    // 計算下一週的週數
    final int nextWeekNumber = weekNumber + 1;
    // 判斷下一週是單數週還是雙數週
    final bool isNextWeekSingle = nextWeekNumber % 2 == 1;
    // 設定下一週的目標聚餐日是星期一還是星期四
    final int nextTargetWeekday =
        isNextWeekSingle ? DateTime.monday : DateTime.thursday;
    // 下一週的星期日
    final DateTime nextWeekSunday = thisWeekSunday.add(const Duration(days: 7));
    // 下週的目標聚餐日
    DateTime nextWeekTarget = nextWeekSunday.add(
      Duration(days: nextTargetWeekday),
    );

    // 計算下下週的目標聚餐日
    final int afterNextWeekNumber = weekNumber + 2;
    final bool isAfterNextWeekSingle = afterNextWeekNumber % 2 == 1;
    final int afterNextTargetWeekday =
        isAfterNextWeekSingle ? DateTime.monday : DateTime.thursday;
    final DateTime afterNextWeekSunday = thisWeekSunday.add(
      const Duration(days: 14),
    );
    DateTime afterNextWeekTarget = afterNextWeekSunday.add(
      Duration(days: afterNextTargetWeekday),
    );

    // 先計算本週的聚餐日期
    final DateTime currentWeekTarget = thisWeekSunday.add(
      Duration(days: targetWeekday),
    );

    // 先決定要顯示的聚餐日期（這週、下週或下下週）
    // 如果距離聚餐時間小於37小時（聚餐在晚上7點，小於37小時相當於聚餐日前一天的早上6點以後）
    DateTime dinnerDateTime = DateTime(
      currentWeekTarget.year,
      currentWeekTarget.month,
      currentWeekTarget.day,
      19, // 聚餐時間：晚上7點
      0,
    );
    Duration timeUntilDinner = dinnerDateTime.difference(now);

    // 計算下週聚餐的時間
    DateTime nextDinnerDateTime = DateTime(
      nextWeekTarget.year,
      nextWeekTarget.month,
      nextWeekTarget.day,
      19, // 聚餐時間：晚上7點
      0,
    );
    Duration timeUntilNextDinner = nextDinnerDateTime.difference(now);

    // 決定要顯示哪一週的聚餐
    if (now.isAfter(currentWeekTarget) || timeUntilDinner.inHours < 37) {
      // 已經過了本週聚餐或距離本週聚餐時間小於37小時

      if (now.isAfter(nextWeekTarget) || timeUntilNextDinner.inHours < 37) {
        // 如果下週聚餐也已經過了或時間也太接近，則顯示下下週聚餐
        _nextDinnerDate = afterNextWeekTarget;
        debugPrint('選擇下下週聚餐，因為本週和下週聚餐時間太近，使用下下週週日計算參加階段時間');
        debugPrint(
          '下下週聚餐日期的週日: ${DateFormat('yyyy-MM-dd').format(afterNextWeekSunday)}',
        );
      } else {
        // 顯示下週聚餐
        _nextDinnerDate = nextWeekTarget;
        debugPrint('選擇下週聚餐，因為本週聚餐時間太近，使用下週週日計算參加階段時間');
        debugPrint(
          '下週聚餐日期的週日: ${DateFormat('yyyy-MM-dd').format(nextWeekSunday)}',
        );
      }
    } else {
      // 顯示本週聚餐
      _nextDinnerDate = currentWeekTarget;
      debugPrint('選擇本週聚餐，使用本週週日計算參加階段時間');
      debugPrint(
        '本週聚餐日期的週日: ${DateFormat('yyyy-MM-dd').format(thisWeekSunday)}',
      );
    }

    // 計算聚餐時間

    _nextDinnerTime = DateTime(
      _nextDinnerDate.year,
      _nextDinnerDate.month,
      _nextDinnerDate.day,
      19, // 聚餐時間：晚上7點
      0,
    );

    // 根據選定的聚餐日期計算參加階段的開始時間和結束時間
    DateTime joinPhaseStart = _nextDinnerTime.subtract(
      const Duration(hours: 61),
    );
    DateTime joinPhaseEnd = _nextDinnerTime.subtract(const Duration(hours: 37));

    // 接著判斷是否在參加階段
    if (now.isAfter(joinPhaseStart) && now.isBefore(joinPhaseEnd)) {
      // 處於參加階段
      _currentStage = PageStage.join;
    } else {
      // 正常預約階段
      _currentStage = PageStage.reserve;
    }

    // 檢查用戶狀態（如果是booking狀態且在參加階段，顯示參加按鈕）
    _checkUserStateForJoinPhase();

    // 根據最終確定的 _nextDinnerDate 來設定星期幾文字
    if (_nextDinnerDate.weekday == DateTime.monday) {
      _weekdayText = '星期一';
    } else if (_nextDinnerDate.weekday == DateTime.thursday) {
      _weekdayText = '星期四';
    } else {
      // 處理潛在錯誤，雖然正常情況下不應發生
      _weekdayText = '未知';
      debugPrint('錯誤：計算出的聚餐日既不是星期一也不是星期四: $_nextDinnerDate');
    }

    // 設定按鈕文字和說明文字
    _updateTextsBasedOnStage();

    // 調試輸出
    debugPrint('當前週數: $weekNumber (${_isSingleWeek ? "單週" : "雙週"})');
    debugPrint('當前星期幾: $currentDay');
    debugPrint('當前階段: $_currentStage');

    // Helper function to get weekday text
    String getWeekdayText(DateTime date) {
      if (date.weekday == DateTime.monday) return '星期一';
      if (date.weekday == DateTime.thursday) return '星期四';
      return '未知';
    }

    debugPrint(
      '本週目標聚餐日: ${DateFormat('yyyy-MM-dd').format(thisWeekTarget)} (${getWeekdayText(thisWeekTarget)})',
    );
    debugPrint(
      '下週目標聚餐日: ${DateFormat('yyyy-MM-dd').format(nextWeekTarget)} (${getWeekdayText(nextWeekTarget)})',
    );
    debugPrint(
      '下下週目標聚餐日: ${DateFormat('yyyy-MM-dd').format(afterNextWeekTarget)} (${getWeekdayText(afterNextWeekTarget)})',
    );
    debugPrint(
      '選擇的聚餐日期: ${DateFormat('yyyy-MM-dd').format(_nextDinnerDate)} (${getWeekdayText(_nextDinnerDate)})',
    );
    debugPrint(
      '參加階段開始: ${DateFormat('yyyy-MM-dd HH:mm').format(joinPhaseStart)}',
    );
    debugPrint(
      '參加階段結束: ${DateFormat('yyyy-MM-dd HH:mm').format(joinPhaseEnd)}',
    );
  }

  // 根據用戶狀態確定是否顯示「參加」按鈕
  Future<void> _checkUserStateForJoinPhase() async {
    if (_currentStage == PageStage.join) {
      try {
        final currentUser = await _authService.getCurrentUser();
        if (currentUser != null) {
          final userStatus = await _databaseService.getUserStatus(
            currentUser.id,
          );
          // 如果用戶狀態是booking，則可以參加
          if (userStatus == 'booking') {
            _currentStage = PageStage.join;
          } else {
            // 用戶已經在其他階段，顯示下週聚餐
            _currentStage = PageStage.nextWeek;
          }
        }
      } catch (error) {
        debugPrint('檢查用戶狀態錯誤: $error');
        // 發生錯誤時，假設為預約階段
        _currentStage = PageStage.reserve;
      }
    }
  }

  // 更新按鈕文字和說明文字
  void _updateTextsBasedOnStage() {
    switch (_currentStage) {
      case PageStage.reserve:
        _buttonText = '預約';
        _descriptionText = '下次活動在$_weekdayText舉行，歡迎預約參加';
        break;
      case PageStage.join:
        _buttonText = '參加';
        _descriptionText = '本週聚餐在$_weekdayText舉行，立即點擊參加！';
        break;
      case PageStage.nextWeek:
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

      switch (_currentStage) {
        case PageStage.reserve:
        case PageStage.nextWeek:
          // 預約邏輯 - 同原本的邏輯
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

          // 延遲一下導航到配對狀態頁面
          if (!mounted) return;
          await Future.delayed(const Duration(seconds: 1));
          await _navigateToMatchingStatus();
          break;

        case PageStage.join:
          // 顯示正在尋找中的提示 (修改)
          if (mounted) {
            setState(() {
              _showSearchingTip = true;
            });
          }

          // 儲存用戶的配對偏好
          await _databaseService.updateUserMatchingPreference(
            currentUser.id,
            _isSchoolEmail ? _onlyNckuStudents : false,
          );

          // 參加邏輯 - 呼叫後端API
          final response = await _matchingService.joinMatching();

          if (!mounted) return;

          // 隱藏提示框 (新增)
          if (mounted) {
            setState(() {
              _showSearchingTip = false;
            });
          }

          // 根據API回應進行導航
          if (response.status == 'waiting_confirmation' &&
              response.deadline != null) {
            // 成功加入桌位，導航到確認出席頁面
            _navigationService.navigateToAttendanceConfirmation(
              context,
              deadline: response.deadline,
            );
          } else if (response.status == 'waiting_matching') {
            print('伺服器回應訊息: ${response.message}');
            // 進入等待配對狀態
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response.message,
                  style: TextStyle(fontFamily: 'OtsutomeFont'),
                ),
              ),
            );
            await _navigateToMatchingStatus();
          } else {
            // 其他狀態，直接導航到對應頁面
            await _navigateToMatchingStatus();
          }
          break;
      }
    } catch (e) {
      debugPrint('${_currentStage == PageStage.join ? "參加" : "預約"}時出錯: $e');
      // 出錯時恢復狀態
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_currentStage == PageStage.join ? "參加" : "預約"}失敗: $e',
              style: TextStyle(fontSize: 15, fontFamily: 'OtsutomeFont'),
            ),
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
              image: AssetImage('assets/images/background/bg1.png'),
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
                                _currentStage == PageStage.reserve ||
                                        _currentStage == PageStage.nextWeek
                                    ? '預約聚餐'
                                    : '參加聚餐',
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
                                    _nextDinnerDate.weekday == DateTime.monday
                                        ? 'assets/images/icon/mon.png'
                                        : 'assets/images/icon/thu.png';
                                return _buildDateCard(
                                  context,
                                  _weekdayText,
                                  iconPath,
                                  '晚間 7:00',
                                  DateFormat('MM/dd').format(_nextDinnerDate),
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
                                              _currentStage !=
                                                  PageStage.nextWeek ||
                                              _nextDinnerDate.isAfter(
                                                DateTime.now(),
                                              ), // 如果是nextWeek階段且已過下週日期，則禁用
                                        ),
                              ),

                              // 顯示預約狀態提示（如果不能預約）
                              if (_currentStage == PageStage.nextWeek &&
                                  !_nextDinnerDate.isAfter(DateTime.now()))
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
                // 顯示 "正在尋找中..." 提示框 (新增)
                if (_showSearchingTip)
                  Positioned(
                    top: 18.h, // 與歡迎提示框相同位置或自訂
                    right: 20.w, // 與歡迎提示框相同位置或自訂
                    child: InfoTipBox(
                      message: '正在尋找中...',
                      show: _showSearchingTip,
                      onHide: () {}, // 不需要特殊處理
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

  // <--- 新增 dispose 方法
  @override
  void dispose() {
    _hourlyTimer?.cancel(); // 在 widget 銷毀時取消計時器
    WidgetsBinding.instance.removeObserver(this); // <--- 移除 observer
    super.dispose();
  }
}
