import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';
// 導入轉場動畫
// 下一個頁面

class FoodPreferencePage extends StatefulWidget {
  const FoodPreferencePage({super.key});

  @override
  State<FoodPreferencePage> createState() => _FoodPreferencePageState();
}

class _FoodPreferencePageState extends State<FoodPreferencePage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final Set<int> _selectedFoods = {}; // 用於存儲選中的食物ID
  bool _isLoading = false;

  // 食物類型列表 - 更新為目錄中提供的圖片
  final List<Map<String, dynamic>> _foodTypes = [
    {'id': 1, 'name': '台灣料理', 'image': 'assets/images/dish/taiwanese.png'},
    {'id': 2, 'name': '日式料理', 'image': 'assets/images/dish/japanese.png'},
    {'id': 3, 'name': '日式咖哩', 'image': 'assets/images/dish/japanese_curry.png'},
    {'id': 4, 'name': '韓式料理', 'image': 'assets/images/dish/korean.png'},
    {'id': 5, 'name': '泰式料理', 'image': 'assets/images/dish/thai.png'},
    {'id': 6, 'name': '義式料理', 'image': 'assets/images/dish/italian.png'},
    {'id': 7, 'name': '美式餐廳', 'image': 'assets/images/dish/american.png'},
    {'id': 8, 'name': '中式料理', 'image': 'assets/images/dish/chinese.png'},
    {'id': 9, 'name': '港式飲茶', 'image': 'assets/images/dish/hongkong.png'},
    {'id': 10, 'name': '印度料理', 'image': 'assets/images/dish/indian.png'},
    {'id': 11, 'name': '墨西哥菜', 'image': 'assets/images/dish/mexican.png'},
    {'id': 12, 'name': '越南料理', 'image': 'assets/images/dish/vietnamese.png'},
    {'id': 13, 'name': '素食料理', 'image': 'assets/images/dish/vegetarian.png'},
    {'id': 14, 'name': '漢堡速食', 'image': 'assets/images/dish/burger.png'},
    {'id': 15, 'name': '披薩料理', 'image': 'assets/images/dish/pizza.png'},
    {'id': 16, 'name': '燒烤料理', 'image': 'assets/images/dish/barbecue.png'},
    {'id': 17, 'name': '火鍋料理', 'image': 'assets/images/dish/hotpot.png'},
  ];

  // 處理返回按鈕
  void _handleBack() {
    // 使用NavigationService導航到profile_setup頁面
    final navigationService = NavigationService();
    navigationService.navigateToPreviousSetupStep(context, 'food_preference');
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

  // 處理下一步按鈕
  Future<void> _handleNextStep() async {
    if (_selectedFoods.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('請至少選擇一種食物類型')));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('您尚未登入，請先登入')));
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

      // 使用NavigationService進行導航
      if (mounted) {
        final navigationService = NavigationService();
        navigationService.navigateToNextSetupStep(context, 'food_preference');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('儲存資料失敗: $error')));
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
          // 系統返回按鍵被點擊時導航到profile_setup頁面
          Navigator.of(context).pushReplacementNamed('/profile_setup');
          return false; // 返回false阻止默認行為
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
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // 頂部標題和返回按鈕放在同一行
                    Padding(
                      padding: EdgeInsets.only(top: 40.h, bottom: 20.h),
                      child: Row(
                        children: [
                          // 左側返回按鈕
                          Padding(
                            padding: EdgeInsets.only(left: 20.w, bottom: 8.h),
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
                                fontSize: 30.sp,
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
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                            onTap: () => _toggleFoodSelection(food['id']),
                            child: Stack(
                              children: [
                                // 基本卡片容器
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(12.r),
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
                                              fontFamily: 'OtsutomeFont',
                                              color: const Color(0xFF23456B),
                                              fontWeight: FontWeight.bold,
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
                                          borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(12.r),
                                            bottomRight: Radius.circular(12.r),
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
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: const Color(0xFFB33D1C), // 橘色主題色
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

                    // 下一步按鈕區域
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 30.h),
                      alignment: Alignment.center,
                      child:
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
                                isEnabled: _isFormValid(), // 根據選擇狀態決定按鈕是否啟用
                              ),
                    ),

                    // 進度指示器
                    Padding(
                      padding: EdgeInsets.only(bottom: 20.h),
                      child: const ProgressDotsIndicator(
                        totalSteps: 5,
                        currentStep: 3,
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
