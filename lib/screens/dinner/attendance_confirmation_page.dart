import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/components/common/loading_image.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';

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
  bool _isLoading = true;
  bool _isConfirming = false; // 跟蹤確認操作狀態

  @override
  void initState() {
    super.initState();
    // TODO: 載入出席確認資料
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _handleConfirm() async {
    setState(() {
      _isConfirming = true;
    });

    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser != null) {
        // 這裡應更新用戶狀態為下一個狀態
        await _databaseService.updateUserStatus(
          currentUser.id,
          'waiting_restaurant', // 假設下一個狀態是等待選擇餐廳
        );

        // 導航到下一個頁面
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/restaurant_selection');
        }
      }
    } catch (e) {
      debugPrint('確認出席時出錯: $e');
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('確認失敗: $e')));
      }
    }
  }

  Future<void> _handleCancel() async {
    setState(() {
      _isConfirming = true;
    });

    try {
      final currentUser = _authService.getCurrentUser();
      if (currentUser != null) {
        // 取消出席，回到預約狀態
        await _databaseService.updateUserStatus(currentUser.id, 'booking');

        // 返回預約頁面
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/dinner_reservation');
        }
      }
    } catch (e) {
      debugPrint('取消出席時出錯: $e');
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('取消失敗: $e')));
      }
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
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF23456B)),
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
                              _isConfirming
                                  ? Center(
                                    child: LoadingImage(
                                      width: 60.w,
                                      height: 60.h,
                                      color: const Color(0xFF23456B),
                                    ),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // 取消按鈕
                                      ImageButton(
                                        text: '取消',
                                        imagePath:
                                            'assets/images/ui/button/blue_m.png',
                                        width: 120.w,
                                        height: 60.h,
                                        onPressed: _handleCancel,
                                      ),

                                      SizedBox(width: 40.w),

                                      // 確認按鈕
                                      ImageButton(
                                        text: '確認',
                                        imagePath:
                                            'assets/images/ui/button/red_m.png',
                                        width: 120.w,
                                        height: 60.h,
                                        onPressed: _handleConfirm,
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
    );
  }
}
