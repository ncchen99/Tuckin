import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalityTestPage extends StatefulWidget {
  final bool isFromProfile;

  const PersonalityTestPage({super.key, this.isFromProfile = false});

  @override
  State<PersonalityTestPage> createState() => _PersonalityTestPageState();
}

class _PersonalityTestPageState extends State<PersonalityTestPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  String? _questionOneAnswer; // 問題1的答案 (a or b)
  String? _questionTwoAnswer; // 問題2的答案 (a or b)
  bool _isLoading = false;
  bool _isDataLoaded = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final bool _hasBackPressed = false; // 追蹤是否已按過返回鍵

  // 個性類型問題與選項
  final List<Map<String, dynamic>> _questions = [
    {
      'id': 1,
      'question': '當您接收資訊時，您更喜歡哪種方式？',
      'options': [
        {'id': 'a', 'text': '以事實和數據為基礎的資訊', 'description': '例如：統計數字、報告、證據'},
        {'id': 'b', 'text': '以情感和個人經驗為基礎的資訊', 'description': '例如：故事、感覺、個人意見'},
      ],
    },
    {
      'id': 2,
      'question': '當您解釋某件事時，您更喜歡哪種方式？',
      'options': [
        {'id': 'a', 'text': '從頭到尾，逐步解釋', 'description': '例如：一步一步說明過程'},
        {
          'id': 'b',
          'text': '直接切入重點，即使可能跳過一些細節',
          'description': '例如：先說結論，再補充細節',
        },
      ],
    },
  ];

  // 分析結果映射
  final Map<String, String> _personalityTypes = {
    'aa': '分析型',
    'ab': '功能型',
    'bb': '直覺型',
    'ba': '個人型',
  };

  // 分析結果描述
  final Map<String, String> _personalityDescriptions = {
    '分析型': '您喜歡以邏輯和數據為基礎的溝通，並希望資訊有條理。您可能更容易與注重事實和組織性的人成為朋友。',
    '功能型': '您喜歡數據，但溝通更靈活，注重實用性。您可能更喜歡與能快速抓住重點的人交朋友。',
    '直覺型': '您重視情感和直覺，喜歡簡潔直接的溝通。您可能更容易與創造力強、隨性的人產生共鳴。',
    '個人型': '您重視情感連結，並希望溝通有結構。您可能更喜歡與同理心強、注重關係的人成為朋友。',
  };

  @override
  void initState() {
    super.initState();
    _loadUserPersonalityType();
  }

  // 載入用戶的個性類型
  Future<void> _loadUserPersonalityType() async {
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

          if (userProfile['personality_type'] != null) {
            final personalityType = userProfile['personality_type'] as String;

            // 根據個性類型反推答案
            if (personalityType == '分析型') {
              setState(() {
                _questionOneAnswer = 'a';
                _questionTwoAnswer = 'a';
              });
            } else if (personalityType == '功能型') {
              setState(() {
                _questionOneAnswer = 'a';
                _questionTwoAnswer = 'b';
              });
            } else if (personalityType == '直覺型') {
              setState(() {
                _questionOneAnswer = 'b';
                _questionTwoAnswer = 'b';
              });
            } else if (personalityType == '個人型') {
              setState(() {
                _questionOneAnswer = 'b';
                _questionTwoAnswer = 'a';
              });
            }

            setState(() {
              _isDataLoaded = true;
            });
          }
        }
      } catch (e) {
        debugPrint('載入用戶個性類型出錯: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 處理返回按鈕
  void _handleBack() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (widget.isFromProfile) {
        // 如果是從profile頁面導航過來的，顯示確認對話框
        showCustomConfirmationDialog(
          context: context,
          iconPath: 'assets/images/icon/save.png',
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
            if (_questionTwoAnswer != null) {
              await _handleComplete();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '請完成所有問題後再儲存',
                    style: TextStyle(fontFamily: 'OtsutomeFont'),
                  ),
                ),
              );
            }
          },
        );
      } else {
        // 在第一頁時，導航回food_preference頁面
        final navigationService = NavigationService();
        navigationService.navigateToPreviousSetupStep(
          context,
          'personality_test',
        );
      }
    }
  }

  // 處理問題1選擇
  void _selectQuestionOneAnswer(String optionId) {
    setState(() {
      _questionOneAnswer = optionId;
    });
  }

  // 處理問題2選擇
  void _selectQuestionTwoAnswer(String optionId) {
    setState(() {
      _questionTwoAnswer = optionId;
    });
  }

  // 處理下一頁
  void _handleNext() {
    if (_questionOneAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '請選擇一個選項',
            style: TextStyle(fontFamily: 'OtsutomeFont'),
          ),
        ),
      );
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // 獲取個性類型結果
  String _getPersonalityResult() {
    if (_questionOneAnswer == null || _questionTwoAnswer == null) {
      return '';
    }

    String key = '$_questionOneAnswer$_questionTwoAnswer';
    return _personalityTypes[key] ?? '';
  }

  // 處理完成按鈕
  Future<void> _handleComplete() async {
    // 確保第二個問題有選擇
    if (_questionTwoAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '請選擇第二個問題的選項',
            style: TextStyle(fontFamily: 'OtsutomeFont'),
          ),
        ),
      );
      return;
    }

    final currentUser = await _authService.getCurrentUser();
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '您尚未登入，請先登入',
            style: TextStyle(fontFamily: 'OtsutomeFont'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // 根據回答確定人格類型
    final personalityType = _getPersonalityResult();

    // 保存人格類型到數據庫
    _databaseService
        .updateUserPersonalityType(currentUser.id, personalityType)
        .then((_) async {
          if (!widget.isFromProfile) {
            // 只有在不是從profile頁面來的時候，才更新用戶狀態為 booking
            try {
              await _databaseService.updateUserStatus(
                currentUser.id,
                'booking',
              );

              // 設置一個標誌表示是新用戶第一次使用
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_new_user', true);
            } catch (error) {
              debugPrint('更新用戶狀態出錯: $error');
            }
          }

          setState(() {
            _isLoading = false;
          });

          if (widget.isFromProfile) {
            // 如果是從profile頁面導航過來的，保存後返回profile頁面
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '測驗結果更新成功',
                  style: TextStyle(fontFamily: 'OtsutomeFont'),
                ),
              ),
            );
            Navigator.of(context).pop();
          } else {
            // 使用NavigationService進行導航
            final navigationService = NavigationService();
            navigationService.navigateToNextSetupStep(
              context,
              'personality_test',
            );
          }
        })
        .catchError((error) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '儲存資料失敗: $error',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 根據當前頁面決定行為
        if (_currentPage > 0) {
          // 如果不是第一頁，則返回上一頁
          setState(() {
            _currentPage--;
          });
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          return false; // 阻止默認返回行為
        } else {
          // 在第一頁時，處理返回邏輯
          _handleBack();
          return false; // 阻止默認返回行為
        }
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
                    : Stack(
                      children: [
                        // 右下角背景圖片 - 放在Stack的第一個元素作為底層
                        Positioned(
                          right: -30.w, // 負值使圖片右側超出螢幕
                          bottom: -30.h, // 負值使圖片底部超出螢幕
                          child: Opacity(
                            opacity: 0.65, // 降低透明度，使圖片更加融入背景
                            child: ColorFiltered(
                              // 降低彩度的矩陣
                              colorFilter: const ColorFilter.matrix(<double>[
                                0.6, 0.1, 0.1, 0, 0, // R影響
                                0.1, 0.6, 0.1, 0, 0, // G影響
                                0.1, 0.1, 0.6, 0, 0, // B影響
                                0, 0, 0, 1, 0, // A影響
                              ]),
                              child: Image.asset(
                                _currentPage == 0
                                    ? 'assets/images/illustrate/p1.webp'
                                    : 'assets/images/illustrate/p2.webp',
                                width: 220.w, // 增大尺寸
                                height: 220.h, // 增大尺寸
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),

                        // 主要內容
                        Column(
                          children: [
                            // 頂部標題和返回按鈕放在同一行
                            Padding(
                              padding: EdgeInsets.only(top: 25.h, bottom: 8.h),
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
                                  // 中央標題（只有主標題）
                                  Expanded(
                                    child: Text(
                                      '個性測驗',
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

                            // 問題頁面區域
                            Expanded(
                              child: PageView(
                                controller: _pageController,
                                physics: const NeverScrollableScrollPhysics(),
                                onPageChanged: (int page) {
                                  setState(() {
                                    _currentPage = page;
                                  });
                                },
                                children: [
                                  // 問題 1
                                  Column(
                                    children: [
                                      // 副標題 - 問題1
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom: 20.h,
                                          top: 20.h,
                                        ),
                                        child: Text(
                                          _questions[0]['question'],
                                          style: TextStyle(
                                            fontSize: 18.sp,
                                            fontFamily: 'OtsutomeFont',
                                            color: const Color(0xFF23456B),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),

                                      // 問題1選項
                                      Expanded(
                                        child: ListView.builder(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20.w,
                                          ),
                                          itemCount:
                                              _questions[0]['options'].length,
                                          itemBuilder: (context, index) {
                                            final option =
                                                _questions[0]['options'][index];
                                            final isSelected =
                                                _questionOneAnswer ==
                                                option['id'];

                                            return GestureDetector(
                                              onTap:
                                                  () =>
                                                      _selectQuestionOneAnswer(
                                                        option['id'],
                                                      ),
                                              child: Container(
                                                margin: EdgeInsets.only(
                                                  bottom: 15.h,
                                                ),
                                                padding: EdgeInsets.all(20.r),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        12.r,
                                                      ),
                                                  border: Border.all(
                                                    color:
                                                        isSelected
                                                            ? const Color(
                                                              0xFFB33D1C,
                                                            )
                                                            : Colors
                                                                .transparent,
                                                    width: 3,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${option['text']}',
                                                      style: TextStyle(
                                                        fontSize: 18.sp,
                                                        fontFamily:
                                                            'OtsutomeFont',
                                                        color: const Color(
                                                          0xFF23456B,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    SizedBox(height: 10.h),
                                                    Text(
                                                      option['description'],
                                                      style: TextStyle(
                                                        fontSize: 14.sp,
                                                        fontFamily:
                                                            'OtsutomeFont',
                                                        color: const Color(
                                                          0xFF23456B,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                      // 下一步按鈕
                                      Container(
                                        margin: EdgeInsets.only(bottom: 35.h),
                                        child: ImageButton(
                                          text: '下一步',
                                          imagePath:
                                              'assets/images/ui/button/red_l.png',
                                          width: 150.w,
                                          height: 70.h,
                                          onPressed: _handleNext,
                                          isEnabled: _questionOneAnswer != null,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // 問題 2
                                  Column(
                                    children: [
                                      // 副標題 - 問題2
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom: 20.h,
                                          top: 20.h,
                                        ),
                                        child: Text(
                                          _questions[1]['question'],
                                          style: TextStyle(
                                            fontSize: 18.sp,
                                            fontFamily: 'OtsutomeFont',
                                            color: const Color(0xFF23456B),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),

                                      // 問題2選項
                                      Expanded(
                                        child: ListView.builder(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20.w,
                                          ),
                                          itemCount:
                                              _questions[1]['options'].length,
                                          itemBuilder: (context, index) {
                                            final option =
                                                _questions[1]['options'][index];
                                            final isSelected =
                                                _questionTwoAnswer ==
                                                option['id'];

                                            return GestureDetector(
                                              onTap:
                                                  () =>
                                                      _selectQuestionTwoAnswer(
                                                        option['id'],
                                                      ),
                                              child: Container(
                                                margin: EdgeInsets.only(
                                                  bottom: 15.h,
                                                ),
                                                padding: EdgeInsets.all(20.r),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        12.r,
                                                      ),
                                                  border: Border.all(
                                                    color:
                                                        isSelected
                                                            ? const Color(
                                                              0xFFB33D1C,
                                                            )
                                                            : Colors
                                                                .transparent,
                                                    width: 3,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${option['text']}',
                                                      style: TextStyle(
                                                        fontSize: 18.sp,
                                                        fontFamily:
                                                            'OtsutomeFont',
                                                        color: const Color(
                                                          0xFF23456B,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    SizedBox(height: 10.h),
                                                    Text(
                                                      option['description'],
                                                      style: TextStyle(
                                                        fontSize: 14.sp,
                                                        fontFamily:
                                                            'OtsutomeFont',
                                                        color: const Color(
                                                          0xFF23456B,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                      // 完成按鈕
                                      Container(
                                        margin: EdgeInsets.only(bottom: 35.h),
                                        child:
                                            _isLoading
                                                ? LoadingImage(
                                                  width: 60.w,
                                                  height: 60.h,
                                                  color: const Color(
                                                    0xFFB33D1C,
                                                  ),
                                                )
                                                : ImageButton(
                                                  text: '完成',
                                                  imagePath:
                                                      'assets/images/ui/button/red_l.png',
                                                  width: 150.w,
                                                  height: 70.h,
                                                  onPressed: _handleComplete,
                                                  isEnabled:
                                                      _questionTwoAnswer !=
                                                      null,
                                                ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // 頁面底部：進度指示器 - 只在非profile來源時顯示
                            if (!widget.isFromProfile)
                              Padding(
                                padding: EdgeInsets.only(bottom: 30.h),
                                child: const ProgressDotsIndicator(
                                  totalSteps: 5,
                                  currentStep: 4,
                                ),
                              ),
                            if (widget.isFromProfile) SizedBox(height: 5.h),
                          ],
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}
