import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/restaurant_service.dart';
import 'package:tuckin/services/matching_service.dart';
import 'package:tuckin/services/database_service.dart';
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
  final MatchingService _matchingService = MatchingService();
  final DatabaseService _databaseService = DatabaseService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  dynamic _selectedRestaurantId;
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
      // 獲取用戶當前的匹配群組
      final userMatchingInfo = await _matchingService.getCurrentMatchingInfo();

      // 載入投票餐廳
      List<Map<String, dynamic>> votedRestaurants = [];
      if (userMatchingInfo != null &&
          userMatchingInfo.containsKey('matching_group_id')) {
        votedRestaurants = await _restaurantService.getTopVotedRestaurants(
          userMatchingInfo['matching_group_id'],
        );
      }

      setState(() {
        _restaurantList = votedRestaurants;
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
  void _handleRestaurantTap(dynamic restaurantId) {
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
        link.contains('maps.app.goo.gl') ||
        link.contains('google.com/maps');

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
                      SizedBox(height: 15.h),
                      // 標題
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(horizontal: 15.w),
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                        child: Column(
                          children: [
                            // 圖標
                            SizedBox(
                              width: 55.w,
                              height: 55.h,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // 底部陰影
                                  Positioned(
                                    left: 0,
                                    top: 3.h,
                                    child: Image.asset(
                                      'assets/images/icon/add.png',
                                      width: 55.w,
                                      height: 55.h,
                                      color: Colors.black.withOpacity(0.4),
                                      colorBlendMode: BlendMode.srcIn,
                                    ),
                                  ),
                                  // 主圖像
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    child: Image.asset(
                                      'assets/images/icon/add.png',
                                      width: 55.w,
                                      height: 55.h,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10.h),

                      // 改進的地圖連結輸入框
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 15.w),
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
                                    final bool isValid = _isGoogleMapLink(
                                      value,
                                    );
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
                                              // 錯誤時關閉對話框，以顯示底部的錯誤提示
                                              Navigator.pop(context);
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
                          '請輸入 Google 地圖上餐廳的分享連結',
                          style: TextStyle(
                            fontFamily: 'OtsutomeFont',
                            fontSize: 14.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),

                      SizedBox(height: 5.h),

                      // 取消按鈕
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
                                  imagePath:
                                      'assets/images/ui/button/blue_m.png',
                                  width: 120.w,
                                  height: 60.h,
                                  textStyle: TextStyle(
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFFD1D1D1),
                                  ),
                                  onPressed: () {
                                    _mapLinkFocusNode.unfocus();
                                    Navigator.pop(context);
                                  },
                                ),
                      ),

                      SizedBox(height: 15.h),
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

      // 確保餐廳卡片更新並觸發投票標籤動畫
      // 為了觸發RestaurantCard在didUpdateWidget中的動畫效果
      // 先設為null再設回去，模擬點擊效果
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _selectedRestaurantId = null;
          });
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              setState(() {
                _selectedRestaurantId = restaurantData['id'];
              });
            }
          });
        }
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
            backgroundColor: const Color(0xFFB33D1C), // 深橘色背景
            content: Text(
              '無法處理地圖連結: $e',
              style: const TextStyle(
                fontFamily: 'OtsutomeFont',
                color: Colors.white,
              ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '請選擇一家餐廳',
            style: TextStyle(fontFamily: 'OtsutomeFont'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 使用餐廳服務提交選擇的餐廳
      final response = await _restaurantService.submitSelectedRestaurant(
        _selectedRestaurantId,
      );

      if (mounted) {
        // 檢查投票完成狀態
        final isVotingComplete = response['is_voting_complete'] == true;

        if (isVotingComplete) {
          // 投票已完成，導航到餐廳資訊頁面
          _navigationService.navigateToDinnerInfo(context);
        } else {
          // 投票未完成，更新用戶狀態為等待其他用戶
          await _databaseService.updateUserStatus(
            response['user_id'],
            'waiting_other_users',
          );

          // 然後導航到首頁（系統會自動根據用戶狀態重定向）
          _navigationService.navigateToHome(context);
        }
      }
    } catch (e) {
      debugPrint('提交餐廳選擇出錯: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB33D1C), // 深橘色背景
            content: Text(
              '提交失敗: $e',
              style: const TextStyle(
                fontFamily: 'OtsutomeFont',
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // 處理用戶頭像點擊
  void _handleProfileTap() {
    _navigationService.navigateToProfile(context);
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
              image: AssetImage('assets/images/background/bg2.png'),
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
                    : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 頂部導航欄 - 移到滾動區域內
                          HeaderBar(title: '餐廳選擇'),

                          SizedBox(height: 20.h),

                          // 提示文字
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Text(
                              '請選擇一家餐廳',
                              style: TextStyle(
                                fontSize: 22.sp,
                                fontFamily: 'OtsutomeFont',
                                color: const Color(0xFF23456B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          SizedBox(height: 15.h),

                          // 餐廳列表
                          ..._restaurantList.map((restaurant) {
                            // 添加調試信息
                            debugPrint(
                              '餐廳卡片數據: ${restaurant['name']}, 票數: ${restaurant['votes']}',
                            );

                            return RestaurantCard(
                              name: restaurant['name'],
                              imageUrl: restaurant['imageUrl'],
                              category: restaurant['category'],
                              address: restaurant['address'],
                              isSelected:
                                  _selectedRestaurantId == restaurant['id'],
                              onTap:
                                  () => _handleRestaurantTap(restaurant['id']),
                              mapUrl: restaurant['mapUrl'],
                              voteCount: restaurant['votes'],
                            );
                          }),

                          // 用戶推薦的餐廳（如果有）
                          if (_userRecommendedRestaurant != null)
                            RestaurantCard(
                              name: _userRecommendedRestaurant!['name'],
                              imageUrl: _userRecommendedRestaurant!['imageUrl'],
                              category: _userRecommendedRestaurant!['category'],
                              address: _userRecommendedRestaurant!['address'],
                              isSelected:
                                  _selectedRestaurantId ==
                                  _userRecommendedRestaurant!['id'],
                              onTap:
                                  () => _handleRestaurantTap(
                                    _userRecommendedRestaurant!['id'],
                                  ),
                              mapUrl: _userRecommendedRestaurant!['mapUrl'],
                            )
                          else
                            // 推薦餐廳卡片
                            RecommendRestaurantCard(
                              onTap: _handleRecommendRestaurant,
                            ),

                          SizedBox(height: 40.h),

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
                                      isEnabled: _selectedRestaurantId != null,
                                    ),
                          ),

                          SizedBox(height: 30.h),
                        ],
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}
