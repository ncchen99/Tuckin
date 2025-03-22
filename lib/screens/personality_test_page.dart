import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';
import 'home_page.dart'; // 下一個頁面

class PersonalityTestPage extends StatefulWidget {
  const PersonalityTestPage({super.key});

  @override
  State<PersonalityTestPage> createState() => _PersonalityTestPageState();
}

class _PersonalityTestPageState extends State<PersonalityTestPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  int? _selectedPersonality;
  bool _isLoading = false;

  // 個性類型列表
  final List<Map<String, dynamic>> _personalityTypes = [
    {
      'id': 1,
      'name': '隨和型',
      'description': '你是個隨和的人，願意接受各種餐廳的選擇，沒有太多偏好。',
      'image': 'assets/images/personality/easygoing.png',
    },
    {
      'id': 2,
      'name': '嘗鮮型',
      'description': '你喜歡探索新餐廳，嘗試你從未去過的地方。',
      'image': 'assets/images/personality/explorer.png',
    },
    {
      'id': 3,
      'name': '懷舊型',
      'description': '你總是懷念幾家最愛的餐廳，並經常回訪。',
      'image': 'assets/images/personality/nostalgic.png',
    },
    {
      'id': 4,
      'name': '品質型',
      'description': '無論價格如何，你都追求高品質的用餐體驗。',
      'image': 'assets/images/personality/quality.png',
    },
    {
      'id': 5,
      'name': '經濟型',
      'description': '你喜歡尋找划算的選擇，享受物超所值的餐點。',
      'image': 'assets/images/personality/budget.png',
    },
  ];

  // 處理返回按鈕
  void _handleBack() {
    Navigator.of(context).pop();
  }

  // 處理性格選擇
  void _selectPersonality(int personalityId) {
    setState(() {
      _selectedPersonality = personalityId;
    });
  }

  // 處理完成按鈕
  Future<void> _handleComplete() async {
    if (_selectedPersonality == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇一種性格類型')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 獲取當前用戶
      final currentUser = _authService.getCurrentUser();

      if (currentUser == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('您尚未登入，請先登入')));
        return;
      }

      // 儲存用戶性格類型到 Supabase
      await _databaseService.updateUserPersonalityType(
        currentUser.id,
        _selectedPersonality!.toString(),
      );

      // 導航到主頁，添加滑動動畫
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => const HomePage(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOut;
              var tween = Tween(
                begin: begin,
                end: end,
              ).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              return SlideTransition(position: offsetAnimation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
          (route) => false, // 清除所有路由歷史
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
              // 頂部標題和返回按鈕放在同一行
              Padding(
                padding: EdgeInsets.only(top: 40.h, bottom: 8.h),
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
                    // 中央標題（只有主標題）
                    Expanded(
                      child: Text(
                        '個性測驗',
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

              // 副標題單獨放在下方
              Padding(
                padding: EdgeInsets.only(bottom: 20.h),
                child: Text(
                  '請選擇最符合您吃飯習慣的類型',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontFamily: 'OtsutomeFont',
                    color: const Color(0xFF23456B),
                  ),
                ),
              ),

              // 個性類型選擇區域
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  itemCount: _personalityTypes.length,
                  itemBuilder: (context, index) {
                    final personality = _personalityTypes[index];
                    final isSelected =
                        _selectedPersonality == personality['id'];

                    return GestureDetector(
                      onTap: () => _selectPersonality(personality['id']),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 15.h),
                        padding: EdgeInsets.all(15.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color:
                                isSelected
                                    ? const Color(0xFF23456B)
                                    : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 性格圖標
                            Image.asset(
                              personality['image'],
                              width: 70.w,
                              height: 70.h,
                            ),
                            SizedBox(width: 15.w),

                            // 性格資訊
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    personality['name'],
                                    style: TextStyle(
                                      fontSize: 20.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 5.h),
                                  Text(
                                    personality['description'],
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 選中標記
                            /* if (isSelected)
                              Container(
                                width: 24.w,
                                height: 24.h,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFB33D1C),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18.h,
                                ),
                              ), */
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 完成按鈕區域
              Container(
                margin: EdgeInsets.only(bottom: 30.h, top: 10.h),
                child:
                    _isLoading
                        ? LoadingImage(
                          width: 60.w,
                          height: 60.h,
                          color: const Color(0xFFB33D1C),
                        )
                        : ImageButton(
                          text: '完成',
                          imagePath: 'assets/images/ui/button/red_l.png',
                          width: 150.w,
                          height: 75.h,
                          onPressed: _handleComplete,
                        ),
              ),

              // 進度指示器
              Padding(
                padding: EdgeInsets.only(bottom: 20.h),
                child: const ProgressDotsIndicator(
                  totalSteps: 5,
                  currentStep: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
