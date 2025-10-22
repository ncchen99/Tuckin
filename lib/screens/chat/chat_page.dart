import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/chat_service.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/user_service.dart';
import 'package:tuckin/services/image_cache_service.dart';
import 'package:tuckin/models/chat_message.dart';
import 'package:tuckin/utils/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'dart:io';

class ChatPage extends StatefulWidget {
  final String diningEventId;

  const ChatPage({super.key, required this.diningEventId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _currentUserId;
  List<ChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _subscribeToMessages();

    // 註冊生命週期監聽
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _chatService.unsubscribeFromMessages(widget.diningEventId);
    _messageController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // APP 回到前台時同步新訊息
      debugPrint('APP 回到前台，同步聊天訊息');
      _chatService.syncMessages(widget.diningEventId);
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUserId = user?.id;
      });
    }
  }

  void _subscribeToMessages() {
    _chatService.subscribeToMessages(widget.diningEventId).listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        // 自動滾動到最新訊息
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendTextMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    final success = await _chatService.sendTextMessage(
      widget.diningEventId,
      content,
    );

    if (mounted) {
      setState(() {
        _isSending = false;
      });

      if (success) {
        _messageController.clear();
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '發送訊息失敗',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _sendImageMessage() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    final success = await _chatService.sendImageMessage(widget.diningEventId);

    if (mounted) {
      setState(() {
        _isSending = false;
      });

      if (success) {
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '發送圖片失敗',
              style: TextStyle(fontFamily: 'OtsutomeFont'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用 resizeToAvoidBottomInset: true 讓鍵盤出現時推動內容
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background/bg2.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header - 固定在頂部
              _buildHeader(),

              // 訊息區域 - 可滾動
              Expanded(
                child: Stack(
                  children: [
                    // 右下角背景圖片
                    Positioned(
                      right: -7.w,
                      bottom: -45.h,
                      child: Opacity(
                        opacity: 0.65,
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.6,
                            0.1,
                            0.1,
                            0,
                            0,
                            0.1,
                            0.6,
                            0.1,
                            0,
                            0,
                            0.1,
                            0.1,
                            0.6,
                            0,
                            0,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ]),
                          child: Image.asset(
                            'assets/images/illustrate/p3.webp',
                            width: 220.w,
                            height: 220.h,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    // 訊息列表
                    _buildMessageList(),
                  ],
                ),
              ),

              // 輸入區域 - 固定在底部
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 25.h),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 中央標題
          Center(
            child: Text(
              '聊天室',
              style: TextStyle(
                fontSize: 20.sp,
                fontFamily: 'OtsutomeFont',
                color: const Color(0xFF23456B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 左側返回按鈕
          Positioned(
            left: 0,
            child: BackIconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              width: 35.w,
              height: 35.h,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          '還沒有訊息，開始聊天吧！',
          style: TextStyle(
            fontSize: 16.sp,
            fontFamily: 'OtsutomeFont',
            color: const Color(0xFF666666),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.userId == _currentUserId;

        return _buildMessageItem(message, isMe);
      },
    );
  }

  Widget _buildMessageItem(ChatMessage message, bool isMe) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 他人訊息：左側頭像
          if (!isMe) ...[_buildAvatar(message), SizedBox(width: 10.w)],

          // 訊息內容
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color:
                    isMe
                        ? const Color(0xFFFFD9B3) // 淡橘色
                        : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: Offset(0, 2.h),
                  ),
                ],
              ),
              child:
                  message.isText
                      ? _buildTextMessage(message, isMe)
                      : _buildImageMessage(message),
            ),
          ),

          // 自己訊息：不顯示頭像
          if (isMe) SizedBox(width: 10.w),
        ],
      ),
    );
  }

  Widget _buildAvatar(ChatMessage message) {
    return Container(
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF23456B), width: 2),
      ),
      child: ClipOval(child: _buildAvatarImage(message)),
    );
  }

  Widget _buildAvatarImage(ChatMessage message) {
    final avatarPath = message.senderAvatarPath;
    final gender = message.senderGender;

    // 如果沒有頭像，使用預設頭像
    if (avatarPath == null || avatarPath.isEmpty) {
      return Container(
        color: Colors.white,
        child: Image.asset(_getRandomDefaultAvatar(gender), fit: BoxFit.cover),
      );
    }

    // 如果是本地資源頭像
    if (avatarPath.startsWith('assets/')) {
      return Container(
        color: Colors.white,
        child: Image.asset(avatarPath, fit: BoxFit.cover),
      );
    }

    // 如果是 R2 上的自訂頭像
    if (avatarPath.startsWith('avatars/')) {
      return FutureBuilder<File?>(
        future: ImageCacheService().getCachedImageByKey(
          avatarPath,
          CacheType.avatar,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data != null &&
              snapshot.data!.existsSync()) {
            return Image.file(snapshot.data!, fit: BoxFit.cover);
          }

          // 嘗試從網路載入
          return FutureBuilder<String?>(
            future: UserService().getOtherUserAvatarUrl(message.userId),
            builder: (context, urlSnapshot) {
              if (urlSnapshot.hasData && urlSnapshot.data != null) {
                return CachedNetworkImage(
                  imageUrl: urlSnapshot.data!,
                  cacheManager: ImageCacheService().getCacheManager(
                    CacheType.avatar,
                  ),
                  cacheKey: avatarPath,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(
                        color: Colors.white,
                        child: Center(
                          child: LoadingImage(
                            width: 15.w,
                            height: 15.h,
                            color: const Color(0xFF23456B),
                          ),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => Container(
                        color: Colors.white,
                        child: Image.asset(
                          _getRandomDefaultAvatar(gender),
                          fit: BoxFit.cover,
                        ),
                      ),
                );
              }

              return Container(
                color: Colors.white,
                child: Image.asset(
                  _getRandomDefaultAvatar(gender),
                  fit: BoxFit.cover,
                ),
              );
            },
          );
        },
      );
    }

    // 未知格式，使用預設頭像
    return Container(
      color: Colors.white,
      child: Image.asset(_getRandomDefaultAvatar(gender), fit: BoxFit.cover),
    );
  }

  String _getRandomDefaultAvatar(String? gender) {
    final random = Random();
    if (gender == 'male') {
      final avatarNumber = random.nextInt(6) + 1;
      return 'assets/images/avatar/no_bg/male_$avatarNumber.webp';
    } else if (gender == 'female') {
      final avatarNumber = random.nextInt(6) + 1;
      return 'assets/images/avatar/no_bg/female_$avatarNumber.webp';
    } else {
      final isMale = random.nextBool();
      final avatarNumber = random.nextInt(6) + 1;
      return isMale
          ? 'assets/images/avatar/no_bg/male_$avatarNumber.webp'
          : 'assets/images/avatar/no_bg/female_$avatarNumber.webp';
    }
  }

  Widget _buildTextMessage(ChatMessage message, bool isMe) {
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // 發送者暱稱（只在不是自己時顯示）
        if (!isMe && message.senderNickname != null) ...[
          Text(
            message.senderNickname!,
            style: TextStyle(
              fontSize: 12.sp,
              fontFamily: 'OtsutomeFont',
              color: const Color(0xFF666666),
            ),
          ),
          SizedBox(height: 4.h),
        ],

        // 訊息內容
        Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 16.sp,
            fontFamily: 'OtsutomeFont',
            color: const Color(0xFF23456B),
          ),
        ),

        SizedBox(height: 4.h),

        // 時間
        Text(
          _formatTime(message.createdAt),
          style: TextStyle(
            fontSize: 11.sp,
            fontFamily: 'OtsutomeFont',
            color: const Color(0xFF999999),
          ),
        ),
      ],
    );
  }

  Widget _buildImageMessage(ChatMessage message) {
    if (message.imagePath == null) {
      return const Text('[圖片載入失敗]');
    }

    return FutureBuilder<String?>(
      future: _chatService.getImageUrl(message.imagePath!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 200.w,
            height: 200.w,
            child: Center(
              child: LoadingImage(
                width: 40.w,
                height: 40.h,
                color: const Color(0xFF23456B),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: CachedNetworkImage(
              imageUrl: snapshot.data!,
              width: 200.w,
              fit: BoxFit.cover,
              placeholder:
                  (context, url) => SizedBox(
                    width: 200.w,
                    height: 200.w,
                    child: Center(
                      child: LoadingImage(
                        width: 40.w,
                        height: 40.h,
                        color: const Color(0xFF23456B),
                      ),
                    ),
                  ),
              errorWidget:
                  (context, url, error) => Container(
                    width: 200.w,
                    height: 200.w,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
            ),
          );
        }

        return Container(
          width: 200.w,
          height: 200.w,
          color: Colors.grey[300],
          child: const Icon(Icons.error),
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, -2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          // 相機按鈕
          _buildCameraButton(),

          SizedBox(width: 10.w),

          // 輸入框
          Expanded(child: _buildMessageInput()),

          SizedBox(width: 10.w),

          // 發送按鈕
          _buildSendButton(),
        ],
      ),
    );
  }

  Widget _buildCameraButton() {
    return GestureDetector(
      onTap: _isSending ? null : _sendImageMessage,
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
                'assets/images/icon/camera.webp',
                width: 35.w,
                height: 35.h,
                color: Colors.black.withOpacity(0.4),
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
            // 主圖標
            Image.asset(
              'assets/images/icon/camera.webp',
              width: 35.w,
              height: 35.h,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF23456B), width: 2),
      ),
      child: TextField(
        controller: _messageController,
        enabled: !_isSending,
        maxLines: null,
        style: TextStyle(
          fontFamily: 'OtsutomeFont',
          fontSize: 16.sp,
          height: 1.2,
        ),
        decoration: InputDecoration(
          hintText: '輸入訊息...',
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: Colors.grey,
            fontFamily: 'OtsutomeFont',
            fontSize: 16.sp,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTapDown: (_) {
        if (!_isSending) {
          setState(() {
            // 按下時不顯示陰影（模擬按下效果）
          });
        }
      },
      onTapUp: (_) {
        if (!_isSending) {
          setState(() {
            // 放開時顯示陰影
          });
          _sendTextMessage();
        }
      },
      onTapCancel: () {
        if (!_isSending) {
          setState(() {
            // 取消時顯示陰影
          });
        }
      },
      child: SizedBox(
        width: 35.w,
        height: 35.h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 底部陰影（按下時隱藏）
            if (!_isSending)
              Positioned(
                left: 0,
                top: 2.h,
                child: Image.asset(
                  'assets/images/icon/send.webp',
                  width: 35.w,
                  height: 35.h,
                  color: Colors.black.withOpacity(0.4),
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            // 主圖標
            Image.asset(
              'assets/images/icon/send.webp',
              width: 35.w,
              height: 35.h,
            ),
          ],
        ),
      ),
    );
  }
}

