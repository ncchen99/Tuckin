import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';

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
  bool _isFinishing = false; // 追蹤完成晚餐操作的狀態

  // 聚餐相關資訊
  Map<String, dynamic> _dinnerInfo = {};
  DateTime? _dinnerTime;
  String? _restaurantName;
  String? _restaurantAddress;

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
        if (status != 'waiting_dinner' &&
            status != 'waiting_other_users' &&
            status != 'waiting_attendance') {
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
          _restaurantAddress = "台北市信義區松仁路 100 號";
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

  // 用戶完成晚餐
  Future<void> _handleFinishDinner() async {
    // 防誤觸邏輯：確保頁面已完全載入
    if (!_isPageMounted || _isLoading) {
      debugPrint('防止誤觸：頁面未完全掛載或載入中，操作被忽略');
      return;
    }

    try {
      // 更新狀態顯示 loading
      setState(() {
        _isFinishing = true;
      });

      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // 更新用戶狀態
        await _databaseService.updateUserStatus(currentUser.id, 'rating');

        // 確保頁面仍然掛載
        if (mounted) {
          debugPrint('用戶已完成晚餐，導向到評分頁面');
          // 導航前延遲一下，確保 loading 效果可見
          await Future.delayed(const Duration(milliseconds: 200));
          _navigationService.navigateToDinnerRating(context);
        }
      }
    } catch (e) {
      debugPrint('完成晚餐時出錯: $e');
      // 確保頁面仍然掛載
      if (mounted) {
        setState(() {
          _isFinishing = false; // 出錯時恢復按鈕狀態
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '操作失敗: $e',
              style: TextStyle(fontSize: 15, fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  // 在通知圖標點擊處理函數中使用導航服務
  void _handleNotificationTap() {
    _navigationService.navigateToNotifications(context);
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
    // 計算適當的陰影偏移量
    final adaptiveShadowOffset = 4.h;

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
            ? '${_dinnerTime!.year}年${_dinnerTime!.month}月${_dinnerTime!.day}日 ${_dinnerTime!.hour}:${_dinnerTime!.minute.toString().padLeft(2, '0')}'
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
      content = Column(
        children: [
          SizedBox(height: 60.h),

          // 提示文字
          Center(
            child: Text(
              '聚餐資訊確認',
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

          // 圖示 - 使用餐廳圖標
          Center(
            child: SizedBox(
              width: 150.w,
              height: 150.h,
              child: Stack(
                clipBehavior: Clip.none, // 允許陰影超出容器範圍
                children: [
                  // 底部陰影
                  Positioned(
                    left: 0,
                    top: adaptiveShadowOffset,
                    child: Image.asset(
                      'assets/images/icon/restaurant.png',
                      width: 150.w,
                      height: 150.h,
                      color: Colors.black.withOpacity(0.4),
                      colorBlendMode: BlendMode.srcIn,
                    ),
                  ),
                  // 主圖像
                  Image.asset(
                    'assets/images/icon/restaurant.png',
                    width: 150.w,
                    height: 150.h,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 35.h),

          // 聚餐時間顯示
          Center(
            child: Container(
              width: 300.w,
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
                    '聚餐時間',
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

          SizedBox(height: 15.h),

          // 餐廳資訊
          Center(
            child: Container(
              width: 300.w,
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
                    '餐廳資訊',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontFamily: 'OtsutomeFont',
                      color: const Color(0xFF23456B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    _restaurantName ?? '未指定',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontFamily: 'OtsutomeFont',
                      color: const Color(0xFF23456B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    _restaurantAddress ?? '地址未提供',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontFamily: 'OtsutomeFont',
                      color: const Color(0xFF23456B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // 完成晚餐按鈕
          Center(
            child:
                _isFinishing
                    ? Container(
                      width: 180.w,
                      height: 85.h,
                      alignment: Alignment.center,
                      child: LoadingImage(width: 60.w, height: 60.h),
                    )
                    : ImageButton(
                      text: '完成晚餐',
                      imagePath: 'assets/images/ui/button/red_l.png',
                      width: 180.w,
                      height: 85.h,
                      onPressed: () {
                        if (_isPageMounted && !_isLoading) {
                          _handleFinishDinner();
                        } else {
                          debugPrint('頁面未完全掛載或載入中，忽略點擊事件');
                        }
                      },
                    ),
          ),

          SizedBox(height: 30.h),
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
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: content,
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
