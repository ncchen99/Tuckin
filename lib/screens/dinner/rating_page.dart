import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/components/common/stroke_text_widget.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:url_launcher/url_launcher.dart';

class RatingPage extends StatefulWidget {
  const RatingPage({super.key});

  @override
  State<RatingPage> createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final NavigationService _navigationService = NavigationService();
  bool _isLoading = true;
  bool _isSubmitting = false;

  // 評分選項
  final List<String> _ratingOptions = ['喜歡', '不喜歡', '未出席'];

  // 參與者資料，模擬數據，未來需從後端獲取
  final List<Map<String, dynamic>> _participants = [
    {
      'id': '1',
      'nickname': '阿明',
      'gender': 'male',
      'avatarIndex': 1,
      'selectedRating': null,
    },
    {
      'id': '2',
      'nickname': '小美',
      'gender': 'female',
      'avatarIndex': 2,
      'selectedRating': null,
    },
    {
      'id': '3',
      'nickname': '大華',
      'gender': 'male',
      'avatarIndex': 3,
      'selectedRating': null,
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final userStatus = await _databaseService.getUserStatus(currentUser.id);
        setState(() {
          _isLoading = false;
        });

        if (userStatus != 'rating') {
          if (mounted) {
            _navigationService.navigateToUserStatusPage(context);
          }
        }
      }
    } catch (e) {
      debugPrint('檢查用戶狀態時出錯: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 用戶選擇評分
  void _handleRatingSelect(int participantIndex, String rating) {
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        // 儲存用戶評分
        // 這裡需要在 DatabaseService 中實現相應方法
        // for (var participant in _participants) {
        //   await _databaseService.saveDinnerRating(
        //     currentUser.id,
        //     participant['id'],
        //     participant['selectedRating'],
        //   );
        // }

        // 更新用戶狀態
        await _databaseService.updateUserStatus(currentUser.id, 'available');

        if (mounted) {
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
      }
      setState(() {
        _isSubmitting = false;
      });
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
                        participant['avatarIndex'],
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                // 暱稱
                Text(
                  participant['nickname'],
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontFamily: 'OtsutomeFont',
                    color: const Color(0xFF23456B),
                    fontWeight: FontWeight.bold,
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

    return GestureDetector(
      onTap: () => _handleRatingSelect(participantIndex, option),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 5.w),
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
  }

  void _handleProfileTap() {
    _navigationService.navigateToUserSettings(context);
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 48.w;

    return Scaffold(
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
                    child: CircularProgressIndicator(color: Color(0xFF23456B)),
                  )
                  : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // HeaderBar也加入滾動區域
                        HeaderBar(
                          title: '聚餐評分',
                          onProfileTap: _handleProfileTap,
                          showBackButton: false,
                        ),

                        // 主要內容區域
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                              ...List.generate(
                                _participants.length,
                                (index) => _buildRatingCard(index),
                              ),

                              SizedBox(height: 40.h),

                              // 底部提示信息 - 垂直排列，寬度與卡片一致
                              Container(
                                width: cardWidth,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10.r),
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
                                                        .withOpacity(0.3),
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
                                              fontFamily: 'OtsutomeFont',
                                              color: const Color(0xFF666666),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          SizedBox(height: 4.h),
                                          // Email地址
                                          Text(
                                            'help.tuckin@gmail.com',
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              fontFamily: 'OtsutomeFont',
                                              color: const Color(0xFF23456B),
                                              fontWeight: FontWeight.bold,
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
                                    onPressed: _handleSubmitRating,
                                  ),

                              SizedBox(height: 30.h),
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
