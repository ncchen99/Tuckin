import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/components/common/header_bar.dart';
import 'package:tuckin/components/common/loading_image.dart';
import 'package:tuckin/utils/index.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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
  // 預約進行中
  bool _isReserving = false;
  // 添加服務
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  String _username = ''; // 用戶名稱

  // 下次聚餐日期
  late DateTime _nextDinnerDate;
  // 是否為單周（顯示星期一）
  late bool _isSingleWeek;
  // 顯示星期幾文字
  late String _weekdayText;
  // 是否可以預約
  late bool _canReserve;

  @override
  void initState() {
    super.initState();
    _checkIfNewUser();
    _calculateDates();
  }

  // 計算日期
  void _calculateDates() {
    final now = DateTime.now();
    final currentDay = now.weekday;

    // 計算當前是第幾週（從年初起算）
    final int weekNumber =
        (now.difference(DateTime(now.year, 1, 1)).inDays / 7).floor() + 1;

    // 判斷當前週是單數週還是雙數週
    _isSingleWeek = weekNumber % 2 == 1;

    // 設定本週聚餐日是星期一還是星期四
    _weekdayText = _isSingleWeek ? '星期一' : '星期四';

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

    // 下週的目標聚餐日
    DateTime nextWeekTarget = thisWeekTarget.add(const Duration(days: 7));

    // 判斷是否已經過了本週的聚餐日，或者距離聚餐日不足2天
    // 用絕對時間來比較，而不只是日期，這樣可以更精確
    bool isPastOrTooClose = now.isAfter(
      thisWeekTarget.subtract(const Duration(days: 2)),
    );

    if (isPastOrTooClose) {
      // 如果已經過了本週聚餐日期或時間太接近，則預約下週聚餐
      _nextDinnerDate = nextWeekTarget;
    } else {
      // 否則預約本週聚餐
      _nextDinnerDate = thisWeekTarget;
    }

    // 既然都是未來日期，所以一定可以預約
    _canReserve = true;

    // 調試輸出
    debugPrint('當前週數: $weekNumber (${_isSingleWeek ? "單週" : "雙週"})');
    debugPrint('當前星期幾: $currentDay');
    debugPrint(
      '本週目標聚餐日: ${DateFormat('yyyy-MM-dd').format(thisWeekTarget)} ($_weekdayText)',
    );
    debugPrint('下週目標聚餐日: ${DateFormat('yyyy-MM-dd').format(nextWeekTarget)}');
    debugPrint('是否已過或太接近: $isPastOrTooClose');
    debugPrint('選擇的聚餐日期: ${DateFormat('yyyy-MM-dd').format(_nextDinnerDate)}');
  }

  // 檢查是否為新用戶
  Future<void> _checkIfNewUser() async {
    try {
      // 檢查 SharedPreferences 中的新用戶標誌
      final prefs = await SharedPreferences.getInstance();
      final isNewUser = prefs.getBool('is_new_user') ?? false;

      if (isNewUser) {
        // 獲取當前用戶
        final currentUser = _authService.getCurrentUser();
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
          child: Stack(
            children: [
              Column(
                children: [
                  // 頂部導航欄
                  HeaderBar(
                    title: '聚餐預約',
                    onNotificationTap: () {
                      // 導航到通知頁面
                      Navigator.pushNamed(context, '/notifications');
                    },
                    onProfileTap: () {
                      // 導航到個人資料頁面
                      Navigator.pushNamed(context, '/user_settings');
                    },
                  ),

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
                              '下次聚餐時間',
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
                              '這次的活動在星期${_isSingleWeek ? "一" : "四"}舉行，歡迎預約參加',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontFamily: 'OtsutomeFont',
                                color: const Color(0xFF23456B),
                              ),
                            ),
                            SizedBox(height: 25.h),

                            // 日期卡片（單周星期一或雙周星期四）
                            _buildDateCard(
                              context,
                              _weekdayText,
                              _isSingleWeek
                                  ? 'assets/images/icon/mon.png'
                                  : 'assets/images/icon/thu.png',
                              '晚間 7:00',
                              DateFormat('MM/dd').format(_nextDinnerDate),
                            ),

                            SizedBox(height: 25.h),

                            // 成大限定選項 - 對齊標題邊界
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 15.w,
                                vertical: 12.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: const Color(0xFF23456B),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 勾選框
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 2.h,
                                    ),
                                    child: CustomCheckbox(
                                      value: _onlyNckuStudents,
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _onlyNckuStudents = value;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  // 文字說明
                                  Expanded(
                                    child: Text(
                                      '想與校內同學聚餐',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontFamily: 'OtsutomeFont',
                                        color: const Color(0xFF23456B),
                                        fontWeight: FontWeight.bold,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 45.h),

                            // 預約按鈕
                            Center(
                              child:
                                  _isReserving
                                      ? LoadingImage(
                                        width: 60.w,
                                        height: 60.h,
                                        color: const Color(0xFFB33D1C),
                                      )
                                      : ImageButton(
                                        text: '預約',
                                        imagePath:
                                            'assets/images/ui/button/red_l.png',
                                        width: 160.w,
                                        height: 68.h,
                                        onPressed: () async {
                                          setState(() {
                                            _isReserving = true;
                                          });

                                          try {
                                            final currentUser =
                                                _authService.getCurrentUser();
                                            if (currentUser != null) {
                                              // 更新用戶狀態為等待配對階段
                                              await _databaseService
                                                  .updateUserStatus(
                                                    currentUser.id,
                                                    'waiting_matching',
                                                  );

                                              // 導航到配對狀態頁面
                                              if (!mounted) return;
                                              Navigator.pushReplacementNamed(
                                                context,
                                                '/matching_status',
                                              );
                                            }
                                          } catch (e) {
                                            debugPrint('預約時出錯: $e');
                                            // 出錯時恢復狀態
                                            if (mounted) {
                                              setState(() {
                                                _isReserving = false;
                                              });
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('預約失敗: $e'),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        isEnabled:
                                            _canReserve, // 根據是否可以預約來啟用/禁用按鈕
                                      ),
                            ),

                            // 顯示預約狀態提示（如果不能預約）
                            if (!_canReserve)
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
                  top: 70.h, // 調整位置，確保在HeaderBar下方
                  right: 20.w,
                  child: InfoTipBox(
                    message: '嗨囉 $_username！\n 每次相遇都是生命中的美好！',
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
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF23456B), width: 1.5),
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
        ],
      ),
    );
  }
}
