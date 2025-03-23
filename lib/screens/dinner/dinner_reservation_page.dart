import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/components/common/header_bar.dart';
import 'package:tuckin/utils/index.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DinnerReservationPage extends StatefulWidget {
  const DinnerReservationPage({super.key});

  @override
  State<DinnerReservationPage> createState() => _DinnerReservationPageState();
}

class _DinnerReservationPageState extends State<DinnerReservationPage> {
  // 用戶選擇的日期 (0: 星期一, 1: 星期四)
  int? _selectedDate;
  // 是否僅限成大學生參與
  bool _onlyNckuStudents = true;
  // 控制提示框顯示
  bool _showWelcomeTip = false;
  // 是否為新用戶
  bool _isNewUser = false;
  // 添加服務
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  String _username = ''; // 用戶名稱

  @override
  void initState() {
    super.initState();
    _checkIfNewUser();
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
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 20.h),
                            // 標題
                            Text(
                              '選擇聚餐日期',
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
                              '請選擇您希望參加的聚餐日期，每週僅能參加一次聚餐活動',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontFamily: 'OtsutomeFont',
                                color: const Color(0xFF23456B),
                              ),
                            ),
                            SizedBox(height: 30.h),

                            // 日期選擇區域
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 星期一選項
                                _buildDateCard(
                                  context,
                                  '星期一',
                                  'assets/images/icon/tue.png',
                                  '晚間 7:00',
                                  0,
                                ),
                                // 星期四選項
                                _buildDateCard(
                                  context,
                                  '星期四',
                                  'assets/images/icon/thu.png',
                                  '晚間 7:00',
                                  1,
                                ),
                              ],
                            ),

                            SizedBox(height: 30.h),

                            // 預約截止時間提示
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(15.r),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: const Color(0xFF23456B),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '預約截止時間：周五午夜 12:00',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontFamily: 'OtsutomeFont',
                                  color: const Color(0xFF23456B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            SizedBox(height: 20.h),

                            // 成大限定選項
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(15.r),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: const Color(0xFF23456B),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CustomCheckbox(
                                    value: _onlyNckuStudents,
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _onlyNckuStudents = value;
                                        });
                                      }
                                    },
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: Text(
                                      '僅限成大學生參與',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontFamily: 'OtsutomeFont',
                                        color: const Color(0xFF23456B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 50.h),

                            // 提交按鈕
                            Center(
                              child: ImageButton(
                                text: '開始配對',
                                imagePath: 'assets/images/ui/button/red_l.png',
                                width: 180.w,
                                height: 75.h,
                                onPressed: () {
                                  // 導航到配對狀態頁面
                                  Navigator.pushNamed(
                                    context,
                                    '/matching_status',
                                  );
                                },
                                isEnabled:
                                    _selectedDate != null, // 如果未選擇日期，則禁用按鈕
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
                    message: '歡迎您，$_username！\n準備好預約您的第一次聚餐了嗎？',
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

  // 構建日期選擇卡片
  Widget _buildDateCard(
    BuildContext context,
    String day,
    String iconPath,
    String time,
    int dateIndex,
  ) {
    final isSelected = _selectedDate == dateIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = dateIndex;
        });
      },
      child: Container(
        width: 150.w,
        padding: EdgeInsets.all(15.r),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF23456B)
                  : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: const Color(0xFF23456B), width: 1.5),
        ),
        child: Column(
          children: [
            // 日期圖示
            Image.asset(
              iconPath,
              width: 50.w,
              height: 50.w,
              color: isSelected ? Colors.white : const Color(0xFF23456B),
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.calendar_today,
                  size: 50.w,
                  color: isSelected ? Colors.white : const Color(0xFF23456B),
                );
              },
            ),
            SizedBox(height: 10.h),
            // 日期文字
            Text(
              day,
              style: TextStyle(
                fontSize: 18.sp,
                fontFamily: 'OtsutomeFont',
                color: isSelected ? Colors.white : const Color(0xFF23456B),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 5.h),
            // 時間文字
            Text(
              time,
              style: TextStyle(
                fontSize: 14.sp,
                fontFamily: 'OtsutomeFont',
                color: isSelected ? Colors.white : const Color(0xFF23456B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
