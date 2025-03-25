import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';

class RestaurantSelectionPage extends StatefulWidget {
  const RestaurantSelectionPage({super.key});

  @override
  State<RestaurantSelectionPage> createState() =>
      _RestaurantSelectionPageState();
}

class _RestaurantSelectionPageState extends State<RestaurantSelectionPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // TODO: 載入餐廳推薦資料
    _loadRestaurantData();
  }

  Future<void> _loadRestaurantData() async {
    setState(() {
      _isLoading = false;
    });
  }

  // 使用導航服務處理返回
  void _handleBack() {
    Navigator.of(context).pop();
  }

  // 使用導航服務處理選擇餐廳後的導航
  Future<void> _handleSelectRestaurant() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // 更新用戶狀態
        await _databaseService.updateUserStatus(
          currentUser.id,
          'waiting_dinner',
        );

        if (mounted) {
          // 使用導航服務導航到晚餐信息頁面
          _navigationService.navigateToUserStatusPage(context);
        }
      }
    } catch (e) {
      debugPrint('選擇餐廳時出錯: $e');
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
                              BackIconButton(onPressed: _handleBack),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '餐廳選擇',
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
                              '餐廳選擇頁面開發中...',
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
