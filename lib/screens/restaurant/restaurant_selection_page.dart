import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/restaurant_service.dart';
import 'package:tuckin/utils/index.dart';

class RestaurantSelectionPage extends StatefulWidget {
  const RestaurantSelectionPage({super.key});

  @override
  State<RestaurantSelectionPage> createState() =>
      _RestaurantSelectionPageState();
}

class _RestaurantSelectionPageState extends State<RestaurantSelectionPage> {
  final NavigationService _navigationService = NavigationService();
  final RestaurantService _restaurantService = RestaurantService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  int? _selectedRestaurantId;
  final TextEditingController _mapLinkController = TextEditingController();
  final FocusNode _mapLinkFocusNode = FocusNode();
  bool _isSubmittingLink = false;
  bool _isValidLink = false;

  // 範例餐廳資料
  List<Map<String, dynamic>> _restaurantList = [];

  // 用戶自定義的推薦餐廳
  Map<String, dynamic>? _userRecommendedRestaurant;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _mapLinkFocusNode.dispose();
    _mapLinkController.dispose();
    super.dispose();
  }

  // 載入資料
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 從服務中獲取推薦餐廳列表
      final restaurants = await _restaurantService.getRecommendedRestaurants();

      setState(() {
        _restaurantList = restaurants;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('載入餐廳資料出錯: $e');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('載入餐廳資料失敗: $e')));
      }
    }
  }

  // 處理餐廳卡片點擊
  void _handleRestaurantTap(int restaurantId) {
    setState(() {
      if (_selectedRestaurantId == restaurantId) {
        _selectedRestaurantId = null; // 取消選擇
      } else {
        _selectedRestaurantId = restaurantId; // 選擇餐廳
      }
    });
  }

  // 檢查是否為有效的Google地圖連結
  bool _isGoogleMapLink(String link) {
    if (link.isEmpty) return false;

    // 檢查是否為Google Map連結（短網址或完整網址）
    final bool isGoogleMapsLink =
        link.contains('maps.google.com') ||
        link.contains('goo.gl/maps') ||
        link.contains('maps.app.goo.gl');

    return isGoogleMapsLink;
  }

  // 處理推薦餐廳按鈕點擊
  void _handleRecommendRestaurant() {
    _mapLinkController.clear();
    _isValidLink = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Container(
                width: 320.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: const Color(0xFF23456B), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 5.h),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 20.h),
                    // 標題
                    Text(
                      '推薦餐廳',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontFamily: 'OtsutomeFont',
                        color: const Color(0xFF23456B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // 改進的地圖連結輸入框
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 15.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: const Color(0xFF23456B),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 具有陰影效果的圖標
                            SizedBox(
                              width: 32.w,
                              height: 32.h,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  // 底部陰影圖片
                                  Positioned(
                                    left: 0,
                                    top: 4.h,
                                    child: Image.asset(
                                      'assets/images/icon/link.png',
                                      width: 24.w,
                                      height: 24.h,
                                      color: Colors.black.withOpacity(0.4),
                                      colorBlendMode: BlendMode.srcIn,
                                    ),
                                  ),
                                  // 主圖標
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    child: Image.asset(
                                      'assets/images/icon/link.png',
                                      width: 24.w,
                                      height: 24.h,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 10.w),
                            // 輸入框
                            Expanded(
                              child: TextField(
                                controller: _mapLinkController,
                                focusNode: _mapLinkFocusNode,
                                style: TextStyle(
                                  fontFamily: 'OtsutomeFont',
                                  fontSize: 16.sp,
                                  color: const Color(0xFF23456B),
                                ),
                                decoration: InputDecoration(
                                  hintText: '輸入Google地圖連結',
                                  hintStyle: TextStyle(
                                    fontSize: 16.sp,
                                    color: Colors.grey,
                                    fontFamily: 'OtsutomeFont',
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 15.h,
                                  ),
                                ),
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.done,
                                onChanged: (value) {
                                  final bool isValid = _isGoogleMapLink(value);
                                  if (isValid != _isValidLink) {
                                    setModalState(() {
                                      _isValidLink = isValid;
                                    });

                                    // 如果輸入有效，自動處理連結
                                    if (isValid && !_isSubmittingLink) {
                                      _mapLinkFocusNode.unfocus();
                                      setModalState(() {
                                        _isSubmittingLink = true;
                                      });

                                      _processMapLink(value)
                                          .then((_) {
                                            Navigator.pop(context);
                                          })
                                          .catchError((e) {
                                            setModalState(() {
                                              _isSubmittingLink = false;
                                            });
                                          });
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 提示文字
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 10.h,
                      ),
                      child: Text(
                        '請輸入Google地圖上餐廳的分享連結',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),

                    SizedBox(height: 15.h),

                    // 加載進度指示器或取消按鈕
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      child:
                          _isSubmittingLink
                              ? const LoadingImage(
                                width: 60,
                                height: 60,
                                color: Color(0xFF23456B),
                              )
                              : ImageButton(
                                text: '取消',
                                imagePath: 'assets/images/ui/button/blue_m.png',
                                width: 120.w,
                                height: 60.h,
                                onPressed: () {
                                  _mapLinkFocusNode.unfocus();
                                  Navigator.pop(context);
                                },
                              ),
                    ),

                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 處理Google地圖連結
  Future<void> _processMapLink(String mapLink) async {
    try {
      // 使用餐廳服務處理地圖連結
      final restaurantData = await _restaurantService.processMapLink(mapLink);

      // 更新推薦餐廳並選中
      setState(() {
        _userRecommendedRestaurant = restaurantData;
        _selectedRestaurantId = restaurantData['id'];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '已成功添加您推薦的餐廳',
            style: TextStyle(fontFamily: 'OtsutomeFont'),
          ),
        ),
      );
    } catch (e) {
      debugPrint('處理地圖連結出錯: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '無法處理地圖連結: $e',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
      rethrow; // 重新拋出異常讓調用者處理
    }
  }

  // 處理提交按鈕
  Future<void> _handleSubmit() async {
    if (_selectedRestaurantId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇一家餐廳')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 使用餐廳服務提交選擇的餐廳
      final success = await _restaurantService.submitSelectedRestaurant(
        _selectedRestaurantId!,
      );

      if (success && mounted) {
        // TODO: 實際流程會根據後端回應決定導航到哪個頁面
        // 使用導航服務導航到餐廳預訂頁面
        _navigationService.navigateToRestaurantReservation(context);

        // 原始邏輯 - 導航到晚餐資訊頁面
        // _navigationService.navigateToDinnerInfo(context);
      }
    } catch (e) {
      debugPrint('提交餐廳選擇出錯: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('提交失敗: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
                        // 頂部導航欄
                        HeaderBar(
                          title: '餐廳選擇',
                          onProfileTap: _handleProfileTap,
                        ),

                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 20.h),

                                // 提示文字
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                  ),
                                  child: Text(
                                    '請選擇一家餐廳：',
                                    style: TextStyle(
                                      fontSize: 20.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                SizedBox(height: 15.h),

                                // 餐廳列表
                                ..._restaurantList.map(
                                  (restaurant) => RestaurantCard(
                                    name: restaurant['name'],
                                    imageUrl: restaurant['imageUrl'],
                                    category: restaurant['category'],
                                    address: restaurant['address'],
                                    isSelected:
                                        _selectedRestaurantId ==
                                        restaurant['id'],
                                    onTap:
                                        () => _handleRestaurantTap(
                                          restaurant['id'],
                                        ),
                                    mapUrl: restaurant['mapUrl'],
                                  ),
                                ),

                                if (_userRecommendedRestaurant == null)
                                  SizedBox(height: 10.h),

                                // 用戶推薦的餐廳（如果有）
                                if (_userRecommendedRestaurant != null)
                                  RestaurantCard(
                                    name: _userRecommendedRestaurant!['name'],
                                    imageUrl:
                                        _userRecommendedRestaurant!['imageUrl'],
                                    category:
                                        _userRecommendedRestaurant!['category'],
                                    address:
                                        _userRecommendedRestaurant!['address'],
                                    isSelected:
                                        _selectedRestaurantId ==
                                        _userRecommendedRestaurant!['id'],
                                    onTap:
                                        () => _handleRestaurantTap(
                                          _userRecommendedRestaurant!['id'],
                                        ),
                                    mapUrl:
                                        _userRecommendedRestaurant!['mapUrl'],
                                  )
                                else
                                  // 推薦餐廳卡片
                                  RecommendRestaurantCard(
                                    onTap: _handleRecommendRestaurant,
                                  ),

                                SizedBox(height: 60.h),

                                // 提交按鈕
                                Center(
                                  child:
                                      _isSubmitting
                                          ? LoadingImage(
                                            width: 60.w,
                                            height: 60.h,
                                            color: const Color(0xFF23456B),
                                          )
                                          : ImageButton(
                                            text: '送出選擇',
                                            imagePath:
                                                'assets/images/ui/button/red_l.png',
                                            width: 160.w,
                                            height: 70.h,
                                            onPressed: _handleSubmit,
                                            isEnabled:
                                                _selectedRestaurantId != null,
                                          ),
                                ),

                                SizedBox(height: 30.h),
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
