import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';

class RatingPage extends StatefulWidget {
  const RatingPage({super.key});

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;
  double _rating = 0;

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

        if (userStatus != 'rating') {
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

  // 用戶提交評分
  Future<void> _handleSubmitRating() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // 儲存用戶評分
        // 註：需要在 DatabaseService 中實現相應方法
        // await _databaseService.saveDinnerRating(
        //   currentUser.id,
        //   _rating,
        // );

        // 更新用戶狀態
        await _databaseService.updateUserStatus(currentUser.id, 'available');

        if (mounted) {
          _navigationService.navigateToHome(context);
        }
      }
    } catch (e) {
      debugPrint('提交評分時出錯: $e');
    }
  }

  // 用戶跳過評分
  Future<void> _handleSkipRating() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // 更新用戶狀態
        await _databaseService.updateUserStatus(currentUser.id, 'available');

        if (mounted) {
          _navigationService.navigateToHome(context);
        }
      }
    } catch (e) {
      debugPrint('跳過評分時出錯: $e');
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
                                  '聚餐評分',
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
                            '評分頁面開發中...',
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
    );
  }
}
