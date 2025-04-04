import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:url_launcher/url_launcher.dart';

class DinnerInfoPage extends StatefulWidget {
  const DinnerInfoPage({super.key});

  @override
  State<DinnerInfoPage> createState() => _DinnerInfoPageState();
}

class _DinnerInfoPageState extends State<DinnerInfoPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;
  bool _isPageMounted = false; // 追蹤頁面是否完全掛載
  String _userStatus = ''; // 用戶當前狀態

  // 聚餐相關資訊
  Map<String, dynamic> _dinnerInfo = {};
  DateTime? _dinnerTime;
  String? _restaurantName;
  String? _restaurantAddress;
  String? _restaurantImageUrl;
  String? _restaurantCategory;
  String? _restaurantMapUrl;

  @override
  void initState() {
    super.initState();
    _loadUserAndDinnerInfo();
    // 使用延遲來確保頁面完全渲染後才設置為掛載狀態
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isPageMounted = true;
        });
        debugPrint('DinnerInfoPage 完全渲染');
      }
    });
  }

  @override
  void dispose() {
    _isPageMounted = false;
    super.dispose();
  }

  Future<void> _loadUserAndDinnerInfo() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // 獲取用戶狀態
        final status = await _databaseService.getUserStatus(currentUser.id);

        // 檢查用戶狀態是否是有效的狀態
        if (status != 'waiting_other_users' && status != 'waiting_attendance') {
          debugPrint('用戶狀態不是晚餐信息相關狀態: $status，導向到適當頁面');
          if (mounted) {
            _navigationService.navigateToUserStatusPage(context);
          }
          return;
        }

        // 模擬從資料庫獲取聚餐資訊
        // 實際應用中應從資料庫獲取
        final DateTime now = DateTime.now();
        final DateTime dinnerTime = now.add(const Duration(days: 1));

        setState(() {
          _userStatus = status;
          _dinnerTime = dinnerTime;
          _restaurantName = "好吃餐廳";
          _restaurantAddress = "台北市信義區松仁路 100 號 1F 之 1";
          _restaurantImageUrl =
              "https://images.unsplash.com/photo-1552566626-52f8b828add9?q=80&w=2070"; // Unsplash 餐廳圖片
          _restaurantCategory = "未分類";
          _restaurantMapUrl = "https://maps.google.com/?q=台北市信義區松仁路100號";
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('獲取用戶和聚餐資訊時出錯: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 在用戶設置圖標點擊處理函數中使用導航服務
  void _handleProfileTap() {
    _navigationService.navigateToUserSettings(context);
  }

  // 獲取狀態相關的提示文字
  String _getStatusText() {
    switch (_userStatus) {
      case 'waiting_other_users':
        return '正在等待其他用戶確認...';
      case 'waiting_attendance':
      case 'waiting_dinner':
        return '聚餐資訊';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 根據狀態決定顯示內容
    Widget content;

    if (_isLoading) {
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
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF23456B)),
            ),
          ),
        ),
      );
    }

    // 格式化聚餐時間
    final dinnerTimeFormatted =
        _dinnerTime != null
            ? '${_dinnerTime!.month}月${_dinnerTime!.day}日 ${_dinnerTime!.hour}:${_dinnerTime!.minute.toString().padLeft(2, '0')}'
            : '時間待定';

    // 構建等待其他用戶確認的UI
    if (_userStatus == 'waiting_other_users') {
      content = Column(
        children: [
          SizedBox(height: 60.h),

          // 提示文字
          Center(
            child: Text(
              '正在等待其他用戶確認',
              style: TextStyle(
                fontSize: 24.sp,
                fontFamily: 'OtsutomeFont',
                color: const Color(0xFF23456B),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: 25.h),

          // 圖示 - 使用頭像和圓形遮罩
          Center(
            child: Container(
              width: 150.w,
              height: 150.w, // 使用相同的寬度單位確保是正方形
              child: Stack(
                clipBehavior: Clip.none, // 允許陰影超出容器範圍
                children: [
                  // 主圖像（使用 BoxDecoration 確保圓形）
                  Container(
                    width: 150.w,
                    height: 150.w, // 使用相同的寬度單位確保是正方形
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF23456B),
                        width: 2.w,
                      ),
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage(
                          'assets/images/avatar/profile/female_7.png',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 70.h),

          // 聚餐時間顯示
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
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
                  Text(
                    '預計聚餐時間',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontFamily: 'OtsutomeFont',
                      color: const Color(0xFF23456B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    dinnerTimeFormatted,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontFamily: 'OtsutomeFont',
                      color: const Color(0xFF23456B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    // 構建等待出席/聚餐資訊的UI
    else {
      // 定義卡片寬度，確保一致性
      final cardWidth = MediaQuery.of(context).size.width - 48.w;

      content = Column(
        children: [
          SizedBox(height: 30.h),

          // 提示文字
          Center(
            child: Text(
              '聚餐資訊',
              style: TextStyle(
                fontSize: 22.sp,
                fontFamily: 'OtsutomeFont',
                color: const Color(0xFF23456B),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: 20.h),

          // 聚餐資訊卡片（結合餐廳資訊和時間）
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
                // 餐廳資訊部分
                Padding(
                  padding: EdgeInsets.all(12.h),
                  child: Row(
                    children: [
                      // 餐廳縮圖
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10.r),
                        child:
                            _restaurantImageUrl != null
                                ? Image.network(
                                  _restaurantImageUrl!,
                                  width: 85.w,
                                  height: 85.h,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 70.w,
                                      height: 70.h,
                                      color: Colors.grey[300],
                                      child: Icon(
                                        Icons.restaurant,
                                        color: Colors.grey[600],
                                        size: 30.sp,
                                      ),
                                    );
                                  },
                                )
                                : Container(
                                  width: 70.w,
                                  height: 70.h,
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.restaurant,
                                    color: Colors.grey[600],
                                    size: 30.sp,
                                  ),
                                ),
                      ),

                      SizedBox(width: 15.w),

                      // 餐廳資訊
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 餐廳名稱
                            Text(
                              _restaurantName ?? '未指定餐廳',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontFamily: 'OtsutomeFont',
                                color: const Color(0xFF23456B),
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),

                            SizedBox(height: 4.h),
                            // 餐廳類別
                            Text(
                              _restaurantCategory ?? '未分類',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontFamily: 'OtsutomeFont',
                                color: const Color(0xFF666666),
                              ),
                            ),

                            SizedBox(height: 10.h),
                            // 餐廳地址 - 可點擊
                            GestureDetector(
                              onTap: () async {
                                if (_restaurantMapUrl != null) {
                                  final Uri url = Uri.parse(_restaurantMapUrl!);
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  }
                                }
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _restaurantAddress ?? '地址未提供',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontFamily: 'OtsutomeFont',
                                        color: const Color(0xFF23456B),
                                        decoration: TextDecoration.none,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
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

                // 聚餐時間部分
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 15.h,
                    vertical: 15.h,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 左側時間信息
                      SizedBox(
                        width: cardWidth * 0.4,
                        child: Row(
                          children: [
                            // 時間圖標 - 使用指定的圖標並添加陰影效果
                            Padding(
                              padding: EdgeInsets.only(left: 5.w, bottom: 5.h),
                              child: SizedBox(
                                width: 35.w,
                                height: 35.h,
                                child: Stack(
                                  clipBehavior: Clip.none, // 允許陰影超出容器範圍
                                  children: [
                                    // 底部陰影
                                    Positioned(
                                      left: 0,
                                      top: 2.h,
                                      child: Image.asset(
                                        'assets/images/icon/clock.png',
                                        width: 35.w,
                                        height: 35.h,
                                        color: Colors.black.withOpacity(0.4),
                                        colorBlendMode: BlendMode.srcIn,
                                      ),
                                    ),
                                    // 主圖標
                                    Image.asset(
                                      'assets/images/icon/clock.png',
                                      width: 35.w,
                                      height: 35.h,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(width: 10.w),

                            // 時間信息文字
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '聚餐時間',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    dinnerTimeFormatted,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 垂直分隔線
                      Container(
                        height: 45.h,
                        width: 1.w,
                        color: Colors.grey[300],
                      ),

                      // 右側導航部分
                      SizedBox(
                        width: cardWidth * 0.4,
                        child: InkWell(
                          onTap: () async {
                            if (_restaurantMapUrl != null) {
                              final Uri url = Uri.parse(_restaurantMapUrl!);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 導航圖標
                              Padding(
                                padding: EdgeInsets.only(bottom: 5.h),
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
                                          'assets/images/icon/navigation.png',
                                          width: 35.w,
                                          height: 35.h,
                                          color: Colors.black.withOpacity(0.4),
                                          colorBlendMode: BlendMode.srcIn,
                                        ),
                                      ),
                                      // 主圖標
                                      Image.asset(
                                        'assets/images/icon/navigation.png',
                                        width: 35.w,
                                        height: 35.h,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '導航',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                    ),
                                  ),
                                  Text(
                                    'Google Map',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                ],
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

          SizedBox(height: 20.h),

          // 提示文字卡片 - 確保寬度一致
          Container(
            width: cardWidth,
            margin: EdgeInsets.symmetric(vertical: 8.h),
            padding: EdgeInsets.all(15.h),
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
                Text(
                  '提示',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontFamily: 'OtsutomeFont',
                    color: const Color(0xFF23456B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  '請在指定時間抵達餐廳。\n如有任何變動，系統將會發送通知。',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontFamily: 'OtsutomeFont',
                    color: const Color(0xFF666666),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

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
            child: Column(
              children: [
                // 頂部導航欄
                HeaderBar(
                  title: _getStatusText(),
                  onProfileTap: _handleProfileTap,
                ),

                // 主要內容
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: content,
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
