import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileSetupPage extends StatefulWidget {
  final bool isFromProfile;

  const ProfileSetupPage({super.key, this.isFromProfile = false});

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
  bool _isDataLoaded = false;
  bool _hasBackPressed = false; // 追蹤是否已按過返回鍵

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    // 添加監聽器，當暱稱輸入框變更時重新渲染頁面
    _nicknameController.addListener(_updateButtonState);
  }

  // 載入用戶資料
  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 獲取當前用戶
      final currentUser = await _authService.getCurrentUser();

      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '請先登入您的帳號',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
              duration: Duration(seconds: 2),
            ),
          );
          // 延遲一下再導航，讓用戶看到提示訊息
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            }
          });
        }
        return;
      }

      if (widget.isFromProfile) {
        // 如果是從profile頁面導航過來的，載入用戶資料
        try {
          final userProfile = await _databaseService.getUserCompleteProfile(
            currentUser.id,
          );

          if (userProfile['profile'] != null) {
            final profile = userProfile['profile'];

            // 設置暱稱
            if (profile['nickname'] != null) {
              _nicknameController.text = profile['nickname'];
            }

            // 設置性別
            if (profile['gender'] != null) {
              if (profile['gender'] == 'male') {
                _selectedGender = 1;
              } else if (profile['gender'] == 'female') {
                _selectedGender = 2;
              }
            }

            // 設置個人描述
            if (profile['personal_desc'] != null) {
              _personalDescController.text = profile['personal_desc'];
            }

            setState(() {
              _isDataLoaded = true;
            });
          }
        } catch (e) {
          debugPrint('載入用戶資料出錯: $e');
        }
      } else {
        // 檢查用戶是否已完成設定
        final hasCompleted = await _databaseService.hasCompletedSetup(
          currentUser.id,
        );

        // 如果已完成設定，直接導航到主頁
        if (hasCompleted && mounted) {
          try {
            await _databaseService.updateUserStatus(currentUser.id, 'booking');

            // 設置一個標誌表示是新用戶第一次使用
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_new_user', true);
          } catch (error) {
            debugPrint('更新用戶狀態出錯: $error');
          }
          final navigationService = NavigationService();
          navigationService.navigateToDinnerReservation(context);
        }
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

  // 處理返回按鈕
  void _handleBack() {
    if (widget.isFromProfile) {
      // 如果是從profile頁面導航過來的，顯示確認對話框
      showCustomConfirmationDialog(
        context: context,
        iconPath: 'assets/images/icon/save.png',
        content: '您尚未儲存資料，\n是否要儲存後離開？',
        cancelButtonText: '不用',
        confirmButtonText: '儲存',
        onCancel: () {
          // 不儲存，直接返回
          Navigator.of(context).pop(); // 先關閉對話框
          Navigator.of(context).pop(); // 然後返回上一頁
        },
        onConfirm: () async {
          // 關閉對話框
          Navigator.of(context).pop();
          // 執行儲存操作
          if (_isFormValid()) {
            await _handleNextStep();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '請填寫必填項目',
                  style: TextStyle(fontFamily: 'OtsutomeFont'),
                ),
              ),
            );
          }
        },
      );
    } else {
      // 顯示提示訊息，告知用戶無法返回
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '請完成基本資料設定',
            style: TextStyle(fontFamily: 'OtsutomeFont'),
          ),
        ),
      );
    }
  }

  // 處理下一步或完成按鈕
  Future<void> _handleNextStep() async {
    // 檢查是否有必填項目未填
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請輸入暱稱', style: TextStyle(fontFamily: 'OtsutomeFont')),
        ),
      );
      return;
    }

    if (_selectedGender == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '請選擇生理性別',
            style: TextStyle(fontFamily: 'OtsutomeFont'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 獲取當前用戶
      final currentUser = await _authService.getCurrentUser();

      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '請先登入您的帳號',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
              duration: Duration(seconds: 2),
            ),
          );
          // 延遲一下再導航，讓用戶看到提示訊息
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            }
          });
        }
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

      if (mounted) {
        if (widget.isFromProfile) {
          // 如果是從profile頁面導航過來的，保存後返回profile頁面
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '個人資料更新成功',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
            ),
          );
          Navigator.of(context).pop();
        } else {
          // 使用NavigationService進行導航
          final navigationService = NavigationService();
          navigationService.navigateToNextSetupStep(context, 'profile_setup');
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '儲存資料失敗: $error',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
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
      // 根據來源決定系統返回按鈕行為
      onWillPop: () async {
        _handleBack();
        // 阻止默認返回行為，讓我們的_handleBack邏輯決定是否返回
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
            child:
                _isLoading && !_isDataLoaded
                    ? Center(
                      child: LoadingImage(
                        width: 60.w,
                        height: 60.h,
                        color: const Color(0xFFB33D1C),
                      ),
                    )
                    : Column(
                      children: [
                        // 頂部標題和返回按鈕
                        Padding(
                          padding: EdgeInsets.only(top: 25.h, bottom: 10.h),
                          child: Row(
                            children: [
                              // 左側返回按鈕 - 只在從profile頁面來時顯示
                              if (widget.isFromProfile)
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: 20.w,
                                    bottom: 8.h,
                                  ),
                                  child: BackIconButton(
                                    onPressed: _handleBack,
                                    width: 35.w,
                                    height: 35.h,
                                  ),
                                ),
                              // 中央標題
                              Expanded(
                                child: Text(
                                  '基本資料設定',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 25.sp,
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFF23456B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // 為了平衡布局，添加一個空白區域
                              if (widget.isFromProfile) SizedBox(width: 55.w),
                            ],
                          ),
                        ),

                        // 暱稱輸入框
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          margin: EdgeInsets.symmetric(vertical: 10.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(left: 8.w),
                                child: Text(
                                  '綽號',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFF23456B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconTextInput(
                                hintText: '請輸入綽號',
                                iconPath: 'assets/images/icon/user_profile.png',
                                controller: _nicknameController,
                              ),
                            ],
                          ),
                        ),

                        // 生理性別選擇
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 5.h),
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  left: 8.w,
                                  bottom: 8.h,
                                ),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
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
                                                  color: const Color(
                                                    0xFF23456B,
                                                  ),
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
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
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
                                                  color: const Color(
                                                    0xFF23456B,
                                                  ),
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
                          margin: EdgeInsets.symmetric(vertical: 20.h),
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  left: 8.w,
                                  bottom: 8.h,
                                ),
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
                              // 下一步或完成按鈕
                              _isLoading
                                  ? Container(
                                    alignment: Alignment.center,
                                    child: LoadingImage(
                                      width: 60.w,
                                      height: 60.h,
                                      color: const Color(0xFFB33D1C),
                                    ),
                                  )
                                  : ImageButton(
                                    text: widget.isFromProfile ? '完成' : '下一步',
                                    imagePath:
                                        'assets/images/ui/button/red_l.png',
                                    width: 150.w,
                                    height: 70.h,
                                    onPressed: _handleNextStep,
                                    isEnabled:
                                        _isFormValid(), // 根據表單有效性決定按鈕是否啟用
                                  ),

                              // 進度指示器 - 只在非profile來源時顯示
                              if (!widget.isFromProfile)
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
