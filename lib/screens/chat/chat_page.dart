import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/services/chat_service.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/user_service.dart';
import 'package:tuckin/services/image_cache_service.dart';
import 'package:tuckin/models/chat_message.dart';
import 'package:tuckin/utils/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
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
  final Map<String, int> _fixedAvatars = {}; // 儲存固定頭像索引

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
    _chatService.subscribeToMessages(widget.diningEventId).listen((
      messages,
    ) async {
      if (mounted) {
        // 確保訊息按 created_at 升序排序（從舊到新）
        final sortedMessages = List<ChatMessage>.from(messages);
        sortedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        // 為沒有自訂頭像的用戶載入固定頭像索引
        for (final message in sortedMessages) {
          if ((message.senderAvatarPath == null ||
                  message.senderAvatarPath!.isEmpty ||
                  !message.senderAvatarPath!.startsWith('avatars/')) &&
              !_fixedAvatars.containsKey(message.userId)) {
            final index = await _chatService.getFixedAvatarIndex(
              message.userId,
              widget.diningEventId,
              message.senderGender,
            );
            _fixedAvatars[message.userId] = index;
          }
        }

        setState(() {
          // 反轉訊息順序：最新訊息在前 [新, 中, 舊]
          // 這樣配合 reverse: true，最新訊息會顯示在底部
          _messages = sortedMessages.reversed.toList();
        });
        // 自動滾動到最新訊息
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    // 使用 reverse: true 時，最小滾動位置是最新訊息
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0, // reverse 模式下，0 是最底部（最新訊息）
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

    // 清空輸入框
    _messageController.clear();

    setState(() {
      _isSending = true;
    });

    // 樂觀UI更新：立即顯示訊息（傳送中狀態）
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = ChatMessage(
      id: tempId,
      diningEventId: widget.diningEventId,
      userId: _currentUserId!,
      content: content,
      messageType: 'text',
      createdAt: DateTime.now(),
      sendStatus: 'pending',
    );

    setState(() {
      _messages = [..._messages, optimisticMessage];
    });
    _scrollToBottom();

    final success = await _chatService.sendTextMessage(
      widget.diningEventId,
      content,
    );

    if (mounted) {
      setState(() {
        _isSending = false;
      });

      if (!success) {
        // 發送失敗，移除樂觀訊息並顯示錯誤
        setState(() {
          _messages = _messages.where((m) => m.id != tempId).toList();
        });

        if (mounted) {
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
      // 成功的話，Realtime 會自動更新訊息列表
    }
  }

  Future<void> _sendImageMessage() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    // 樂觀UI更新：顯示傳送中的圖片訊息
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = ChatMessage(
      id: tempId,
      diningEventId: widget.diningEventId,
      userId: _currentUserId!,
      messageType: 'image',
      createdAt: DateTime.now(),
      sendStatus: 'pending',
    );

    setState(() {
      _messages = [..._messages, optimisticMessage];
    });
    _scrollToBottom();

    final success = await _chatService.sendImageMessage(widget.diningEventId);

    if (mounted) {
      setState(() {
        _isSending = false;
      });

      if (!success) {
        // 發送失敗，移除樂觀訊息
        setState(() {
          _messages = _messages.where((m) => m.id != tempId).toList();
        });

        if (mounted) {
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
      // 成功的話，Realtime 會自動更新訊息列表
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
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
      child: Row(
        children: [
          // 左側返回按鈕
          BackIconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            width: 35.w,
            height: 35.h,
          ),

          // 中央標題
          Expanded(
            child: Center(
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
          ),

          // 右側佔位（保持對稱）
          SizedBox(width: 35.w),
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
      reverse: true, // 從底部開始渲染
      itemCount: _messages.length,
      cacheExtent: 500, // 預渲染範圍，減少跳動
      addAutomaticKeepAlives: true, // 保持已渲染的項目狀態
      itemBuilder: (context, index) {
        // _messages 已經反轉：[新, 中, 舊]
        // reverse: true 會讓 index 0（最新）顯示在視覺底部
        final message = _messages[index];
        final isMe = message.userId == _currentUserId;

        // 使用訊息 ID 作為 key，確保 Flutter 正確追蹤每個訊息
        return _buildMessageItem(message, isMe, key: ValueKey(message.id));
      },
    );
  }

  Widget _buildMessageItem(ChatMessage message, bool isMe, {Key? key}) {
    return Padding(
      key: key,
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 他人訊息：左側頭像
          if (!isMe) ...[_buildAvatar(message), SizedBox(width: 10.w)],

          // 訊息內容區域（包含名字、訊息框、時間）
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 發送者名字（只在不是自己時顯示）
                if (!isMe && message.senderNickname != null) ...[
                  Padding(
                    padding: EdgeInsets.only(left: 8.w, bottom: 4.h),
                    child: Text(
                      message.senderNickname!,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontFamily: 'OtsutomeFont',
                        color: const Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                // 訊息框和時間
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 時間（左側，僅當是自己的訊息時）
                    if (isMe) ...[
                      Padding(
                        padding: EdgeInsets.only(right: 6.w, bottom: 2.h),
                        child: _buildTimeText(message),
                      ),
                    ],

                    // 訊息框（文字訊息）或圖片（圖片訊息）
                    Flexible(
                      child:
                          message.isText
                              ? Container(
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
                                child: _buildTextContent(message),
                              )
                              : _buildImageMessage(message),
                    ),

                    // 時間（右側，僅當是他人的訊息時）
                    if (!isMe) ...[
                      Padding(
                        padding: EdgeInsets.only(left: 6.w, bottom: 2.h),
                        child: _buildTimeText(message),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 自己訊息：不顯示頭像，但保留空間
          if (isMe) SizedBox(width: 10.w),
        ],
      ),
    );
  }

  Widget _buildAvatar(ChatMessage message) {
    return Container(
      width: 50.w,
      height: 50.w,
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

    // 如果沒有頭像或不是自訂頭像，使用固定的預設頭像
    if (avatarPath == null ||
        avatarPath.isEmpty ||
        !avatarPath.startsWith('avatars/')) {
      final fixedIndex = _fixedAvatars[message.userId] ?? 1;
      return Container(
        color: Colors.white,
        child: Image.asset(
          _getFixedDefaultAvatar(gender, fixedIndex),
          fit: BoxFit.cover,
        ),
      );
    }

    // 如果是 R2 上的自訂頭像
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
                          width: 20.w,
                          height: 20.h,
                          color: const Color(0xFF23456B),
                        ),
                      ),
                    ),
                errorWidget: (context, url, error) {
                  final fixedIndex = _fixedAvatars[message.userId] ?? 1;
                  return Container(
                    color: Colors.white,
                    child: Image.asset(
                      _getFixedDefaultAvatar(gender, fixedIndex),
                      fit: BoxFit.cover,
                    ),
                  );
                },
              );
            }

            final fixedIndex = _fixedAvatars[message.userId] ?? 1;
            return Container(
              color: Colors.white,
              child: Image.asset(
                _getFixedDefaultAvatar(gender, fixedIndex),
                fit: BoxFit.cover,
              ),
            );
          },
        );
      },
    );
  }

  String _getFixedDefaultAvatar(String? gender, int index) {
    // index 範圍 1-6
    final safeIndex = ((index - 1) % 6) + 1;

    if (gender == 'male') {
      return 'assets/images/avatar/no_bg/male_$safeIndex.webp';
    } else if (gender == 'female') {
      return 'assets/images/avatar/no_bg/female_$safeIndex.webp';
    } else {
      // 未知性別時，偶數使用男性，奇數使用女性
      final isMale = safeIndex % 2 == 0;
      return isMale
          ? 'assets/images/avatar/no_bg/male_$safeIndex.webp'
          : 'assets/images/avatar/no_bg/female_$safeIndex.webp';
    }
  }

  Widget _buildTextContent(ChatMessage message) {
    // 只顯示訊息內容，時間和名字已在外部顯示
    return Text(
      message.content ?? '',
      style: TextStyle(
        fontSize: 16.sp,
        fontFamily: 'OtsutomeFont',
        color: const Color(0xFF23456B),
      ),
    );
  }

  Widget _buildTimeText(ChatMessage message) {
    // 如果是傳送中的訊息，顯示狀態
    if (message.sendStatus == 'pending') {
      return Text(
        '傳送中...',
        style: TextStyle(
          fontSize: 11.sp,
          fontFamily: 'OtsutomeFont',
          color: const Color(0xFF999999),
        ),
      );
    }

    // 使用 12 小時制顯示時間
    final hour = message.createdAt.hour;
    final minute = message.createdAt.minute;
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';

    return Text(
      '$hour12:${minute.toString().padLeft(2, '0')} $period',
      style: TextStyle(
        fontSize: 11.sp,
        fontFamily: 'OtsutomeFont',
        color: const Color(0xFF999999),
      ),
    );
  }

  Widget _buildImageMessage(ChatMessage message) {
    // 如果是傳送中的圖片，顯示載入狀態
    if (message.sendStatus == 'pending') {
      return Container(
        width: 200.w,
        height: 200.w,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingImage(
                width: 40.w,
                height: 40.h,
                color: const Color(0xFF23456B),
              ),
              SizedBox(height: 10.h),
              Text(
                '上傳中...',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (message.imagePath == null) {
      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: const Text('[圖片載入失敗]'),
      );
    }

    // 如果有快取的圖片尺寸，使用快取的尺寸
    if (message.imageWidth != null && message.imageHeight != null) {
      final imageWidth = message.imageWidth!;
      final imageHeight = message.imageHeight!;
      final aspectRatio = imageWidth / imageHeight;

      // 計算顯示尺寸（最大寬度200.w，最大高度300.h）
      final maxWidth = 200.w;
      final maxHeight = 300.h;
      double displayWidth = min(maxWidth, imageWidth.toDouble());
      double displayHeight = displayWidth / aspectRatio;

      // 如果高度超過最大高度，則按高度縮放
      if (displayHeight > maxHeight) {
        displayHeight = maxHeight;
        displayWidth = displayHeight * aspectRatio;
      }

      return _buildImageWithSize(message, displayWidth, displayHeight);
    }

    // 如果沒有尺寸資訊，使用自適應方式
    return _buildImageWithAutoSize(message);
  }

  /// 使用已知尺寸建構圖片訊息
  Widget _buildImageWithSize(
    ChatMessage message,
    double displayWidth,
    double displayHeight,
  ) {
    return FutureBuilder<String?>(
      future: _chatService.getImageUrl(message.imagePath!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: displayWidth,
            height: displayHeight,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
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
          final imageUrl = snapshot.data!;

          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ImageViewer(imageUrl: imageUrl),
                  fullscreenDialog: true,
                ),
              );
            },
            child: Hero(
              tag: message.id,
              child: Container(
                width: displayWidth,
                height: displayHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: Offset(0, 2.h),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    cacheManager: ImageCacheService().getCacheManager(
                      CacheType.chat,
                    ),
                    cacheKey: message.imagePath,
                    fit: BoxFit.cover, // 使用 cover 填滿容器
                    width: displayWidth,
                    height: displayHeight,
                    placeholder:
                        (context, url) => Container(
                          width: displayWidth,
                          height: displayHeight,
                          color: Colors.grey[200],
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
                          width: displayWidth,
                          height: displayHeight,
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        ),
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          width: displayWidth,
          height: displayHeight,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: const Icon(Icons.error),
        );
      },
    );
  }

  /// 自動調整尺寸的圖片訊息（用於沒有尺寸資訊的情況）
  Widget _buildImageWithAutoSize(ChatMessage message) {
    // 為了避免圖片載入時改變高度導致 ListView 跳動
    // 使用固定的初始容器，載入完成後也保持固定大小
    // 使用較大的預設尺寸，載入後會根據實際比例調整
    final displayWidth = 200.w;
    final displayHeight = 200.w; // 初始使用正方形，載入後會調整

    return FutureBuilder<String?>(
      future: _chatService.getImageUrl(message.imagePath!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: displayWidth,
            height: displayHeight,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
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
          final imageUrl = snapshot.data!;

          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ImageViewer(imageUrl: imageUrl),
                  fullscreenDialog: true,
                ),
              );
            },
            child: Hero(
              tag: message.id,
              child: Container(
                width: displayWidth,
                height: displayHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: Offset(0, 2.h),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    cacheManager: ImageCacheService().getCacheManager(
                      CacheType.chat,
                    ),
                    cacheKey: message.imagePath,
                    fit: BoxFit.cover, // 使用 cover 填滿容器
                    width: displayWidth,
                    height: displayHeight,
                    placeholder:
                        (context, url) => Container(
                          width: displayWidth,
                          height: displayHeight,
                          color: Colors.grey[200],
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
                          width: displayWidth,
                          height: displayHeight,
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        ),
                    imageBuilder: (context, imageProvider) {
                      // 當圖片載入完成後，儲存圖片尺寸以便下次使用
                      _saveImageSize(message, imageProvider);
                      return Image(
                        image: imageProvider,
                        fit: BoxFit.cover, // 使用 cover 填滿容器
                        width: displayWidth,
                        height: displayHeight,
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          width: displayWidth,
          height: displayHeight,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: const Icon(Icons.error),
        );
      },
    );
  }

  Future<void> _saveImageSize(
    ChatMessage message,
    ImageProvider imageProvider,
  ) async {
    try {
      final completer = Completer<ImageInfo>();
      final stream = imageProvider.resolve(const ImageConfiguration());
      late ImageStreamListener listener;

      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) {
            completer.complete(info);
            stream.removeListener(listener);
          }
        },
        onError: (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error);
            stream.removeListener(listener);
          }
        },
      );

      stream.addListener(listener);
      final imageInfo = await completer.future;

      final width = imageInfo.image.width;
      final height = imageInfo.image.height;

      // 儲存到資料庫（下次載入時會使用正確的尺寸）
      await _chatService.saveImageDimensions(message.id, width, height);
      debugPrint('已儲存圖片尺寸到本地資料庫: $width x $height');
    } catch (e) {
      debugPrint('儲存圖片尺寸失敗: $e');
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 15.w,
        right: 15.w,
        top: 10.h,
        bottom: max(10.h, MediaQuery.of(context).padding.bottom),
      ),
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
      onTapDown:
          _isSending
              ? null
              : (_) {
                setState(() {});
              },
      onTapUp:
          _isSending
              ? null
              : (_) {
                setState(() {});
                _sendImageMessage();
              },
      onTapCancel:
          _isSending
              ? null
              : () {
                setState(() {});
              },
      child: AnimatedScale(
        scale: _isSending ? 1.0 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: _isSending ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 100),
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
    bool _isPressed = false;

    return StatefulBuilder(
      builder: (context, setButtonState) {
        return GestureDetector(
          onTapDown: (_) {
            if (!_isSending) {
              setButtonState(() {
                _isPressed = true;
              });
            }
          },
          onTapUp: (_) {
            if (!_isSending) {
              setButtonState(() {
                _isPressed = false;
              });
              _sendTextMessage();
            }
          },
          onTapCancel: () {
            if (!_isSending) {
              setButtonState(() {
                _isPressed = false;
              });
            }
          },
          child: AnimatedOpacity(
            opacity: _isSending ? 0.5 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              transform: Matrix4.translationValues(0, _isPressed ? 2.h : 0, 0),
              child: SizedBox(
                width: 35.w,
                height: 35.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 底部陰影（按下時隱藏）
                    if (!_isPressed && !_isSending)
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
            ),
          ),
        );
      },
    );
  }
}
