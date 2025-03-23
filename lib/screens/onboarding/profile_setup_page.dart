import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/screens/onboarding/food_preference_page.dart';
import 'package:tuckin/screens/home_page.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:tuckin/utils/route_transitions.dart'; // 確保導入轉場動畫

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _personalDescController = TextEditingController();

  // 性別選擇，0-未選擇，1-男，2-女
  int _selectedGender = 0;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkUserProfile();
    // 添加監聽器，當暱稱輸入框變更時重新渲染頁面
    _nicknameController.addListener(_updateButtonState);
  }

  // 檢查用戶資料是否已設定
  Future<void> _checkUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 獲取當前用戶
      final currentUser = _authService.getCurrentUser();

      if (currentUser == null) {
        return;
      }

      // 檢查用戶是否已完成設定
      final hasCompleted = await _databaseService.hasCompletedSetup(
        currentUser.id,
      );

      // 如果已完成設定，直接導航到主頁
      if (hasCompleted && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          rightSlideTransition(page: const HomePage()),
          (route) => false,
        );
      }
    } catch (error) {
      // 錯誤處理
      debugPrint('檢查用戶資料錯誤: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nicknameController.removeListener(_updateButtonState);
    _nicknameController.dispose();
    _personalDescController.dispose();
    super.dispose();
  }

  // 更新按鈕狀態的方法
  void _updateButtonState() {
    setState(() {
      // 強制刷新界面
    });
  }

  // 檢查表單是否有效
  bool _isFormValid() {
    return _nicknameController.text.trim().isNotEmpty && _selectedGender != 0;
  }

  // 處理返回按鈕 - 在這個頁面禁用返回功能
  void _handleBack() {
    // 顯示提示訊息，告知用戶無法返回
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('請完成基本資料設定')));
  }

  // 處理下一步按鈕
  Future<void> _handleNextStep() async {
    // 檢查是否有必填項目未填
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入暱稱')));
      return;
    }

    if (_selectedGender == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇生理性別')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 獲取當前用戶
      final currentUser = _authService.getCurrentUser();

      if (currentUser == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('您尚未登入，請先登入')));
        return;
      }

      // 構建用戶資料
      final userData = {
        'user_id': currentUser.id,
        'nickname': _nicknameController.text.trim(),
        'gender': _selectedGender == 1 ? 'male' : 'female',
        'personal_desc':
            _personalDescController.text.trim().isEmpty
                ? '' // 如果個人亮點描述為空，則設為空字串
                : _personalDescController.text.trim(),
      };

      // 儲存用戶資料到 Supabase
      await _databaseService.updateUserProfile(userData);

      // 導航到下一個頁面 - 飲食偏好設定頁，添加向右滑動動畫
      if (mounted) {
        Navigator.push(
          context,
          rightSlideTransition(page: const FoodPreferencePage()),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存資料失敗: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // 禁止使用系統返回按鈕
      onWillPop: () async {
        // 顯示提示訊息
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('請完成基本資料設定')));
        // 返回 false 阻止返回操作
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background/bg2.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 頂部標題和返回按鈕
                Padding(
                  padding: EdgeInsets.only(top: 50.h, bottom: 30.h),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 中央標題
                      Text(
                        '基本資料設定',
                        style: TextStyle(
                          fontSize: 30.sp,
                          fontFamily: 'OtsutomeFont',
                          color: const Color(0xFF23456B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // 暱稱輸入框
                IconTextInput(
                  hintText: '請輸入暱稱',
                  iconPath: 'assets/images/icon/user_profile.png',
                  controller: _nicknameController,
                ),

                // 生理性別選擇
                Container(
                  margin: EdgeInsets.symmetric(vertical: 15.h),
                  width: context.widthPercent(0.8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 8.w, bottom: 8.h),
                        child: Text(
                          '生理性別',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontFamily: 'OtsutomeFont',
                            color: const Color(0xFF23456B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 男性選項
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedGender = 1;
                                });
                              },
                              child: Container(
                                margin: EdgeInsets.only(right: 10.w),
                                height: 50.h,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color:
                                        _selectedGender == 1
                                            ? const Color(0xFF23456B)
                                            : Colors.white,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.male,
                                        color: const Color(0xFF23456B),
                                        size: 24.h,
                                      ),
                                      SizedBox(width: 2.w),
                                      Text(
                                        '男生',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontFamily: 'OtsutomeFont',
                                          color: const Color(0xFF23456B),
                                          fontWeight: FontWeight.bold,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 女性選項
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedGender = 2;
                                });
                              },
                              child: Container(
                                margin: EdgeInsets.only(left: 10.w),
                                height: 50.h,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color:
                                        _selectedGender == 2
                                            ? const Color(0xFF23456B)
                                            : Colors.white,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.female,
                                        color: const Color(0xFF23456B),
                                        size: 24.h,
                                      ),
                                      SizedBox(width: 2.w),
                                      Text(
                                        '女生',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontFamily: 'OtsutomeFont',
                                          color: const Color(0xFF23456B),
                                          fontWeight: FontWeight.bold,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 個人亮點描述輸入框
                Container(
                  margin: EdgeInsets.symmetric(vertical: 15.h),
                  width: context.widthPercent(0.8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 8.w, bottom: 8.h),
                        child: Text(
                          '關於我，想讓人知道的一件事！',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontFamily: 'OtsutomeFont',
                            color: const Color(0xFF23456B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 15.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xFF23456B),
                            width: 2,
                          ),
                        ),
                        child: SizedBox(
                          height: 100.h,
                          child: TextField(
                            controller: _personalDescController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: '例：我喜歡嘗試新的食物！',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: Colors.grey,
                                fontFamily: 'OtsutomeFont',
                                fontSize: 16.sp,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: TextStyle(
                              fontFamily: 'OtsutomeFont',
                              fontSize: 16.sp,
                              color: const Color(0xFF23456B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 彈性空間
                Expanded(child: Container()),

                // 底部按鈕區域
                Container(
                  margin: EdgeInsets.only(bottom: 40.h),
                  child: Column(
                    children: [
                      // 下一步按鈕
                      _isLoading
                          ? LoadingImage(
                            width: 60.w,
                            height: 60.h,
                            color: const Color(0xFFB33D1C),
                          )
                          : ImageButton(
                            text: '下一步',
                            imagePath: 'assets/images/ui/button/red_l.png',
                            width: 150.w,
                            height: 75.h,
                            onPressed: _handleNextStep,
                            isEnabled: _isFormValid(), // 根據表單有效性決定按鈕是否啟用
                          ),

                      // 進度指示器
                      Padding(
                        padding: EdgeInsets.only(top: 20.h),
                        child: const ProgressDotsIndicator(
                          totalSteps: 5,
                          currentStep: 2,
                        ),
                      ),
                    ],
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
