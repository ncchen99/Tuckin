import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:url_launcher/url_launcher.dart';

class RestaurantReservationPage extends StatefulWidget {
  const RestaurantReservationPage({super.key});

  @override
  State<RestaurantReservationPage> createState() =>
      _RestaurantReservationPageState();
}

class _RestaurantReservationPageState extends State<RestaurantReservationPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;
  bool _isPageMounted = false;
  bool _isConfirming = false;

  // 餐廳相關資訊
  final Map<String, dynamic> _restaurantInfo = {};
  String? _restaurantName;
  String? _restaurantAddress;
  String? _restaurantImageUrl;
  String? _restaurantCategory;
  String? _restaurantMapUrl;
  String? _restaurantPhone;
  String? _restaurantWebsite;
  String? _restaurantReservationNote;

  @override
  void initState() {
    super.initState();
    _loadRestaurantInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isPageMounted = true;
        });
        debugPrint('RestaurantReservationPage 完全渲染');
      }
    });
  }

  @override
  void dispose() {
    _isPageMounted = false;
    super.dispose();
  }

  Future<void> _loadRestaurantInfo() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // 這裡應該從資料庫獲取餐廳資訊
        // 示例資料
        setState(() {
          _restaurantName = "Serendipity 不經意的美好 10199";
          _restaurantAddress = "台北市信義區松仁路 100 號 1F 之 1";
          _restaurantImageUrl =
              "https://images.unsplash.com/photo-1552566626-52f8b828add9?q=80&w=2070";
          _restaurantCategory = "日式料理";
          _restaurantMapUrl = "https://maps.google.com/?q=台北市信義區松仁路100號1F之1";
          _restaurantPhone = "02-2345-6789";
          _restaurantWebsite = "https://example.com/restaurant";
          _restaurantReservationNote = "建議提前3天預訂，可接受6-12人的團體訂位。";
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('獲取餐廳資訊時出錯: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      debugPrint('嘗試撥打電話: $phoneNumber');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw '無法撥打電話：$phoneNumber';
      }
    } catch (e) {
      debugPrint('撥打電話時出錯: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openWebsite(String websiteUrl) async {
    final Uri url = Uri.parse(websiteUrl);
    try {
      debugPrint('嘗試開啟網站: $websiteUrl');
      launchUrl(url, mode: LaunchMode.externalApplication)
          .then((success) {
            if (!success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '無法開啟網站',
                    style: TextStyle(fontFamily: 'OtsutomeFont'),
                  ),
                ),
              );
            }
          })
          .catchError((error) {
            debugPrint('開啟網站出錯: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$error',
                    style: const TextStyle(fontFamily: 'OtsutomeFont'),
                  ),
                ),
              );
            }
          });
    } catch (e) {
      debugPrint('開啟網站時出錯: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '開啟網站時出錯: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openMap(String? mapUrl) async {
    try {
      if (mapUrl != null) {
        final Uri url = Uri.parse(mapUrl);
        debugPrint('嘗試打開地圖URL: $url');
        launchUrl(url, mode: LaunchMode.externalApplication)
            .then((success) {
              if (!success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '無法開啟地圖',
                      style: TextStyle(fontFamily: 'OtsutomeFont'),
                    ),
                  ),
                );
              }
            })
            .catchError((error) {
              debugPrint('打開地圖出錯: $error');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '打開地圖出錯: $error',
                      style: const TextStyle(fontFamily: 'OtsutomeFont'),
                    ),
                  ),
                );
              }
            });
      }
    } catch (e) {
      debugPrint('打開地圖時出錯: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '打開地圖時出錯: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleReservationConfirm() async {
    setState(() {
      _isConfirming = true;
    });

    try {
      // 這裡應該處理預訂確認的邏輯
      await Future.delayed(const Duration(seconds: 2)); // 模擬網絡請求

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '餐廳預訂資訊已確認',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );

        // 導航到下一個頁面
        _navigationService.navigateToDinnerInfo(context);
      }
    } catch (e) {
      debugPrint('確認預訂時出錯: $e');
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '確認預訂失敗: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleCannotReserve() async {
    // 這裡應該處理無法預訂的邏輯
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '已標記為無法預訂',
            style: TextStyle(fontFamily: 'OtsutomeFont'),
          ),
        ),
      );

      // 導航回上一頁或其他相應操作
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF23456B)),
            ),
          ),
        ),
      );
    }

    // 定義卡片寬度，確保一致性
    final cardWidth = MediaQuery.of(context).size.width - 48.w;

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
            child: Column(
              children: [
                // 頂部導航欄 - 使用預設顯示TUCKIN
                HeaderBar(title: '餐廳預訂'),

                // 主要內容
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        SizedBox(height: 40.h),

                        // 標題
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          child: Text(
                            '想請你幫忙訂位',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontFamily: 'OtsutomeFont',
                              color: const Color(0xFF23456B),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),

                        SizedBox(height: 40.h),

                        // 餐廳資訊卡片
                        Container(
                          width: cardWidth,
                          margin: EdgeInsets.symmetric(vertical: 8.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(15.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 5,
                                offset: Offset(0, 2.h),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // 餐廳圖片 - 恢復原始設計
                              ClipRRect(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(15.r),
                                  topRight: Radius.circular(15.r),
                                ),
                                child: GestureDetector(
                                  onTap: () => _openMap(_restaurantMapUrl),
                                  child:
                                      _restaurantImageUrl != null
                                          ? Image.network(
                                            _restaurantImageUrl!,
                                            width: double.infinity,
                                            height: 150.h,
                                            fit: BoxFit.cover,
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return Container(
                                                width: double.infinity,
                                                height: 150.h,
                                                color: Colors.grey[300],
                                                child: Icon(
                                                  Icons.restaurant,
                                                  color: Colors.grey[600],
                                                  size: 50.sp,
                                                ),
                                              );
                                            },
                                          )
                                          : Container(
                                            width: double.infinity,
                                            height: 150.h,
                                            color: Colors.grey[300],
                                            child: Icon(
                                              Icons.restaurant,
                                              color: Colors.grey[600],
                                              size: 50.sp,
                                            ),
                                          ),
                                ),
                              ),

                              // 餐廳詳細資訊
                              Padding(
                                padding: EdgeInsets.all(15.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 餐廳名稱
                                    Text(
                                      _restaurantName ?? '未指定餐廳',
                                      style: TextStyle(
                                        fontSize: 20.sp,
                                        fontFamily: 'OtsutomeFont',
                                        color: const Color(0xFF23456B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    SizedBox(height: 5.h),
                                    // 餐廳類別
                                    Text(
                                      _restaurantCategory ?? '未分類',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontFamily: 'OtsutomeFont',
                                        color: const Color(0xFF666666),
                                      ),
                                    ),

                                    SizedBox(height: 10.h),
                                    // 餐廳地址 - 可點擊
                                    GestureDetector(
                                      onTap: () => _openMap(_restaurantMapUrl),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _restaurantAddress ?? '地址未提供',
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                fontFamily: 'OtsutomeFont',
                                                color: const Color(0xFF23456B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 分隔線
                              Container(
                                height: 1,
                                color: Colors.grey[300],
                                margin: EdgeInsets.symmetric(horizontal: 12.w),
                              ),

                              // 聯絡資訊部分 - 分左右兩區塊
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 15.h,
                                  vertical: 15.h,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // 左側電話資訊
                                    SizedBox(
                                      width: cardWidth * 0.4,
                                      child: InkWell(
                                        onTap: () {
                                          if (_restaurantPhone != null) {
                                            _makePhoneCall(_restaurantPhone!);
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            // 電話圖標 - 使用指定的圖標並添加陰影效果
                                            Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 5.h,
                                              ),
                                              child: SizedBox(
                                                width: 35.w,
                                                height: 35.h,
                                                child: Stack(
                                                  clipBehavior:
                                                      Clip.none, // 允許陰影超出容器範圍
                                                  children: [
                                                    // 底部陰影
                                                    Positioned(
                                                      left: 0,
                                                      top: 2.h,
                                                      child: Image.asset(
                                                        'assets/images/icon/phone.png',
                                                        width: 35.w,
                                                        height: 35.h,
                                                        color: Colors.black
                                                            .withOpacity(0.4),
                                                        colorBlendMode:
                                                            BlendMode.srcIn,
                                                      ),
                                                    ),
                                                    // 主圖標
                                                    Image.asset(
                                                      'assets/images/icon/phone.png',
                                                      width: 35.w,
                                                      height: 35.h,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            SizedBox(width: 10.w),

                                            // 電話資訊文字
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '電話',
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
                                                  SizedBox(height: 2.h),
                                                  Text(
                                                    _restaurantPhone ?? '未提供',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontFamily:
                                                          'OtsutomeFont',
                                                      color: const Color(
                                                        0xFF666666,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 垂直分隔線
                                    Container(
                                      height: 45.h,
                                      width: 1.w,
                                      color: Colors.grey[300],
                                    ),

                                    // 右側網站部分
                                    SizedBox(
                                      width: cardWidth * 0.4,
                                      child: InkWell(
                                        onTap: () {
                                          if (_restaurantWebsite != null) {
                                            _openWebsite(_restaurantWebsite!);
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            // 網站圖標
                                            Padding(
                                              padding: EdgeInsets.only(
                                                bottom: 5.h,
                                              ),
                                              child: SizedBox(
                                                width: 35.w,
                                                height: 35.h,
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  children: [
                                                    // 底部陰影
                                                    Positioned(
                                                      left: 0,
                                                      top: 2.h,
                                                      child: Image.asset(
                                                        'assets/images/icon/link.png',
                                                        width: 35.w,
                                                        height: 35.h,
                                                        color: Colors.black
                                                            .withOpacity(0.4),
                                                        colorBlendMode:
                                                            BlendMode.srcIn,
                                                      ),
                                                    ),
                                                    // 主圖標
                                                    Image.asset(
                                                      'assets/images/icon/link.png',
                                                      width: 35.w,
                                                      height: 35.h,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 10.w),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '網站',
                                                    style: TextStyle(
                                                      fontSize: 16.sp,
                                                      fontFamily:
                                                          'OtsutomeFont',
                                                      color: const Color(
                                                        0xFF23456B,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 2.h),
                                                  Text(
                                                    _restaurantWebsite != null
                                                        ? '點擊前往'
                                                        : '未提供',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontFamily:
                                                          'OtsutomeFont',
                                                      color: const Color(
                                                        0xFF666666,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 60.h),

                        // 確認按鈕
                        Center(
                          child:
                              _isConfirming
                                  ? LoadingImage(
                                    width: 60.w,
                                    height: 60.h,
                                    color: const Color(0xFF23456B),
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // 左側藍色按鈕 - 這間無法
                                      ImageButton(
                                        text: '這間無法',
                                        imagePath:
                                            'assets/images/ui/button/blue_l.png',
                                        width: 150.w,
                                        height: 70.h,
                                        onPressed: _handleCannotReserve,
                                      ),
                                      SizedBox(width: 20.w),
                                      // 右側橘色按鈕 - 已確認
                                      ImageButton(
                                        text: '已確認',
                                        imagePath:
                                            'assets/images/ui/button/red_m.png',
                                        width: 150.w,
                                        height: 70.h,
                                        onPressed: _handleReservationConfirm,
                                      ),
                                    ],
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
