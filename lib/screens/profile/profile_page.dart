import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:tuckin/screens/onboarding/profile_setup_page.dart';
import 'package:tuckin/screens/onboarding/food_preference_page.dart';
import 'package:tuckin/screens/onboarding/personality_test_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = false;
  bool _isLoggingOut = false;
  bool _isDeletingAccount = false;
  Map<String, dynamic> _userProfile = {};
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final profile = await _databaseService.getUserProfile(currentUser.id);
        if (profile != null) {
          setState(() {
            _userProfile = profile;
            _nickname = profile['nickname'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('加載用戶資料錯誤: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 建立陰影效果的圖標
  Widget _buildIconWithShadow(String iconPath, {double size = 32}) {
    final adaptiveShadowOffset = 2.h;

    return SizedBox(
      width: size.w,
      height: size.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 底部陰影
          Positioned(
            left: 0,
            top: adaptiveShadowOffset,
            child: Image.asset(
              iconPath,
              width: size.w,
              height: size.h,
              color: Colors.black.withValues(alpha: .4),
              colorBlendMode: BlendMode.srcIn,
            ),
          ),
          // 主圖像
          Positioned(
            top: 0,
            left: 0,
            child: Image.asset(iconPath, width: size.w, height: size.h),
          ),
        ],
      ),
    );
  }

  // 個人資料設定項目
  Widget _buildSettingItem({
    required String iconPath,
    required String title,
    required VoidCallback onTap,
    double iconSize = 32,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildIconWithShadow(iconPath, size: iconSize),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color(0xFF23456B),
                  height: 1.7,
                ),
              ),
            ),
            // Icon(
            //   Icons.arrow_forward_ios,
            //   color: const Color(0xFF23456B),
            //   size: 16.w,
            // ),
          ],
        ),
      ),
    );
  }

  // 顯示登出確認對話框
  void _showLogoutConfirmDialog() {
    // 設置狀態變量
    setState(() {
      _isLoggingOut = false;
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          // 使用 StatefulBuilder 使對話框能夠更新狀態
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  width: 320.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: Offset(0, 8.h),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 30.h),
                      // 圖標
                      SizedBox(
                        width: 60.w,
                        height: 60.h,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // 底部陰影
                            Positioned(
                              left: 0,
                              top: 3.h,
                              child: Image.asset(
                                'assets/images/icon/logout.png',
                                width: 60.w,
                                height: 60.h,
                                color: Colors.black.withOpacity(0.4),
                                colorBlendMode: BlendMode.srcIn,
                              ),
                            ),
                            // 主圖像
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Image.asset(
                                'assets/images/icon/logout.png',
                                width: 60.w,
                                height: 60.h,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 15.h),
                      // 內容
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(horizontal: 20.w),
                        padding: EdgeInsets.symmetric(
                          vertical: 10.h,
                          horizontal: 10.w,
                        ),

                        child: Text(
                          '確定要登出嗎？\n要用功能需要再登入喔',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontFamily: 'OtsutomeFont',
                            color: const Color(0xFF23456B),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      // 按鈕
                      _isLoggingOut
                          ? Center(
                            child: LoadingImage(
                              width: 60.w,
                              height: 60.h,
                              color: const Color(0xFFB33D1C),
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ImageButton(
                                text: '取消',
                                imagePath: 'assets/images/ui/button/blue_m.png',
                                width: 110.w,
                                height: 55.h,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                textStyle: TextStyle(
                                  fontSize: 16.sp,
                                  color: const Color(0xFFD1D1D1),
                                  fontFamily: 'OtsutomeFont',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 20.w),
                              ImageButton(
                                text: '確定',
                                imagePath: 'assets/images/ui/button/red_m.png',
                                width: 110.w,
                                height: 55.h,
                                onPressed: () async {
                                  // 設置登出中狀態
                                  setState(() {
                                    _isLoggingOut = true;
                                  });

                                  try {
                                    await _authService.signOut();

                                    // 延遲一下以確保操作完成
                                    await Future.delayed(
                                      const Duration(seconds: 1),
                                    );

                                    if (mounted) {
                                      Navigator.of(context).pop(); // 關閉對話框
                                      final navigationService =
                                          NavigationService();
                                      navigationService.navigateAfterSignOut(
                                        context,
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('登出錯誤: $e');
                                    // 發生錯誤時重置登出狀態
                                    setState(() {
                                      _isLoggingOut = false;
                                    });
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '登出失敗: ${e.toString()}',
                                            style: const TextStyle(
                                              fontFamily: 'OtsutomeFont',
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                textStyle: TextStyle(
                                  fontSize: 16.sp,
                                  color: const Color(0xFFD1D1D1),
                                  fontFamily: 'OtsutomeFont',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      SizedBox(height: 30.h),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 顯示刪除帳號確認對話框
  void _showDeleteAccountConfirmDialog() {
    setState(() {
      _isDeletingAccount = false;
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  width: 320.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: Offset(0, 8.h),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 30.h),
                      // 圖標
                      SizedBox(
                        width: 60.w,
                        height: 60.h,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // 底部陰影
                            Positioned(
                              left: 0,
                              top: 3.h,
                              child: Image.asset(
                                'assets/images/icon/delete.png',
                                width: 60.w,
                                height: 60.h,
                                color: Colors.black.withOpacity(0.4),
                                colorBlendMode: BlendMode.srcIn,
                              ),
                            ),
                            // 主圖像
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Image.asset(
                                'assets/images/icon/delete.png',
                                width: 60.w,
                                height: 60.h,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 15.h),
                      // 內容
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(horizontal: 20.w),
                        padding: EdgeInsets.symmetric(
                          vertical: 10.h,
                          horizontal: 10.w,
                        ),
                        child: Text(
                          '確定刪除帳號嗎？\n這一步不能後悔喔，所有資料都會被永久刪除',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontFamily: 'OtsutomeFont',
                            color: const Color(0xFF23456B),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),
                      // 按鈕
                      _isDeletingAccount
                          ? Center(
                            child: LoadingImage(
                              width: 60.w,
                              height: 60.h,
                              color: const Color(0xFFB33D1C),
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ImageButton(
                                text: '取消',
                                imagePath: 'assets/images/ui/button/blue_m.png',
                                width: 110.w,
                                height: 55.h,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                textStyle: TextStyle(
                                  fontSize: 16.sp,
                                  color: const Color(0xFFD1D1D1),
                                  fontFamily: 'OtsutomeFont',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 20.w),
                              ImageButton(
                                text: '確定',
                                imagePath: 'assets/images/ui/button/red_m.png',
                                width: 110.w,
                                height: 55.h,
                                onPressed: () async {
                                  // 設置刪除中狀態
                                  setState(() {
                                    _isDeletingAccount = true;
                                  });

                                  try {
                                    // 刪除用戶資料
                                    final currentUser =
                                        await _authService.getCurrentUser();
                                    if (currentUser != null) {
                                      // 檢查用戶是否可以刪除帳號
                                      final canDelete = await _databaseService
                                          .canDeleteAccount(currentUser.id);

                                      if (!canDelete) {
                                        // 如果不能刪除，顯示提示消息
                                        setState(() {
                                          _isDeletingAccount = false;
                                        });

                                        if (mounted) {
                                          Navigator.of(context).pop(); // 關閉對話框
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '您目前正在聚餐流程中，無法刪除帳號',
                                                style: const TextStyle(
                                                  fontFamily: 'OtsutomeFont',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return;
                                      }

                                      // 可以刪除帳號，繼續原來的刪除流程
                                      await _databaseService.deleteUser(
                                        currentUser.id,
                                      );
                                    }

                                    // 延遲一下以確保操作完成
                                    await Future.delayed(
                                      const Duration(seconds: 1),
                                    );

                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '刪除帳號成功',
                                            style: const TextStyle(
                                              fontFamily: 'OtsutomeFont',
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    // 登出用戶
                                    await _authService.signOut();
                                    if (mounted) {
                                      Navigator.of(context).pop(); // 關閉對話框
                                      final navigationService =
                                          NavigationService();
                                      navigationService.navigateAfterSignOut(
                                        context,
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('刪除帳號錯誤: $e');
                                    // 發生錯誤時重置刪除狀態
                                    setState(() {
                                      _isDeletingAccount = false;
                                    });
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '刪除帳號失敗: ${e.toString()}',
                                            style: const TextStyle(
                                              fontFamily: 'OtsutomeFont',
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                textStyle: TextStyle(
                                  fontSize: 16.sp,
                                  color: const Color(0xFFD1D1D1),
                                  fontFamily: 'OtsutomeFont',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      SizedBox(height: 30.h),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 顯示隱私政策對話框
  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const PrivacyPolicyDialog();
      },
    );
  }

  // 打開關於我們的網頁
  void _openAboutUsWebpage() async {
    final Uri url = Uri.parse('https://github.com/ncchen99/Tuckin');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('無法開啟網頁')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 25.h),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 中央品牌標誌
                    Center(
                      child: SizedBox(
                        height: 35.h,
                        width: 155.w,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // 底部陰影層
                            Positioned(
                              top: 3.h,
                              left: 0,
                              child: Image.asset(
                                'assets/images/icon/tuckin_t_brand.png',
                                height: 35.h,
                                fit: BoxFit.contain,
                                color: Colors.black.withValues(alpha: .4),
                                colorBlendMode: BlendMode.srcIn,
                              ),
                            ),
                            // 主圖層
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Image.asset(
                                'assets/images/icon/tuckin_t_brand.png',
                                height: 35.h,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 返回按鈕，絕對定位在左側
                    Positioned(
                      left: 0,
                      child: BackIconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        width: 35.w,
                        height: 35.h,
                      ),
                    ),
                  ],
                ),
              ),

              // 設定項目列表
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                  child: Column(
                    children: [
                      // 更改基本資料
                      _buildSettingItem(
                        iconPath: 'assets/images/icon/user_profile.png',
                        title: '更改基本資料',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      ProfileSetupPage(isFromProfile: true),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 15.h),

                      // 更改飲食偏好
                      _buildSettingItem(
                        iconPath: 'assets/images/dish/american.png',
                        title: '更改飲食偏好',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      FoodPreferencePage(isFromProfile: true),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 15.h),

                      // 重新進行個性測驗
                      _buildSettingItem(
                        iconPath: 'assets/images/icon/brain.png',
                        title: '重新進行測驗',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      PersonalityTestPage(isFromProfile: true),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 15.h),

                      // 聚餐歷史記錄
                      _buildSettingItem(
                        iconPath: 'assets/images/icon/history.png',
                        title: '聚餐歷史記錄',
                        onTap: () {
                          // 尚未建立
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '此功能尚未開放',
                                style: TextStyle(fontFamily: 'OtsutomeFont'),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 15.h),

                      // 隱私與條款
                      _buildSettingItem(
                        iconPath: 'assets/images/icon/shield.png',
                        title: '隱私與條款',
                        onTap: _showPrivacyPolicyDialog,
                      ),
                      SizedBox(height: 15.h),

                      // 關於我們
                      _buildSettingItem(
                        iconPath: 'assets/images/icon/tuckin_t_brand.png',
                        title: '關於我們',
                        onTap: _openAboutUsWebpage,
                      ),
                      SizedBox(height: 35.h),

                      // 登出
                      _buildSettingItem(
                        iconPath: 'assets/images/icon/logout.png',
                        title: '登出',
                        onTap: _showLogoutConfirmDialog,
                      ),
                      SizedBox(height: 15.h),

                      // 刪除帳號
                      _buildSettingItem(
                        iconPath: 'assets/images/icon/delete.png',
                        title: '刪除帳號',
                        onTap: _showDeleteAccountConfirmDialog,
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
