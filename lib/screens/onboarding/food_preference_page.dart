import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';
// 導入轉場動畫
// 下一個頁面

class FoodPreferencePage extends StatefulWidget {
  final bool isFromProfile;

  const FoodPreferencePage({super.key, this.isFromProfile = false});

  @override
  State<FoodPreferencePage> createState() => _FoodPreferencePageState();
}

class _FoodPreferencePageState extends State<FoodPreferencePage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final Set<int> _selectedFoods = {}; // 用於存儲選中的食物ID
  bool _isLoading = false;
  bool _isDataLoaded = false;
  final bool _hasBackPressed = false; // 追蹤是否已按過返回鍵

  // 食物類型列表 - 更新為目錄中提供的圖片
  final List<Map<String, dynamic>> _foodTypes = [
    {'id': 1, 'name': '台灣料理', 'image': 'assets/images/dish/taiwanese.webp'},
    {'id': 2, 'name': '日式料理', 'image': 'assets/images/dish/japanese.webp'},
    {
      'id': 3,
      'name': '日式咖哩',
      'image': 'assets/images/dish/japanese_curry.webp',
    },
    {'id': 4, 'name': '韓式料理', 'image': 'assets/images/dish/korean.webp'},
    {'id': 5, 'name': '泰式料理', 'image': 'assets/images/dish/thai.webp'},
    {'id': 6, 'name': '義式料理', 'image': 'assets/images/dish/italian.webp'},
    {'id': 7, 'name': '美式餐廳', 'image': 'assets/images/dish/american.webp'},
    {'id': 8, 'name': '中式料理', 'image': 'assets/images/dish/chinese.webp'},
    {'id': 9, 'name': '港式飲茶', 'image': 'assets/images/dish/hongkong.webp'},
    {'id': 10, 'name': '印度料理', 'image': 'assets/images/dish/indian.webp'},
    {'id': 11, 'name': '墨西哥菜', 'image': 'assets/images/dish/mexican.webp'},
    {'id': 12, 'name': '越南料理', 'image': 'assets/images/dish/vietnamese.webp'},
    {'id': 14, 'name': '漢堡速食', 'image': 'assets/images/dish/burger.webp'},
    {'id': 15, 'name': '披薩料理', 'image': 'assets/images/dish/pizza.webp'},
    {'id': 17, 'name': '火鍋料理', 'image': 'assets/images/dish/hotpot.webp'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserFoodPreferences();
  }

  // 加載用戶的飲食偏好
  Future<void> _loadUserFoodPreferences() async {
    if (widget.isFromProfile) {
      setState(() {
        _isLoading = true;
      });

      try {
        final currentUser = await _authService.getCurrentUser();
        if (currentUser != null) {
          final userProfile = await _databaseService.getUserCompleteProfile(
            currentUser.id,
          );

          if (userProfile['food_preferences'] != null) {
            final foodPreferences = List<int>.from(
              userProfile['food_preferences'],
            );
            setState(() {
              _selectedFoods.clear();
              _selectedFoods.addAll(foodPreferences);
              _isDataLoaded = true;
            });
          }
        }
      } catch (e) {
        debugPrint('載入用戶飲食偏好出錯: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // 處理返回按鈕
  void _handleBack() {
    if (widget.isFromProfile) {
      // 如果是從profile頁面導航過來的，顯示確認對話框
      showCustomConfirmationDialog(
        context: context,
        iconPath: 'assets/images/icon/save.webp',
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
                  '請至少選擇一種食物類型',
                  style: TextStyle(fontFamily: 'OtsutomeFont'),
                ),
              ),
            );
          }
        },
      );
    } else {
      // 否則使用正常的onboarding流程返回
      final navigationService = NavigationService();
      navigationService.navigateToPreviousSetupStep(context, 'food_preference');
    }
  }

  // 處理食物選擇
  void _toggleFoodSelection(int foodId) {
    setState(() {
      if (_selectedFoods.contains(foodId)) {
        _selectedFoods.remove(foodId);
      } else {
        _selectedFoods.add(foodId);
      }
    });
  }

  // 處理下一步或完成按鈕
  Future<void> _handleNextStep() async {
    if (_selectedFoods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '請至少選擇一種食物類型',
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
                '您尚未登入，請先登入',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
            ),
          );
        }
        return;
      }

      // 轉換選擇的食物ID為列表
      final foodPreferences = _selectedFoods.toList();

      // 儲存用戶食物偏好到 Supabase
      await _databaseService.updateUserFoodPreferences(
        currentUser.id,
        foodPreferences,
      );

      if (mounted) {
        if (widget.isFromProfile) {
          // 如果是從profile頁面導航過來的，保存後返回profile頁面
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '飲食偏好更新成功',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
            ),
          );
          Navigator.of(context).pop();
        } else {
          // 否則繼續正常的onboarding流程
          final navigationService = NavigationService();
          navigationService.navigateToNextSetupStep(context, 'food_preference');
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

  // 檢查是否至少選擇了一種食物類型
  bool _isFormValid() {
    return _selectedFoods.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('FoodPreferencePage: build 方法被調用');

    try {
      return WillPopScope(
        onWillPop: () async {
          // 系統返回按鍵根據來源決定行為
          _handleBack();
          return false; // 返回false阻止默認行為
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background/bg2.jpg'),
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
                      : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            // 頂部標題和返回按鈕放在同一行
                            Padding(
                              padding: EdgeInsets.only(top: 25.h, bottom: 20.h),
                              child: Row(
                                children: [
                                  // 左側返回按鈕
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
                                      '飲食偏好設定',
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
                                  SizedBox(width: 55.w),
                                ],
                              ),
                            ),

                            // 提示文字
                            Padding(
                              padding: EdgeInsets.only(bottom: 20.h),
                              child: Text(
                                '請選擇您喜愛的食物類型 (可複選)',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontFamily: 'OtsutomeFont',
                                  color: const Color(0xFF23456B),
                                ),
                              ),
                            ),

                            // 食物選擇網格
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: GridView.builder(
                                physics:
                                    const NeverScrollableScrollPhysics(), // 禁用網格自身的滾動
                                shrinkWrap: true, // 讓網格根據內容收縮
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 15.w,
                                      mainAxisSpacing: 15.h,
                                      childAspectRatio: 1.8, // 控制卡片長寬比
                                    ),
                                itemCount: _foodTypes.length,
                                itemBuilder: (context, index) {
                                  final food = _foodTypes[index];
                                  final isSelected = _selectedFoods.contains(
                                    food['id'],
                                  );

                                  return GestureDetector(
                                    onTap:
                                        () => _toggleFoodSelection(food['id']),
                                    child: Stack(
                                      children: [
                                        // 基本卡片容器
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.9,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12.r,
                                            ),
                                          ),
                                          clipBehavior:
                                              Clip.hardEdge, // 使用clipBehavior來防止內容溢出
                                          child: Stack(
                                            children: [
                                              // 食物名稱
                                              Positioned(
                                                left: 10.w,
                                                top: 0,
                                                bottom: 0,
                                                child: Center(
                                                  child: Text(
                                                    food['name'],
                                                    style: TextStyle(
                                                      fontSize: 16.sp,
                                                      fontFamily:
                                                          'OtsutomeFont',
                                                      color: const Color(
                                                        0xFF23456B,
                                                      ),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // 食物圖片，修改為在容器內顯示
                                              Positioned(
                                                right: -28.w,
                                                top: 0,
                                                bottom: -32.h,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                        topRight:
                                                            Radius.circular(
                                                              12.r,
                                                            ),
                                                        bottomRight:
                                                            Radius.circular(
                                                              12.r,
                                                            ),
                                                      ),
                                                  child: Container(
                                                    width: 100.w,
                                                    height: double.infinity,
                                                    alignment: Alignment.center,
                                                    child: Image.asset(
                                                      food['image'],
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        debugPrint(
                                                          'FoodPreferencePage: 圖片加載錯誤 ${food['image']}: $error',
                                                        );
                                                        return const Icon(
                                                          Icons.error,
                                                          color: Colors.red,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // 選中的邊框 - 置於最上層，改為橘色
                                        if (isSelected)
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(12.r),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFFB33D1C,
                                                ), // 橘色主題色
                                                width: 3,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                            // 下一步或完成按鈕區域
                            Container(
                              margin: EdgeInsets.only(top: 20.h, bottom: 20.h),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 20.h,
                                    ),
                                    child:
                                        _isLoading
                                            ? LoadingImage(
                                              width: 60.w,
                                              height: 60.h,
                                              color: const Color(0xFFB33D1C),
                                            )
                                            : ImageButton(
                                              text:
                                                  widget.isFromProfile
                                                      ? '完成'
                                                      : '下一步',
                                              imagePath:
                                                  'assets/images/ui/button/red_l.webp',
                                              width: 150.w,
                                              height: 70.h,
                                              onPressed: _handleNextStep,
                                              isEnabled:
                                                  _isFormValid(), // 根據選擇狀態決定按鈕是否啟用
                                            ),
                                  ),
                                  // 進度指示器 - 只在非profile來源時顯示
                                  if (!widget.isFromProfile)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: 15.h,
                                        bottom: 10.h,
                                      ),
                                      child: const ProgressDotsIndicator(
                                        totalSteps: 5,
                                        currentStep: 3,
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
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('FoodPreferencePage: 構建UI時發生錯誤: $e');
      debugPrint('堆疊追蹤: $stackTrace');

      // 在發生錯誤時顯示一個簡單的錯誤頁面
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.red),
              const SizedBox(height: 20),
              const Text('頁面加載失敗', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 10),
              Text('錯誤: $e', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }
  }
}
