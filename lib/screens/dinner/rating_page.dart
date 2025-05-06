import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/components/common/stroke_text_widget.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/dining_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:tuckin/services/user_status_service.dart';

class RatingPage extends StatefulWidget {
  const RatingPage({super.key});

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final DiningService _diningService = DiningService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _diningEventId;
  String _sessionToken = ''; // 存儲API返回的session_token
  String _loadingStatus = '正在載入評分資料...'; // 加載狀態文字

  // 評分選項
  final List<String> _ratingOptions = ['喜歡', '不喜歡', '未出席'];

  // 參與者資料，將從API獲取
  List<Map<String, dynamic>> _participants = [];

  // 為每個參與者的每個選項創建動畫控制器
  late List<List<AnimationController>> _animationControllers;
  late List<List<Animation<double>>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    // 延遲執行資料加載，確保頁面已完全構建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserStatus();
    });
  }

  void _initAnimations() {
    _animationControllers = List.generate(
      _participants.length,
      (_) => List.generate(
        _ratingOptions.length,
        (_) => AnimationController(
          duration: const Duration(milliseconds: 300),
          vsync: this,
        ),
      ),
    );

    _scaleAnimations = List.generate(
      _participants.length,
      (i) => List.generate(
        _ratingOptions.length,
        (j) => Tween<double>(begin: 1.0, end: 1.15).animate(
          CurvedAnimation(
            parent: _animationControllers[i][j],
            curve: Curves.elasticOut,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 釋放所有動畫控制器
    if (_animationControllers != null) {
      for (var controllers in _animationControllers) {
        for (var controller in controllers) {
          controller.dispose();
        }
      }
    }
    super.dispose();
  }

  Future<void> _checkUserStatus() async {
    try {
      setState(() {
        _loadingStatus = '正在檢查用戶狀態...';
      });

      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        setState(() {
          _loadingStatus = '正在獲取聚餐資訊...';
        });

        final userStatus = await _databaseService.getUserStatus(currentUser.id);

        if (userStatus != 'rating') {
          if (mounted) {
            // 狀態不為rating，導航到適當頁面
            _navigationService.navigateToUserStatusPage(context);
            return;
          }
        }

        // 從UserStatusService獲取聚餐事件ID
        if (mounted) {
          final userStatusService = Provider.of<UserStatusService>(
            context,
            listen: false,
          );

          _diningEventId = userStatusService.diningEventId;

          if (_diningEventId == null) {
            setState(() {
              _loadingStatus = '正在查詢聚餐事件...';
            });

            // 嘗試從數據庫獲取當前聚餐事件
            final diningEvent = await _databaseService.getCurrentDiningEvent(
              currentUser.id,
            );

            if (diningEvent != null) {
              _diningEventId = diningEvent['id'];

              // 檢查聚餐事件狀態
              final eventStatus = diningEvent['status'];
              if (eventStatus != 'completed') {
                debugPrint('聚餐事件狀態不是completed，而是: $eventStatus');
                if (mounted) {
                  _navigationService.navigateToUserStatusPage(context);
                  return;
                }
              }
            } else {
              debugPrint('未找到聚餐事件，導航到主頁面');
              if (mounted) {
                _navigationService.navigateToHome(context);
                return;
              }
            }
          }

          // 獲取評分表單
          setState(() {
            _loadingStatus = '正在獲取評分表單...';
          });

          await _loadRatingForm();
        }
      } else {
        if (mounted) {
          _navigationService.navigateToHome(context);
        }
      }
    } catch (e) {
      debugPrint('檢查用戶狀態時出錯: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '載入評分資料時出錯: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadRatingForm() async {
    try {
      if (_diningEventId == null) {
        throw Exception('聚餐事件ID為空，無法獲取評分表單');
      }

      final response = await _diningService.getRatingForm(_diningEventId!);

      if (mounted) {
        setState(() {
          // 存儲session_token用於後續提交評分
          _sessionToken = response['session_token'] ?? '';

          // 解析API回傳的參與者資料
          if (response.containsKey('participants')) {
            _participants = List<Map<String, dynamic>>.from(
              response['participants'],
            );
          } else {
            _participants = [];
          }

          // 初始化動畫
          _initAnimations();

          // 最後一步設置加載完成
          _isLoading = false;
        });

        debugPrint('成功載入評分表單，參與者數量: ${_participants.length}');
      }
    } catch (e) {
      debugPrint('載入評分表單時出錯: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '載入評分表單時出錯: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  // 計算是否所有參與者都已評分
  bool _isAllRated() {
    return _participants.every(
      (participant) => participant['selectedRating'] != null,
    );
  }

  // 用戶選擇評分
  void _handleRatingSelect(int participantIndex, String rating) {
    // 找出選項在列表中的索引
    int optionIndex = _ratingOptions.indexOf(rating);

    if (optionIndex != -1) {
      // 重置該參與者的所有動畫
      for (int i = 0; i < _ratingOptions.length; i++) {
        _animationControllers[participantIndex][i].reset();
      }

      // 播放選中的選項動畫
      _animationControllers[participantIndex][optionIndex].forward();
    }

    setState(() {
      _participants[participantIndex]['selectedRating'] = rating;
    });
  }

  // 用戶提交評分
  Future<void> _handleSubmitRating() async {
    // 檢查是否所有參與者都已評分
    bool allRated = _participants.every(
      (participant) => participant['selectedRating'] != null,
    );

    if (!allRated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '請為所有參與者評分',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
      return;
    }

    // 檢查session_token是否有效
    if (_sessionToken.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '評分會話無效，請重新進入評分頁面',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_diningEventId == null) {
        throw Exception('聚餐事件ID為空，無法提交評分');
      }

      // 準備評分數據
      final ratings =
          _participants
              .map(
                (participant) => {
                  'participant_id': participant['id'], // 使用後端返回的ID作為參與者ID
                  'rating': participant['selectedRating'],
                },
              )
              .toList();

      // 提交評分
      await _diningService.submitRating(
        _diningEventId!,
        ratings,
        _sessionToken,
      );

      // 更新用戶狀態
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        await _databaseService.updateUserStatus(currentUser.id, 'booking');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '評分成功！！',
                style: const TextStyle(fontFamily: 'OtsutomeFont'),
              ),
            ),
          );
          // 更新UserStatusService
          final userStatusService = Provider.of<UserStatusService>(
            context,
            listen: false,
          );
          userStatusService.setUserStatus('booking');

          _navigationService.navigateToHome(context);
        }
      }
    } catch (e) {
      debugPrint('提交評分時出錯: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '提交評分時出錯: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // 獲取頭像路徑
  String _getAvatarPath(String gender, int index) {
    return 'assets/images/avatar/profile/${gender}_$index.png';
  }

  // 開啟郵件應用
  Future<void> _launchEmail() async {
    try {
      if (Platform.isIOS) {
        // iOS使用message://打開郵件應用
        final Uri emailUri = Uri.parse('message://');
        if (await canLaunchUrl(emailUri)) {
          await launchUrl(emailUri);
        } else {
          debugPrint('無法開啟郵件應用');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '無法開啟郵件應用',
                  style: TextStyle(fontFamily: 'OtsutomeFont'),
                ),
              ),
            );
          }
        }
      } else if (Platform.isAndroid) {
        // Android使用mailto scheme
        final Uri emailUri = Uri(
          scheme: 'mailto',
          path: 'help.tuckin@gmail.com',
          queryParameters: {'subject': '聚餐反映事項'},
        );

        if (await canLaunchUrl(emailUri)) {
          await launchUrl(emailUri);
        } else {
          debugPrint('無法開啟郵件應用');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '無法開啟郵件應用',
                  style: TextStyle(fontFamily: 'OtsutomeFont'),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('開啟郵件應用時發生錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '開啟郵件應用時發生錯誤: $e',
              style: const TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  // 選項指針圖標
  Widget _buildPointerIcon() {
    return Positioned(
      left: 10.w,
      top: 15.h,
      child: SizedBox(
        width: 38.w,
        height: 38.h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 底部陰影
            Positioned(
              left: 2.w,
              top: 1.h,
              child: Image.asset(
                'assets/images/icon/pointer.png',
                width: 38.w,
                height: 38.h,
                color: Colors.black.withOpacity(0.3),
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
            // 主圖標
            Image.asset(
              'assets/images/icon/pointer.png',
              width: 38.w,
              height: 38.h,
            ),
          ],
        ),
      ),
    );
  }

  // 評分卡片
  Widget _buildRatingCard(int index) {
    final participant = _participants[index];
    final cardWidth = MediaQuery.of(context).size.width - 48.w;

    return Container(
      width: cardWidth,
      margin: EdgeInsets.symmetric(vertical: 10.h),
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
      child: Padding(
        padding: EdgeInsets.all(15.h),
        child: Row(
          children: [
            // 左側頭像和暱稱
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 頭像
                Container(
                  width: 60.w,
                  height: 60.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 3,
                        offset: Offset(0, 1.h),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30.r),
                    child: Image.asset(
                      _getAvatarPath(
                        participant['gender'],
                        participant['avatar_index'],
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                // 暱稱 - 添加截斷功能
                Container(
                  width: 70.w, // 設定固定寬度
                  child: Text(
                    participant['nickname'],
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontFamily: 'OtsutomeFont',
                      color: const Color(0xFF23456B),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis, // 使用省略號截斷
                    maxLines: 1, // 最多顯示1行
                  ),
                ),
              ],
            ),

            SizedBox(width: 15.w),

            // 右側評分選項 - 使用分割線設計
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 喜歡選項
                  Expanded(
                    child: _buildRatingOption(
                      index,
                      _ratingOptions[0],
                      isFirst: true,
                    ),
                  ),

                  // 第一條分隔線
                  Container(height: 40.h, width: 1.w, color: Colors.grey[300]),

                  // 不喜歡選項
                  Expanded(child: _buildRatingOption(index, _ratingOptions[1])),

                  // 第二條分隔線
                  Container(height: 40.h, width: 1.w, color: Colors.grey[300]),

                  // 未出席選項
                  Expanded(
                    child: _buildRatingOption(
                      index,
                      _ratingOptions[2],
                      isLast: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 評分選項
  Widget _buildRatingOption(
    int participantIndex,
    String option, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    final participant = _participants[participantIndex];
    final bool isSelected = participant['selectedRating'] == option;
    final int optionIndex = _ratingOptions.indexOf(option);

    return GestureDetector(
      onTap: () => _handleRatingSelect(participantIndex, option),
      child: AnimatedBuilder(
        animation: _animationControllers[participantIndex][optionIndex],
        builder: (context, child) {
          return Transform.scale(
            scale:
                isSelected
                    ? _scaleAnimations[participantIndex][optionIndex].value
                    : 1.0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              // 擴大點擊範圍
              width: double.infinity,
              height: 60.h,
              // 添加可點擊的視覺效果，僅在滑鼠懸停時顯示（Web平台）
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 選項文字，根據選中狀態使用不同的樣式
                    isSelected
                        ? StrokeTextWidget(
                          text: option,
                          fontSize: 16,
                          textColor: const Color.fromARGB(255, 243, 202, 202),
                          strokeColor: const Color.fromARGB(255, 167, 53, 21),
                          textAlign: TextAlign.center,
                        )
                        : StrokeTextWidget(
                          text: option,
                          fontSize: 16,
                          textColor: const Color.fromARGB(255, 255, 255, 255),
                          strokeColor: const Color(0xFF23456B),
                          textAlign: TextAlign.center,
                        ),

                    // 若選中，則顯示指針圖標
                    if (isSelected) _buildPointerIcon(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 處理用戶頭像點擊
  void _handleProfileTap() {
    _navigationService.navigateToProfile(context);
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 48.w;

    return WillPopScope(
      onWillPop: () async {
        return false; // 禁用返回按鈕
      },
      child: Scaffold(
        body:
            _isLoading
                ? LoadingScreen(
                  status: _loadingStatus,
                  displayDuration: 500, // 設置較短的顯示時間
                  onLoadingComplete: () {
                    // 不執行任何操作，讓它保持顯示直到數據加載完成
                  },
                )
                : Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/background/bg2.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      // 改為Column佈局以便使用Expanded
                      children: [
                        // HeaderBar
                        HeaderBar(title: '聚餐評分', showBackButton: false),

                        // 內容區域使用Expanded包裹，確保可以滾動
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                // 主要內容區域
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24.w,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SizedBox(height: 20.h),

                                      // 說明文字
                                      Text(
                                        '此喜好調查僅用於之後聚餐的配對',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontFamily: 'OtsutomeFont',
                                          color: const Color(0xFF23456B),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      SizedBox(height: 25.h),

                                      // 評分卡片
                                      _participants.isEmpty
                                          ? Center(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 30.h,
                                              ),
                                              child: Text(
                                                '沒有需要評分的參與者',
                                                style: TextStyle(
                                                  fontSize: 18.sp,
                                                  fontFamily: 'OtsutomeFont',
                                                  color: const Color(
                                                    0xFF666666,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                          : Column(
                                            children: List.generate(
                                              _participants.length,
                                              (index) =>
                                                  _buildRatingCard(index),
                                            ),
                                          ),

                                      SizedBox(height: 40.h),

                                      // 底部提示信息 - 垂直排列，寬度與卡片一致
                                      Container(
                                        width: cardWidth,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              10.r,
                                            ),
                                            onTap: _launchEmail,
                                            child: Padding(
                                              padding: EdgeInsets.all(15.h),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Email 圖標置中 (帶陰影)
                                                  SizedBox(
                                                    width: 30.w,
                                                    height: 30.h,
                                                    child: Stack(
                                                      children: [
                                                        // 底部陰影
                                                        Positioned(
                                                          left: 0.w,
                                                          top: 1.h,
                                                          child: Image.asset(
                                                            'assets/images/icon/email.png',
                                                            width: 28.w,
                                                            height: 28.h,
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.3,
                                                                ),
                                                            colorBlendMode:
                                                                BlendMode.srcIn,
                                                          ),
                                                        ),
                                                        // 主圖標
                                                        Image.asset(
                                                          'assets/images/icon/email.png',
                                                          width: 28.w,
                                                          height: 28.h,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(height: 8.h),
                                                  // 提示文字
                                                  Text(
                                                    '如果有任何想要反映的事情，請寄信到：',
                                                    style: TextStyle(
                                                      fontSize: 14.sp,
                                                      fontFamily:
                                                          'OtsutomeFont',
                                                      color: const Color(
                                                        0xFF666666,
                                                      ),
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  SizedBox(height: 4.h),
                                                  // Email地址
                                                  Text(
                                                    'help.tuckin@gmail.com',
                                                    style: TextStyle(
                                                      fontSize: 14.sp,
                                                      fontFamily:
                                                          'OtsutomeFont',
                                                      color: const Color(
                                                        0xFF23456B,
                                                      ),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      SizedBox(height: 40.h),

                                      // 提交按鈕
                                      _isSubmitting
                                          ? LoadingImage(
                                            width: 60.w,
                                            height: 60.h,
                                            color: const Color(0xFF23456B),
                                          )
                                          : ImageButton(
                                            text: '送出評分',
                                            imagePath:
                                                'assets/images/ui/button/red_m.png',
                                            width: 160.w,
                                            height: 70.h,
                                            onPressed:
                                                _participants.isEmpty
                                                    ? () {}
                                                    : () =>
                                                        _handleSubmitRating(),
                                            isEnabled:
                                                _participants.isNotEmpty &&
                                                _isAllRated(),
                                          ),

                                      // 動態填充剩餘空間
                                      SizedBox(height: 30.h), // 底部保留一些空間
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
                ),
      ),
    );
  }
}
