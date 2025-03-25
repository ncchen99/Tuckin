import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart'; // 包含 NavigationService

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
  bool _hasConfirmed = false;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final userStatus = await _databaseService.getUserStatus(currentUser.id);
        setState(() {
          _isLoading = false;
        });

        if (userStatus != 'waiting_confirmation') {
          if (mounted) {
            _navigationService.navigateToUserStatusPage(context);
          }
        }
      }
    } catch (e) {
      debugPrint('檢查用戶狀態時出錯: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 用戶確認參加晚餐
  Future<void> _handleConfirmAttendance() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // 更新用戶狀態
        await _databaseService.updateUserStatus(
          currentUser.id,
          'waiting_restaurant',
        );

        setState(() {
          _hasConfirmed = true;
        });

        if (mounted) {
          _navigationService.navigateToRestaurantSelection(context);
        }
      }
    } catch (e) {
      debugPrint('確認參加晚餐時出錯: $e');
    }
  }

  // 用戶取消參加晚餐
  Future<void> _handleCancelAttendance() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // 更新用戶狀態
        await _databaseService.updateUserStatus(currentUser.id, 'booking');

        if (mounted) {
          _navigationService.navigateToDinnerReservation(context);
        }
      }
    } catch (e) {
      debugPrint('取消參加晚餐時出錯: $e');
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
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF23456B),
                      ),
                    )
                    : Column(
                      children: [
                        // 頁面標題
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.h),
                          child: Row(
                            children: [
                              BackIconButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '出席確認',
                                    style: TextStyle(
                                      fontSize: 24.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 55.w), // 平衡左側的返回按鈕
                            ],
                          ),
                        ),

                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '我們已找到朋友！',
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFF23456B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: 30.h),

                                Text(
                                  '請確認是否要參加聚餐？',
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFF23456B),
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: 80.h),

                                // 確認和取消按鈕
                                _hasConfirmed
                                    ? Center(
                                      child: LoadingImage(
                                        width: 60.w,
                                        height: 60.h,
                                        color: const Color(0xFF23456B),
                                      ),
                                    )
                                    : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // 取消按鈕
                                        ImageButton(
                                          text: '取消',
                                          imagePath:
                                              'assets/images/ui/button/blue_m.png',
                                          width: 120.w,
                                          height: 60.h,
                                          onPressed: _handleCancelAttendance,
                                        ),

                                        SizedBox(width: 40.w),

                                        // 確認按鈕
                                        ImageButton(
                                          text: '確認',
                                          imagePath:
                                              'assets/images/ui/button/red_m.png',
                                          width: 120.w,
                                          height: 60.h,
                                          onPressed: _handleConfirmAttendance,
                                        ),
                                      ],
                                    ),
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
