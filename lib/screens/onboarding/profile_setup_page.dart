import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/user_service.dart';
import 'package:tuckin/services/image_cache_service.dart';
import 'package:tuckin/utils/index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

class ProfileSetupPage extends StatefulWidget {
  final bool isFromProfile;

  const ProfileSetupPage({super.key, this.isFromProfile = false});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final UserService _userService = UserService();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _personalDescController = TextEditingController();

  // 性別選擇，0-未選擇，1-男，2-女，3-不設定（儲存為non_binary）
  int _selectedGender = 0;
  int _previousGender = 0; // 用於追蹤性別變化

  bool _isLoading = false;
  bool _isDataLoaded = false;
  bool _showGenderTip = false; // 控制性別提示框顯示

  // 頭像相關
  String? _avatarUrl; // 自訂頭像的 URL（從網路載入的 presigned URL）
  String? _defaultAvatarPath; // 預設頭像的本地路徑
  String? _uploadedAvatarPath; // 已上傳的頭像路徑（用於儲存到資料庫）
  Uint8List? _localAvatarBytes; // 本地壓縮的頭像數據（用於直接顯示）
  bool _hasCustomAvatar = false; // 是否已上傳自訂頭像
  bool _isLoadingAvatar = false; // 頭像是否正在載入中
  bool _isProcessingAvatar = false; // 是否正在處理頭像（上傳或刪除中）

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    // 添加監聽器，當暱稱輸入框變更時重新渲染頁面
    _nicknameController.addListener(_updateButtonState);
    // 初始化預設頭像
    _updateDefaultAvatar();
  }

  /// 獲取隨機預設頭像路徑
  String _getRandomDefaultAvatar(int gender) {
    final random = Random();
    if (gender == 1) {
      // 男性：male_1.webp ~ male_6.webp
      final index = random.nextInt(6) + 1;
      return 'assets/images/avatar/no_bg/male_$index.webp';
    } else if (gender == 2) {
      // 女性：female_1.webp ~ female_6.webp
      final index = random.nextInt(6) + 1;
      return 'assets/images/avatar/no_bg/female_$index.webp';
    } else {
      // 性別未設定或不設定：隨機選擇任一張
      final isMale = random.nextBool();
      if (isMale) {
        final index = random.nextInt(6) + 1;
        return 'assets/images/avatar/no_bg/male_$index.webp';
      } else {
        final index = random.nextInt(6) + 1;
        return 'assets/images/avatar/no_bg/female_$index.webp';
      }
    }
  }

  /// 更新預設頭像
  void _updateDefaultAvatar() {
    if (!_hasCustomAvatar) {
      final newDefaultPath = _getRandomDefaultAvatar(_selectedGender);
      setState(() {
        _defaultAvatarPath = newDefaultPath;
        _uploadedAvatarPath = newDefaultPath; // 同時更新 uploadedAvatarPath 以便保存
      });
    }
  }

  /// 載入用戶頭像
  Future<void> _loadUserAvatar() async {
    setState(() {
      _isLoadingAvatar = true;
    });

    try {
      // 優先使用本地已壓縮的圖片（剛上傳但還沒保存到資料庫的情況）
      if (_hasCustomAvatar && _localAvatarBytes != null) {
        debugPrint('使用本地已上傳的頭像');
        setState(() {
          _isLoadingAvatar = false;
        });
        return;
      }

      // 檢查 _uploadedAvatarPath 的類型
      if (_uploadedAvatarPath == null || _uploadedAvatarPath!.isEmpty) {
        // 沒有頭像路徑，生成隨機預設頭像
        debugPrint('沒有頭像路徑，生成隨機預設頭像');
        setState(() {
          _hasCustomAvatar = false;
          _updateDefaultAvatar();
          _isLoadingAvatar = false;
        });
      } else if (_uploadedAvatarPath!.startsWith('assets/')) {
        // 是預設頭像路徑，直接使用
        debugPrint('使用預設頭像: $_uploadedAvatarPath');
        setState(() {
          _defaultAvatarPath = _uploadedAvatarPath;
          _hasCustomAvatar = false;
          _isLoadingAvatar = false;
        });
      } else if (_uploadedAvatarPath!.startsWith('avatars/')) {
        // 是 R2 上的自訂頭像，使用智能載入
        debugPrint('載入 R2 自訂頭像: $_uploadedAvatarPath');

        final result = await _userService.loadAvatarSmart(_uploadedAvatarPath!);

        if (result['success'] == true) {
          if (mounted) {
            setState(() {
              _avatarUrl =
                  result['isFromCache'] == true
                      ? result['filePath'] // 使用本地快取文件路徑
                      : result['url']; // 使用網路 URL
              _hasCustomAvatar = true;
              _isLoadingAvatar = false;
            });
          }
          debugPrint('頭像載入成功，來源: ${result['isFromCache'] ? '本地快取' : '網路下載'}');
        } else {
          // 載入失敗，使用預設頭像
          debugPrint('頭像載入失敗，使用預設頭像');
          if (mounted) {
            setState(() {
              _hasCustomAvatar = false;
              _updateDefaultAvatar();
              _isLoadingAvatar = false;
            });
          }
        }
      } else {
        // 未知格式，使用預設頭像
        debugPrint('未知頭像路徑格式: $_uploadedAvatarPath，使用預設頭像');
        setState(() {
          _hasCustomAvatar = false;
          _updateDefaultAvatar();
          _isLoadingAvatar = false;
        });
      }
    } catch (e) {
      debugPrint('載入頭像失敗: $e');
      setState(() {
        _hasCustomAvatar = false;
        _updateDefaultAvatar();
        _isLoadingAvatar = false;
      });
    }
  }

  /// 處理頭像上傳
  Future<void> _handleAvatarUpload() async {
    // 防止重複操作
    if (_isProcessingAvatar) {
      return;
    }

    // 保存先前的狀態，以便錯誤時恢復
    final previousAvatarPath = _uploadedAvatarPath;
    final previousAvatarBytes = _localAvatarBytes;
    final previousHasCustomAvatar = _hasCustomAvatar;

    try {
      // 步驟 1: 先讓用戶選擇並壓縮圖片（此時不顯示 loading）
      final imageBytes = await _userService.pickAndConvertImageToWebP();

      // 如果用戶取消選擇，直接返回
      if (imageBytes == null) {
        debugPrint('用戶取消選擇圖片');
        return;
      }

      // 步驟 2: 用戶已選擇圖片，開始顯示 loading 並標記處理中
      if (mounted) {
        setState(() {
          _isLoadingAvatar = true;
          _isProcessingAvatar = true;
        });
      }

      // 步驟 3: 獲取上傳 URL
      final uploadData = await _userService.getAvatarUploadUrl();

      if (uploadData == null) {
        debugPrint('獲取上傳 URL 失敗');
        if (mounted) {
          setState(() {
            _isLoadingAvatar = false;
            _isProcessingAvatar = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '獲取上傳連結失敗',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
            ),
          );
        }
        return;
      }

      final uploadUrl = uploadData['upload_url'] as String;
      final avatarPath = uploadData['avatar_path'] as String;

      // 步驟 4: 上傳圖片到 R2
      final uploadSuccess = await _userService.uploadImageToR2(
        uploadUrl,
        imageBytes,
      );

      if (!uploadSuccess) {
        debugPrint('上傳圖片失敗');
        if (mounted) {
          setState(() {
            _isLoadingAvatar = false;
            _isProcessingAvatar = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '上傳圖片失敗',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
            ),
          );
        }
        return;
      }

      // 步驟 5: 立即快取新頭像並更新狀態
      if (mounted) {
        // 清除舊的自訂頭像快取（若存在）
        if (previousAvatarPath != null &&
            previousAvatarPath.startsWith('avatars/')) {
          await ImageCacheService().clearCacheByKey(
            previousAvatarPath,
            CacheType.avatar,
          );
        }

        // 立即快取新上傳的頭像（使用 UserService 的方法）
        await _userService.cacheUploadedAvatar(avatarPath, imageBytes);

        // 同時使用 Flutter 的預緩存確保當前顯示正常
        final image = MemoryImage(imageBytes);
        await precacheImage(image, context);

        // 更新狀態並隱藏 loading
        setState(() {
          _uploadedAvatarPath = avatarPath;
          _localAvatarBytes = imageBytes;
          _hasCustomAvatar = true;
          _isLoadingAvatar = false;
          _isProcessingAvatar = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '頭像上傳成功',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('上傳頭像時發生錯誤: $e');
      // 發生錯誤，恢復先前狀態
      if (mounted) {
        setState(() {
          _uploadedAvatarPath = previousAvatarPath;
          _localAvatarBytes = previousAvatarBytes;
          _hasCustomAvatar = previousHasCustomAvatar;
          _isLoadingAvatar = false;
          _isProcessingAvatar = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '頭像上傳失敗',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  /// 處理頭像刪除
  Future<void> _handleAvatarDelete() async {
    // 防止重複操作
    if (_isProcessingAvatar) {
      return;
    }

    // 標記開始處理
    setState(() {
      _isProcessingAvatar = true;
    });

    // 只清除本地狀態，不調用後端刪除
    // 實際的資料庫刪除會在按下「完成」或「下一步」時處理
    setState(() {
      _avatarUrl = null;
      _hasCustomAvatar = false;
      _uploadedAvatarPath = null; // 清除已上傳的頭像路徑
      _localAvatarBytes = null; // 清除本地圖片數據
      _updateDefaultAvatar();
      _isProcessingAvatar = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('頭像已移除', style: TextStyle(fontFamily: 'OtsutomeFont')),
        ),
      );
    }
  }

  // 載入用戶資料
  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 獲取當前用戶
      final currentUser = await _authService.getCurrentUser();

      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '請先登入您的帳號',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
              duration: Duration(seconds: 2),
            ),
          );
          // 延遲一下再導航，讓用戶看到提示訊息
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            }
          });
        }
        return;
      }

      if (widget.isFromProfile) {
        // 如果是從profile頁面導航過來的，載入用戶資料
        try {
          debugPrint('正在載入用戶資料，用戶 ID: ${currentUser.id}');
          final userProfile = await _databaseService.getUserCompleteProfile(
            currentUser.id,
          );

          if (userProfile['profile'] != null) {
            final profile = userProfile['profile'];
            debugPrint('用戶資料: $profile');

            // 設置暱稱
            if (profile['nickname'] != null) {
              _nicknameController.text = profile['nickname'];
            }

            // 設置性別
            if (profile['gender'] != null) {
              if (profile['gender'] == 'male') {
                _selectedGender = 1;
              } else if (profile['gender'] == 'female') {
                _selectedGender = 2;
              } else if (profile['gender'] == 'non_binary') {
                _selectedGender = 3;
              }
            }
            _previousGender = _selectedGender;

            // 設置個人描述
            if (profile['personal_desc'] != null) {
              _personalDescController.text = profile['personal_desc'];
            }

            // 設置頭像路徑
            if (profile['avatar_path'] != null) {
              _uploadedAvatarPath = profile['avatar_path'];
              debugPrint('從資料庫載入的頭像路徑: $_uploadedAvatarPath');
            } else {
              debugPrint('資料庫中沒有頭像路徑');
            }

            setState(() {
              _isDataLoaded = true;
            });

            // 載入頭像
            await _loadUserAvatar();
          }
        } catch (e) {
          debugPrint('載入用戶資料出錯: $e');
        }
      } else {
        // 檢查用戶是否已完成設定
        final hasCompleted = await _databaseService.hasCompletedSetup(
          currentUser.id,
        );

        // 如果已完成設定，直接導航到主頁
        if (hasCompleted && mounted) {
          try {
            await _databaseService.updateUserStatus(currentUser.id, 'booking');

            // 設置一個標誌表示是新用戶第一次使用
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('is_new_user', true);
          } catch (error) {
            debugPrint('更新用戶狀態出錯: $error');
          }
          final navigationService = NavigationService();
          navigationService.navigateToDinnerReservation(context);
        }
      }
    } catch (error) {
      // 錯誤處理
      debugPrint('檢查用戶資料錯誤: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nicknameController.removeListener(_updateButtonState);
    _nicknameController.dispose();
    _personalDescController.dispose();
    super.dispose();
  }

  // 更新按鈕狀態的方法
  void _updateButtonState() {
    setState(() {
      // 強制刷新界面
    });
  }

  // 檢查表單是否有效
  bool _isFormValid() {
    return _nicknameController.text.trim().isNotEmpty &&
        _selectedGender != 0 &&
        !_isProcessingAvatar; // 處理頭像時不能提交
  }

  // 處理返回按鈕
  void _handleBack() {
    if (widget.isFromProfile) {
      // 如果是從profile頁面導航過來的，顯示確認對話框
      showCustomConfirmationDialog(
        context: context,
        iconPath: 'assets/images/icon/save.webp',
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
          if (_isFormValid()) {
            await _handleNextStep();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '請填寫必填項目',
                  style: TextStyle(fontFamily: 'OtsutomeFont'),
                ),
              ),
            );
          }
        },
      );
    } else {
      // 顯示提示訊息，告知用戶無法返回
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '請完成基本資料設定',
            style: TextStyle(fontFamily: 'OtsutomeFont'),
          ),
        ),
      );
    }
  }

  // 處理下一步或完成按鈕
  Future<void> _handleNextStep() async {
    // 檢查是否有必填項目未填
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請輸入暱稱', style: TextStyle(fontFamily: 'OtsutomeFont')),
        ),
      );
      return;
    }

    if (_selectedGender == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請選擇性別', style: TextStyle(fontFamily: 'OtsutomeFont')),
        ),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '請先登入您的帳號',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
              duration: Duration(seconds: 2),
            ),
          );
          // 延遲一下再導航，讓用戶看到提示訊息
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            }
          });
        }
        return;
      }

      // 構建用戶資料
      final userData = {
        'user_id': currentUser.id,
        'nickname': _nicknameController.text.trim(),
        'gender':
            _selectedGender == 1
                ? 'male'
                : _selectedGender == 2
                ? 'female'
                : 'non_binary',
        'personal_desc':
            _personalDescController.text.trim().isEmpty
                ? '' // 如果個人亮點描述為空，則設為空字串
                : _personalDescController.text.trim(),
      };

      // 如果有上傳頭像，加入 avatar_path
      if (_uploadedAvatarPath != null) {
        userData['avatar_path'] = _uploadedAvatarPath!;
      }

      // 儲存用戶資料到 Supabase
      await _databaseService.updateUserProfile(userData);

      if (mounted) {
        if (widget.isFromProfile) {
          // 如果是從profile頁面導航過來的，保存後返回profile頁面
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '個人資料更新成功',
                style: TextStyle(fontFamily: 'OtsutomeFont'),
              ),
            ),
          );
          Navigator.of(context).pop();
        } else {
          // 使用NavigationService進行導航
          final navigationService = NavigationService();
          navigationService.navigateToNextSetupStep(context, 'profile_setup');
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '儲存資料失敗: $error',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
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
    return WillPopScope(
      // 根據來源決定系統返回按鈕行為
      onWillPop: () async {
        _handleBack();
        // 阻止默認返回行為，讓我們的_handleBack邏輯決定是否返回
        return false;
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
            child: GestureDetector(
              onTap: () {
                // 點擊空白處收起鍵盤
                FocusScope.of(context).unfocus();
              },
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  _isLoading && !_isDataLoaded
                      ? Center(
                        child: LoadingImage(
                          width: 60.w,
                          height: 60.h,
                          color: const Color(0xFFB33D1C),
                        ),
                      )
                      : Column(
                        children: [
                          // 頂部標題和返回按鈕
                          Padding(
                            padding: EdgeInsets.only(top: 25.h, bottom: 10.h),
                            child: Row(
                              children: [
                                // 左側返回按鈕 - 只在從profile頁面來時顯示
                                if (widget.isFromProfile)
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
                                // 中央標題
                                Expanded(
                                  child: Text(
                                    '基本資料設定',
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
                                if (widget.isFromProfile) SizedBox(width: 55.w),
                              ],
                            ),
                          ),

                          // 頭像顯示區域
                          Container(
                            margin: EdgeInsets.only(top: 15.h),
                            child: Center(
                              child: GestureDetector(
                                onTap:
                                    _hasCustomAvatar
                                        ? null // 如果有自訂頭像，不響應整個頭像的點擊
                                        : _handleAvatarUpload, // 如果是預設頭像，點擊可上傳
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // 圓形頭像容器
                                    Container(
                                      width: 120.w,
                                      height: 120.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF23456B),
                                          width: 2.5,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child:
                                            _isLoadingAvatar
                                                ? Container(
                                                  color: Colors.white,
                                                  child: Center(
                                                    child: LoadingImage(
                                                      width: 40.w,
                                                      height: 40.h,
                                                      color: const Color(
                                                        0xFFB33D1C,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                : _hasCustomAvatar &&
                                                    _localAvatarBytes != null
                                                ? Image.memory(
                                                  _localAvatarBytes!,
                                                  fit: BoxFit.cover,
                                                )
                                                : _hasCustomAvatar &&
                                                    _avatarUrl != null
                                                ? _avatarUrl!.startsWith('/')
                                                    ? // 本地快取文件，使用 Image.file
                                                    Image.file(
                                                      File(_avatarUrl!),
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        debugPrint(
                                                          '本地快取文件損壞，觸發重新載入: $_uploadedAvatarPath',
                                                        );
                                                        // 本地文件損壞，觸發重新載入
                                                        Future.microtask(
                                                          () =>
                                                              _loadUserAvatar(),
                                                        );
                                                        // 暫時顯示預設頭像
                                                        return Container(
                                                          color: Colors.white,
                                                          child: Image.asset(
                                                            _defaultAvatarPath ??
                                                                'assets/images/avatar/no_bg/male_1.webp',
                                                            fit: BoxFit.cover,
                                                          ),
                                                        );
                                                      },
                                                    )
                                                    : // 網路 URL，使用 CachedNetworkImage
                                                    CachedNetworkImage(
                                                      imageUrl: _avatarUrl!,
                                                      cacheKey:
                                                          _uploadedAvatarPath, // 使用穩定的快取 key
                                                      cacheManager:
                                                          ImageCacheService()
                                                              .avatarCacheManager,
                                                      fit: BoxFit.cover,
                                                      placeholder: (
                                                        context,
                                                        url,
                                                      ) {
                                                        return Container(
                                                          color: Colors.white,
                                                          child: Center(
                                                            child: LoadingImage(
                                                              width: 40.w,
                                                              height: 40.h,
                                                              color:
                                                                  const Color(
                                                                    0xFFB33D1C,
                                                                  ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      errorWidget: (
                                                        context,
                                                        url,
                                                        error,
                                                      ) {
                                                        debugPrint(
                                                          '網路圖片載入失敗，觸發重新載入: $_uploadedAvatarPath',
                                                        );
                                                        // 網路圖片載入失敗，觸發重新載入
                                                        Future.microtask(
                                                          () =>
                                                              _loadUserAvatar(),
                                                        );
                                                        // 暫時顯示預設頭像
                                                        return Container(
                                                          color: Colors.white,
                                                          child: Image.asset(
                                                            _defaultAvatarPath ??
                                                                'assets/images/avatar/no_bg/male_1.webp',
                                                            fit: BoxFit.cover,
                                                          ),
                                                        );
                                                      },
                                                    )
                                                : Container(
                                                  color: Colors.white,
                                                  child: Image.asset(
                                                    _defaultAvatarPath ??
                                                        'assets/images/avatar/no_bg/male_1.webp',
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                      ),
                                    ),
                                    // 右下角功能圖示
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: _AvatarIconButton(
                                        iconPath:
                                            _hasCustomAvatar
                                                ? 'assets/images/icon/cross.webp'
                                                : 'assets/images/icon/camera.webp',
                                        size: 36.w,
                                        onTap:
                                            _hasCustomAvatar
                                                ? _handleAvatarDelete
                                                : _handleAvatarUpload,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // 暱稱輸入框
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            margin: EdgeInsets.only(top: 10.h, bottom: 5.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 8.w),
                                  child: Text(
                                    '綽號',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    // 點擊暱稱輸入框時防止冒泡到父級GestureDetector
                                  },
                                  child: IconTextInput(
                                    hintText: '請輸入綽號',
                                    iconPath:
                                        'assets/images/icon/user_profile.webp',
                                    controller: _nicknameController,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 性別選擇
                          Container(
                            margin: EdgeInsets.only(top: 2.5.h, bottom: 5.h),
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: 8.w,
                                    bottom: 8.h,
                                  ),
                                  child: Text(
                                    '性別',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    // 男性選項
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedGender = 1;
                                            // 如果沒有自訂頭像且性別變更，更新預設頭像
                                            if (!_hasCustomAvatar &&
                                                _previousGender != 1) {
                                              _updateDefaultAvatar();
                                              _previousGender = 1;
                                            }
                                          });
                                        },
                                        child: Container(
                                          height: 50.h,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                              color:
                                                  _selectedGender == 1
                                                      ? const Color(0xFF23456B)
                                                      : Colors.white,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12.r,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '男生',
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontFamily: 'OtsutomeFont',
                                                color: const Color(0xFF23456B),
                                                fontWeight: FontWeight.bold,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(width: 15.w),

                                    // 女性選項
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedGender = 2;
                                            // 如果沒有自訂頭像且性別變更，更新預設頭像
                                            if (!_hasCustomAvatar &&
                                                _previousGender != 2) {
                                              _updateDefaultAvatar();
                                              _previousGender = 2;
                                            }
                                          });
                                        },
                                        child: Container(
                                          height: 50.h,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                              color:
                                                  _selectedGender == 2
                                                      ? const Color(0xFF23456B)
                                                      : Colors.white,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12.r,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '女生',
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontFamily: 'OtsutomeFont',
                                                color: const Color(0xFF23456B),
                                                fontWeight: FontWeight.bold,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    SizedBox(width: 15.w),

                                    // 不設定選項
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedGender = 3;
                                            _showGenderTip = true; // 顯示提示框
                                            // 如果沒有自訂頭像且性別變更，更新預設頭像
                                            if (!_hasCustomAvatar &&
                                                _previousGender != 3) {
                                              _updateDefaultAvatar();
                                              _previousGender = 3;
                                            }
                                          });

                                          // 3秒後自動隱藏提示框
                                          Future.delayed(
                                            const Duration(seconds: 4),
                                            () {
                                              if (mounted) {
                                                setState(() {
                                                  _showGenderTip = false;
                                                });
                                              }
                                            },
                                          );
                                        },
                                        child: Container(
                                          height: 50.h,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                              color:
                                                  _selectedGender == 3
                                                      ? const Color(0xFF23456B)
                                                      : Colors.white,
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12.r,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '不設定',
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontFamily: 'OtsutomeFont',
                                                color: const Color(0xFF23456B),
                                                fontWeight: FontWeight.bold,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // 個人亮點描述輸入框
                          Container(
                            margin: EdgeInsets.only(top: 12.5.h),
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: 8.w,
                                    bottom: 8.h,
                                  ),
                                  child: Text(
                                    '一句話介紹自己',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    // 點擊文字框時防止冒泡到父級GestureDetector
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 15.w,
                                      vertical: 10.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: const Color(0xFF23456B),
                                        width: 2,
                                      ),
                                    ),
                                    child: SizedBox(
                                      height: 70.h,
                                      child: TextField(
                                        controller: _personalDescController,
                                        maxLines: null,
                                        minLines: 3,
                                        keyboardType: TextInputType.text,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (value) {
                                          // 按下完成按鈕時收起鍵盤
                                          FocusScope.of(context).unfocus();
                                        },
                                        decoration: InputDecoration(
                                          hintText: '例：我喜歡嘗試新的食物！',
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(
                                            color: Colors.grey,
                                            fontFamily: 'OtsutomeFont',
                                            fontSize: 16.sp,
                                          ),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        style: TextStyle(
                                          fontFamily: 'OtsutomeFont',
                                          fontSize: 16.sp,
                                          color: const Color(0xFF23456B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 彈性空間
                          Expanded(child: Container()),

                          // 底部按鈕區域
                          Container(
                            margin: EdgeInsets.only(bottom: 20.h),
                            child: Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20.h),
                                  child:
                                      // 下一步或完成按鈕
                                      _isLoading
                                          ? Container(
                                            alignment: Alignment.center,
                                            child: LoadingImage(
                                              width: 60.w,
                                              height: 60.h,
                                              color: const Color(0xFFB33D1C),
                                            ),
                                          )
                                          : ImageButton(
                                            text:
                                                widget.isFromProfile
                                                    ? '完成'
                                                    : '下一步',
                                            imagePath:
                                                'assets/images/ui/button/red_l.webp',
                                            width: 150.w,
                                            height: 70.h,
                                            onPressed: _handleNextStep,
                                            isEnabled:
                                                _isFormValid(), // 根據表單有效性決定按鈕是否啟用
                                          ),
                                ),
                                // 進度指示器 - 只在非profile來源時顯示
                                if (!widget.isFromProfile)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: 15.h,
                                      bottom: 10.h,
                                    ),
                                    child: const ProgressDotsIndicator(
                                      totalSteps: 5,
                                      currentStep: 2,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                  // 右上角性別提示框
                  if (_showGenderTip)
                    Positioned(
                      top: 20.h,
                      right: 20.w,
                      child: InfoTipBox(
                        message: '建議設定性別，聚餐體驗更好歐！',
                        show: _showGenderTip,
                        onHide: () {
                          setState(() {
                            _showGenderTip = false;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 頭像圖標按鈕（帶陰影和按壓效果）
class _AvatarIconButton extends StatefulWidget {
  final String iconPath;
  final double size;
  final VoidCallback onTap;

  const _AvatarIconButton({
    required this.iconPath,
    required this.size,
    required this.onTap,
  });

  @override
  State<_AvatarIconButton> createState() => _AvatarIconButtonState();
}

class _AvatarIconButtonState extends State<_AvatarIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // 陰影偏移量
    final shadowOffset = 3.h;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: SizedBox(
        width: widget.size,
        height: widget.size + shadowOffset,
        child: Stack(
          children: [
            // 底部陰影圖片
            if (!_isPressed)
              Positioned(
                left: 0,
                top: shadowOffset,
                child: Image.asset(
                  widget.iconPath,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  color: Colors.black.withOpacity(0.4),
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),

            // 主圖標
            Positioned(
              top: _isPressed ? shadowOffset : 0,
              left: 0,
              child: Image.asset(
                widget.iconPath,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
