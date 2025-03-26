import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';

class DinnerInfoPage extends StatefulWidget {
  const DinnerInfoPage({super.key});

  @override
  State<DinnerInfoPage> createState() => _DinnerInfoPageState();
}

class _DinnerInfoPageState extends State<DinnerInfoPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    try {
      final currentUser = _authService.getCurrentUser();
      // final userStatus = await _databaseService.getUserStatus(currentUser.id);
      // setState(() {
      //   _isLoading = false;
      // });

      // if (userStatus != 'waiting_dinner') {
      //   if (mounted) {
      //     _navigationService.navigateToUserStatusPage(context);
      //   }
      // }
    } catch (e) {
      debugPrint('檢查用戶狀態時出錯: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 用戶完成晚餐
  Future<void> _handleFinishDinner() async {
    try {
      final currentUser = _authService.getCurrentUser();
      // // 更新用戶狀態
      // await _databaseService.updateUserStatus(currentUser.id, 'rating');

      // if (mounted) {
      //   _navigationService.navigateToDinnerRating(context);
      // }
    } catch (e) {
      debugPrint('完成晚餐時出錯: $e');
    }
  }

  // 在通知圖標點擊處理函數中使用導航服務
  void _handleNotificationTap() {
    _navigationService.navigateToNotifications(context);
  }

  // 在用戶設置圖標點擊處理函數中使用導航服務
  void _handleProfileTap() {
    _navigationService.navigateToUserSettings(context);
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
                                    '聚餐資訊',
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
                          child: Center(
                            child: Text(
                              '聚餐資訊頁面開發中...',
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontFamily: 'OtsutomeFont',
                                color: const Color(0xFF23456B),
                              ),
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
