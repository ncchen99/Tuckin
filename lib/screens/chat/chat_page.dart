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
import 'dart:typed_data';

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
  final FocusNode _messageFocusNode = FocusNode();

  String? _currentUserId;
  List<ChatMessage> _messages = [];
  bool _isLoading = true; // 新增：訊息載入狀態
  bool _hasText = false; // 追蹤輸入框是否有內容
  final Map<String, int> _fixedAvatars = {}; // 儲存固定頭像索引
  final Map<String, String?> _avatarUrlCache = {}; // 儲存頭像 URL 緩存
  final Map<String, bool> _avatarUrlLoading = {}; // 追蹤正在加載的頭像 URL

  // 儲存正在發送的圖片本地資訊（tempId -> {localPath, imageBytes, width, height}）
  final Map<String, Map<String, dynamic>> _pendingImageData = {};

  // 儲存聊天圖片 URL 緩存（imagePath -> url）
  final Map<String, String?> _chatImageUrlCache = {};
  final Map<String, bool> _chatImageUrlLoading = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _subscribeToMessages();

    // 註冊生命週期監聽
    WidgetsBinding.instance.addObserver(this);

    // 監聽輸入框內容變化
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (_hasText != hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
  }

  @override
  void dispose() {
    _chatService.unsubscribeFromMessages(widget.diningEventId);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
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

        // 收集需要處理的用戶
        final usersNeedingFixedAvatar = <String>[];
        final usersNeedingAvatarUrl = <String>[];

        for (final message in sortedMessages) {
          final avatarPath = message.senderAvatarPath;
          final hasCustomAvatar =
              avatarPath != null &&
              avatarPath.isNotEmpty &&
              avatarPath.startsWith('avatars/');

          if (!hasCustomAvatar && !_fixedAvatars.containsKey(message.userId)) {
            usersNeedingFixedAvatar.add(message.userId);
          }

          // 收集需要預取頭像 URL 的用戶（有自訂頭像且尚未緩存 URL）
          if (hasCustomAvatar && !_avatarUrlCache.containsKey(message.userId)) {
            usersNeedingAvatarUrl.add(message.userId);
          }
        }

        // 為沒有自訂頭像的用戶載入固定頭像索引
        bool needFixedAvatarUpdate = false;
        for (final userId in usersNeedingFixedAvatar) {
          final message = sortedMessages.firstWhere((m) => m.userId == userId);
          final index = await _chatService.getFixedAvatarIndex(
            userId,
            widget.diningEventId,
            message.senderGender,
          );
          _fixedAvatars[userId] = index;
          needFixedAvatarUpdate = true;
        }

        // 批量預取自訂頭像的 URL
        if (usersNeedingAvatarUrl.isNotEmpty) {
          final uniqueUserIds = usersNeedingAvatarUrl.toSet().toList();
          final urls = await UserService().prefetchAvatarUrls(uniqueUserIds);
          for (final entry in urls.entries) {
            _avatarUrlCache[entry.key] = entry.value;
          }
        }

        // 預取聊天圖片 URL（只預取尚未緩存的）
        final imagePathsToFetch = <String>[];
        for (final message in sortedMessages) {
          if (message.isImage &&
              message.imagePath != null &&
              !_chatImageUrlCache.containsKey(message.imagePath)) {
            imagePathsToFetch.add(message.imagePath!);
          }
        }

        // 異步預取圖片 URL（不阻塞 UI）
        if (imagePathsToFetch.isNotEmpty) {
          _prefetchChatImageUrls(imagePathsToFetch);
        }

        // 檢查是否需要更新 UI（比較圖片相關字段）
        final reversedMessages = sortedMessages.reversed.toList();
        final needsUpdate = _shouldUpdateMessages(_messages, reversedMessages);

        if (needsUpdate ||
            needFixedAvatarUpdate ||
            usersNeedingAvatarUrl.isNotEmpty ||
            _isLoading) {
          setState(() {
            // 訊息已載入完成
            _isLoading = false;

            // 反轉訊息順序：最新訊息在前 [新, 中, 舊]
            // 這樣配合 reverse: true，最新訊息會顯示在底部

            // 保留當前的 pending 狀態訊息（樂觀更新）
            final pendingMessages =
                _messages.where((m) => m.sendStatus == 'pending').toList();

            // 匹配 pending 訊息與遠端訊息，轉移本地圖片資訊
            final pendingToRemove = <String>{};
            for (final pendingMessage in pendingMessages) {
              for (final remoteMessage in reversedMessages) {
                // 如果是同一個用戶，且時間差在 30 秒內，且類型相同
                if (remoteMessage.userId == pendingMessage.userId &&
                    remoteMessage.messageType == pendingMessage.messageType &&
                    remoteMessage.createdAt
                            .difference(pendingMessage.createdAt)
                            .abs()
                            .inSeconds <
                        30) {
                  // 如果是文字訊息，比較內容
                  if (remoteMessage.messageType == 'text' &&
                      remoteMessage.content == pendingMessage.content) {
                    pendingToRemove.add(pendingMessage.id);
                    break;
                  }
                  // 如果是圖片訊息，比較尺寸
                  if (remoteMessage.messageType == 'image' &&
                      remoteMessage.imageWidth == pendingMessage.imageWidth &&
                      remoteMessage.imageHeight == pendingMessage.imageHeight) {
                    pendingToRemove.add(pendingMessage.id);
                    // 將本地圖片資訊轉移到新的 messageId（用於 placeholder）
                    if (_pendingImageData.containsKey(pendingMessage.id)) {
                      _pendingImageData[remoteMessage.id] =
                          _pendingImageData[pendingMessage.id]!;
                      _pendingImageData.remove(pendingMessage.id);
                    }
                    break;
                  }
                }
              }
            }

            // 過濾掉已被遠端訊息替代的 pending 訊息
            final remainingPendingMessages =
                pendingMessages
                    .where((m) => !pendingToRemove.contains(m.id))
                    .toList();

            _messages = [...remainingPendingMessages, ...reversedMessages];
          });
          // 自動滾動到最新訊息
          _scrollToBottom();
        }
      }
    });
  }

  /// 檢查是否需要更新訊息列表
  /// 如果圖片相關字段（imagePath, senderAvatarPath）沒有變化，則不需要更新
  bool _shouldUpdateMessages(
    List<ChatMessage> oldMessages,
    List<ChatMessage> newMessages,
  ) {
    // 如果訊息數量不同，需要更新
    if (oldMessages.length != newMessages.length) {
      return true;
    }

    // 建立舊訊息的 Map 以便快速查找
    final oldMessagesMap = {for (var m in oldMessages) m.id: m};

    // 比較每個訊息
    for (final newMessage in newMessages) {
      final oldMessage = oldMessagesMap[newMessage.id];

      // 如果訊息不存在於舊列表中，需要更新
      if (oldMessage == null) {
        return true;
      }

      // 比較圖片相關字段
      if (newMessage.imagePath != oldMessage.imagePath) {
        return true;
      }

      if (newMessage.senderAvatarPath != oldMessage.senderAvatarPath) {
        return true;
      }

      // 比較其他可能影響顯示的字段
      if (newMessage.content != oldMessage.content) {
        return true;
      }

      if (newMessage.sendStatus != oldMessage.sendStatus) {
        return true;
      }

      if (newMessage.senderNickname != oldMessage.senderNickname) {
        return true;
      }

      // 比較圖片尺寸（如果從 null 變成有值，需要更新）
      if ((newMessage.imageWidth != oldMessage.imageWidth) ||
          (newMessage.imageHeight != oldMessage.imageHeight)) {
        // 只有在從 null 變成有值時才需要更新（避免重複載入）
        if (oldMessage.imageWidth == null && newMessage.imageWidth != null) {
          return true;
        }
        if (oldMessage.imageHeight == null && newMessage.imageHeight != null) {
          return true;
        }
      }
    }

    // 所有訊息都沒有變化，不需要更新
    return false;
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

  bool _isSameDay(DateTime date1, DateTime date2) {
    final local1 = date1.toLocal();
    final local2 = date2.toLocal();
    return local1.year == local2.year &&
        local1.month == local2.month &&
        local1.day == local2.day;
  }

  /// 判斷兩條訊息是否屬於同一個群組（同一用戶 + 2分鐘內 + 都是文字訊息）
  bool _isSameGroup(ChatMessage message1, ChatMessage message2) {
    // 不同用戶不算同一群組
    if (message1.userId != message2.userId) return false;

    // 如果其中一條是圖片訊息，不算同一群組（只有文字訊息才會群組處理）
    if (message1.isImage || message2.isImage) return false;

    // 時間差超過 2 分鐘不算同一群組
    final timeDiff = message1.createdAt.difference(message2.createdAt).abs();
    if (timeDiff.inMinutes >= 2) return false;

    return true;
  }

  /// 獲取訊息在群組中的位置
  /// 返回 (isFirstInGroup, isLastInGroup)
  (bool, bool) _getMessageGroupPosition(int index) {
    final message = _messages[index];

    // 如果是圖片訊息，不參與群組處理，直接返回單獨訊息
    if (message.isImage) {
      return (true, true);
    }

    // 因為 _messages 是 [新, 中, 舊]，reverse: true 顯示
    // index 越小 = 時間越新，index 越大 = 時間越舊

    // 檢查是否是群組中的第一條（時間最早的那條）
    // 往後看（index + 1 = 更舊的訊息）
    bool isFirstInGroup = true;
    if (index < _messages.length - 1) {
      final olderMessage = _messages[index + 1];
      if (_isSameGroup(message, olderMessage) &&
          _isSameDay(message.createdAt, olderMessage.createdAt)) {
        isFirstInGroup = false;
      }
    }

    // 檢查是否是群組中的最後一條（時間最新的那條）
    // 往前看（index - 1 = 更新的訊息）
    bool isLastInGroup = true;
    if (index > 0) {
      final newerMessage = _messages[index - 1];
      if (_isSameGroup(message, newerMessage) &&
          _isSameDay(message.createdAt, newerMessage.createdAt)) {
        isLastInGroup = false;
      }
    }

    return (isFirstInGroup, isLastInGroup);
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    if (localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day) {
      return '今天';
    }
    return '${localDate.month.toString()} 月 ${localDate.day.toString()} 日';
  }

  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            _formatDate(date),
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontFamily: 'OtsutomeFont',
            ),
          ),
        ),
      ),
    );
  }

  /// 獲取所有圖片訊息（按時間順序，從舊到新）
  List<ChatMessage> _getImageMessages() {
    final imageMessages =
        _messages
            .where((message) => message.isImage && message.imagePath != null)
            .toList();
    // 按時間升序排序（從舊到新），確保滑動順序正確
    imageMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return imageMessages;
  }

  /// 打開圖片查看器
  void _openImageViewer(ChatMessage message) {
    final imageMessages = _getImageMessages();
    if (imageMessages.isEmpty) return;

    // 找到當前圖片在列表中的索引
    final index = imageMessages.indexWhere((m) => m.id == message.id);
    if (index == -1) return;

    // 暫時禁止輸入框獲取焦點，防止鍵盤在導航過程中彈出
    _messageFocusNode.canRequestFocus = false;
    // 確保當前已經失去焦點
    FocusScope.of(context).unfocus();

    Navigator.of(context)
        .push(
          PageRouteBuilder(
            opaque: false, // 設置為透明路由
            pageBuilder:
                (context, animation, secondaryAnimation) => ImageViewer(
                  imageMessages: imageMessages,
                  initialIndex: index,
                ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        )
        .then((_) {
          // 恢復輸入框可獲取焦點的能力
          // 使用 addPostFrameCallback 確保在下一幀才恢復，避免路由動畫結束時的自動焦點恢復機制觸發
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _messageFocusNode.canRequestFocus = true;
            }
          });
        });
  }

  Future<void> _sendTextMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    // 確保用戶 ID 已載入
    if (_currentUserId == null) {
      await _loadCurrentUser();
      if (_currentUserId == null) {
        _showErrorSnackBar('用戶資訊載入失敗');
        return;
      }
    }

    // 清空輸入框（立即清空，不等待發送完成）
    _messageController.clear();

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
      // 將新訊息插入到列表開頭（因為列表是 [新, 中, 舊]）
      _messages = [optimisticMessage, ..._messages];
    });
    _scrollToBottom();

    // 異步發送訊息（不阻塞 UI）
    final success = await _chatService.sendTextMessage(
      widget.diningEventId,
      content,
    );

    if (mounted && !success) {
      // 發送失敗，移除樂觀訊息並顯示錯誤提示
      setState(() {
        _messages = _messages.where((m) => m.id != tempId).toList();
      });

      _showErrorSnackBar('發送訊息失敗');
    }
    // 成功的話，Realtime 會自動更新訊息列表
  }

  /// 顯示錯誤提示框
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB33D1C), // 深橘色背景
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'OtsutomeFont',
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _sendImageMessage() async {
    // 1. 先選擇/拍攝圖片（這步會打開相機，不阻塞其他操作）
    final imageData = await _chatService.pickImageFromCamera();

    // 如果用戶取消或失敗，直接返回
    if (imageData == null) return;

    // 確保用戶 ID 已載入
    if (_currentUserId == null) {
      await _loadCurrentUser();
      if (_currentUserId == null) {
        _showErrorSnackBar('用戶資訊載入失敗');
        return;
      }
    }

    final localPath = imageData['localPath'] as String;
    final imageBytes = imageData['imageBytes'] as Uint8List;
    final imageWidth = imageData['width'] as int;
    final imageHeight = imageData['height'] as int;

    // 2. 樂觀UI更新：立即顯示本地圖片預覽（傳送中狀態）
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // 儲存本地圖片資訊以便顯示預覽
    _pendingImageData[tempId] = {
      'localPath': localPath,
      'imageBytes': imageBytes,
      'width': imageWidth,
      'height': imageHeight,
    };

    final optimisticMessage = ChatMessage(
      id: tempId,
      diningEventId: widget.diningEventId,
      userId: _currentUserId!,
      messageType: 'image',
      createdAt: DateTime.now(),
      sendStatus: 'pending',
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );

    setState(() {
      // 將新訊息插入到列表開頭（因為列表是 [新, 中, 舊]）
      _messages = [optimisticMessage, ..._messages];
    });
    _scrollToBottom();

    // 3. 異步上傳圖片（不阻塞 UI，可以繼續發送其他訊息）
    final success = await _chatService.uploadAndSendImage(
      widget.diningEventId,
      imageBytes,
      imageWidth,
      imageHeight,
    );

    if (mounted) {
      if (!success) {
        // 發送失敗，移除樂觀訊息和本地圖片資訊
        setState(() {
          _messages = _messages.where((m) => m.id != tempId).toList();
        });
        _pendingImageData.remove(tempId);

        _showErrorSnackBar('發送圖片失敗');
      }
      // 成功後不要立即移除 _pendingImageData
      // 讓圖片顯示元件在網路圖片載入完成後再清理
      // 這樣可以避免「傳送中預覽消失 -> 等待 -> 網路圖片出現」的空白期
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用 resizeToAvoidBottomInset: true 讓鍵盤出現時推動內容
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        // 點擊空白區域時收起鍵盤
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        // 使用 translucent 確保不會攔截子組件的點擊事件
        behavior: HitTestBehavior.translucent,
        child: Container(
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
                Expanded(child: _buildMessageList()),

                // 輸入區域 - 固定在底部
                _buildInputArea(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 20.h,
        bottom: 12.h,
      ),
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
              child: Padding(
                padding: EdgeInsets.only(top: 6.h), // 增加上方 padding
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
          ),

          // 右側佔位（保持對稱）
          SizedBox(width: 35.w),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    // 載入中狀態
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingImage(
              width: 40.w,
              height: 40.h,
              color: const Color(0xFF23456B),
            ),
            SizedBox(height: 12.h),
            Text(
              '訊息載入中...',
              style: TextStyle(
                fontSize: 16.sp,
                fontFamily: 'OtsutomeFont',
                color: const Color(0xFF666666),
              ),
            ),
          ],
        ),
      );
    }

    // 載入完成但沒有訊息
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

        // 獲取訊息在群組中的位置
        final (isFirstInGroup, isLastInGroup) = _getMessageGroupPosition(index);

        final messageItem = _buildMessageItem(
          message,
          isMe,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
          key: ValueKey(message.id),
        );

        // 檢查是否需要顯示日期標籤
        // 因為是 reverse: true，index 越大代表時間越早
        // 如果是最後一個項目（最早的訊息），一定顯示日期
        // 否則，如果當前訊息（較新）與下一個訊息（較舊）不在同一天，則在它們中間顯示日期
        bool showDateHeader = false;
        if (index == _messages.length - 1) {
          showDateHeader = true;
        } else {
          final nextMessage = _messages[index + 1];
          if (!_isSameDay(message.createdAt, nextMessage.createdAt)) {
            showDateHeader = true;
          }
        }

        if (showDateHeader) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 因為是 Column，順序是從上到下
              // 我們希望日期在訊息上方
              _buildDateHeader(message.createdAt),
              messageItem,
            ],
          );
        }

        return messageItem;
      },
    );
  }

  Widget _buildMessageItem(
    ChatMessage message,
    bool isMe, {
    Key? key,
    bool isFirstInGroup = true,
    bool isLastInGroup = true,
  }) {
    // 根據群組位置調整間距
    // 我們希望群組內訊息之間的總間距固定且較小（例如 2.h）
    // 所以每條訊息在群組內側的 padding 設為 1.h
    final double innerPadding = 2.h;

    // 群組邊緣的額外間距
    final double groupEdgePadding = 10.h;

    final topPadding = isFirstInGroup ? groupEdgePadding : innerPadding;
    final bottomPadding = isLastInGroup ? groupEdgePadding : innerPadding;

    // 計算訊息框的圓角
    // 根據群組位置調整圓角，讓連續訊息看起來更像一個整體
    final borderRadius = _getMessageBorderRadius(
      isMe,
      isFirstInGroup,
      isLastInGroup,
    );

    return Padding(
      key: key,
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 他人訊息：左側頭像（只在群組最後一條顯示）
          if (!isMe) ...[
            if (isLastInGroup)
              _buildAvatar(message)
            else
              SizedBox(width: 40.w), // 佔位，保持對齊
            SizedBox(width: 10.w),
          ],

          // 訊息內容區域（包含名字、訊息框、時間）
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 發送者名字（只在群組第一條顯示）
                if (!isMe &&
                    message.senderNickname != null &&
                    isFirstInGroup) ...[
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
                    // 時間（左側，僅當是自己的訊息且是群組最後一條時顯示）
                    if (isMe && isLastInGroup) ...[
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
                                  borderRadius: borderRadius,
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
                              : _buildImageMessage(
                                message,
                                borderRadius: borderRadius,
                              ),
                    ),

                    // 時間（右側，僅當是他人的訊息且是群組最後一條時顯示）
                    if (!isMe && isLastInGroup) ...[
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

          // // 自己訊息：不顯示頭像，但保留空間
          // if (isMe) SizedBox(width: 10.w),
        ],
      ),
    );
  }

  /// 根據訊息在群組中的位置計算圓角
  BorderRadius _getMessageBorderRadius(
    bool isMe,
    bool isFirstInGroup,
    bool isLastInGroup,
  ) {
    final double normalRadius = 12.r;
    final double smallRadius = 4.r;

    if (isFirstInGroup && isLastInGroup) {
      // 單獨一條訊息，四角都是正常圓角
      return BorderRadius.circular(normalRadius);
    }

    if (isMe) {
      // 自己的訊息在右側
      if (isFirstInGroup) {
        // 群組第一條（視覺上最上面）：右下角小圓角
        return BorderRadius.only(
          topLeft: Radius.circular(normalRadius),
          topRight: Radius.circular(normalRadius),
          bottomLeft: Radius.circular(normalRadius),
          bottomRight: Radius.circular(smallRadius),
        );
      } else if (isLastInGroup) {
        // 群組最後一條（視覺上最下面）：右上角小圓角
        return BorderRadius.only(
          topLeft: Radius.circular(normalRadius),
          topRight: Radius.circular(smallRadius),
          bottomLeft: Radius.circular(normalRadius),
          bottomRight: Radius.circular(normalRadius),
        );
      } else {
        // 群組中間：右側兩個角都是小圓角
        return BorderRadius.only(
          topLeft: Radius.circular(normalRadius),
          topRight: Radius.circular(smallRadius),
          bottomLeft: Radius.circular(normalRadius),
          bottomRight: Radius.circular(smallRadius),
        );
      }
    } else {
      // 他人的訊息在左側
      if (isFirstInGroup) {
        // 群組第一條（視覺上最上面）：左下角小圓角
        return BorderRadius.only(
          topLeft: Radius.circular(normalRadius),
          topRight: Radius.circular(normalRadius),
          bottomLeft: Radius.circular(smallRadius),
          bottomRight: Radius.circular(normalRadius),
        );
      } else if (isLastInGroup) {
        // 群組最後一條（視覺上最下面）：左上角小圓角
        return BorderRadius.only(
          topLeft: Radius.circular(smallRadius),
          topRight: Radius.circular(normalRadius),
          bottomLeft: Radius.circular(normalRadius),
          bottomRight: Radius.circular(normalRadius),
        );
      } else {
        // 群組中間：左側兩個角都是小圓角
        return BorderRadius.only(
          topLeft: Radius.circular(smallRadius),
          topRight: Radius.circular(normalRadius),
          bottomLeft: Radius.circular(smallRadius),
          bottomRight: Radius.circular(normalRadius),
        );
      }
    }
  }

  Widget _buildAvatar(ChatMessage message) {
    // 使用穩定的 key，基於 userId 和 avatarPath，避免不必要的重建
    final avatarKey =
        'avatar_${message.userId}_${message.senderAvatarPath ?? 'default'}';
    return Container(
      key: ValueKey(avatarKey),
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: ClipOval(child: _buildAvatarImage(message)),
    );
  }

  Widget _buildAvatarImage(ChatMessage message) {
    final avatarPath = message.senderAvatarPath;
    final gender = message.senderGender;
    final userId = message.userId;

    // 如果沒有頭像或不是自訂頭像，使用固定的預設頭像
    if (avatarPath == null ||
        avatarPath.isEmpty ||
        !avatarPath.startsWith('avatars/')) {
      final fixedIndex = _fixedAvatars[userId] ?? 1;
      // 使用穩定的 key，避免重複載入相同的預設頭像
      return Container(
        key: ValueKey('default_avatar_${userId}_$fixedIndex'),
        color: Colors.white,
        child: Image.asset(
          _getFixedDefaultAvatar(gender, fixedIndex),
          fit: BoxFit.cover,
          cacheWidth: 100, // 限制緩存尺寸，節省記憶體
        ),
      );
    }

    // 如果是 R2 上的自訂頭像
    final avatarCacheKey = 'avatar_${userId}_$avatarPath';

    // 檢查內存中是否有緩存的 URL
    final cachedUrl = _avatarUrlCache[userId];

    // 如果已經有 URL，直接使用 CachedNetworkImage
    if (cachedUrl != null) {
      return _buildCachedAvatarImage(
        key: ValueKey(avatarCacheKey),
        imageUrl: cachedUrl,
        avatarPath: avatarPath,
        gender: gender,
        userId: userId,
      );
    }

    // 首先嘗試從本地快取獲取
    return FutureBuilder<File?>(
      key: ValueKey(avatarCacheKey),
      future: ImageCacheService().getCachedImageByKey(
        avatarPath,
        CacheType.avatar,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null &&
            snapshot.data!.existsSync()) {
          // 本地緩存存在，直接使用 Image.file，不需要請求 URL
          return Image.file(
            snapshot.data!,
            fit: BoxFit.cover,
            cacheWidth: 100, // 限制緩存尺寸，節省記憶體
          );
        }

        // 本地快取不存在，需要從網路載入
        // 異步獲取 URL 並緩存（避免在 build 中重複請求）
        _loadAvatarUrlIfNeeded(userId, avatarPath, gender);

        // 顯示載入中的預設頭像
        final fixedIndex = _fixedAvatars[userId] ?? 1;
        return Container(
          color: Colors.white,
          child: Stack(
            children: [
              Image.asset(
                _getFixedDefaultAvatar(gender, fixedIndex),
                fit: BoxFit.cover,
                cacheWidth: 100,
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.5),
                  child: Center(
                    child: LoadingImage(
                      width: 15.w,
                      height: 15.h,
                      color: const Color(0xFF23456B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 批量預取聊天圖片 URL
  void _prefetchChatImageUrls(List<String> imagePaths) {
    for (final imagePath in imagePaths) {
      _loadChatImageUrlIfNeeded(imagePath);
    }
  }

  /// 異步載入聊天圖片 URL 並緩存（避免重複請求）
  void _loadChatImageUrlIfNeeded(String imagePath) {
    // 如果已經在加載中或已有緩存，跳過
    if (_chatImageUrlLoading[imagePath] == true ||
        _chatImageUrlCache.containsKey(imagePath)) {
      return;
    }

    // 標記為加載中
    _chatImageUrlLoading[imagePath] = true;

    // 異步獲取 URL
    _chatService
        .getImageUrl(imagePath)
        .then((url) {
          if (mounted) {
            setState(() {
              _chatImageUrlCache[imagePath] = url;
              _chatImageUrlLoading[imagePath] = false;
            });
          }
        })
        .catchError((e) {
          debugPrint('獲取圖片 URL 失敗: $e');
          if (mounted) {
            setState(() {
              _chatImageUrlCache[imagePath] = null;
              _chatImageUrlLoading[imagePath] = false;
            });
          }
        });
  }

  /// 異步載入頭像 URL 並緩存（避免重複請求）
  void _loadAvatarUrlIfNeeded(
    String userId,
    String avatarPath,
    String? gender,
  ) {
    // 如果已經在加載中或已有緩存，跳過
    if (_avatarUrlLoading[userId] == true ||
        _avatarUrlCache.containsKey(userId)) {
      return;
    }

    // 標記為加載中
    _avatarUrlLoading[userId] = true;

    // 異步獲取 URL
    UserService()
        .getOtherUserAvatarUrl(userId)
        .then((url) {
          if (mounted) {
            setState(() {
              _avatarUrlCache[userId] = url;
              _avatarUrlLoading[userId] = false;
            });
          }
        })
        .catchError((e) {
          debugPrint('獲取頭像 URL 失敗: $e');
          if (mounted) {
            setState(() {
              _avatarUrlCache[userId] = null;
              _avatarUrlLoading[userId] = false;
            });
          }
        });
  }

  /// 使用已緩存的 URL 構建頭像圖片
  Widget _buildCachedAvatarImage({
    required Key key,
    required String imageUrl,
    required String avatarPath,
    required String? gender,
    required String userId,
  }) {
    return CachedNetworkImage(
      key: key,
      imageUrl: imageUrl,
      cacheManager: ImageCacheService().getCacheManager(CacheType.avatar),
      cacheKey: avatarPath, // 使用 avatarPath 作為緩存 key
      fit: BoxFit.cover,
      memCacheWidth: 100, // 限制記憶體緩存尺寸
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
        final fixedIndex = _fixedAvatars[userId] ?? 1;
        return Container(
          color: Colors.white,
          child: Image.asset(
            _getFixedDefaultAvatar(gender, fixedIndex),
            fit: BoxFit.cover,
            cacheWidth: 100,
          ),
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

    // 使用 12 小時制顯示時間，並轉換為本地時間
    final localTime = message.createdAt.toLocal();
    final hour = localTime.hour;
    final minute = localTime.minute;
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

  Widget _buildImageMessage(ChatMessage message, {BorderRadius? borderRadius}) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(12.r);

    // 如果是傳送中的圖片，顯示本地圖片預覽
    if (message.sendStatus == 'pending') {
      return _buildPendingImageMessage(message, effectiveBorderRadius);
    }

    if (message.imagePath == null) {
      return Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: effectiveBorderRadius,
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

      return _buildImageWithSize(
        message,
        displayWidth,
        displayHeight,
        borderRadius: effectiveBorderRadius,
      );
    }

    // 如果沒有尺寸資訊，使用自適應方式
    return _buildImageWithAutoSize(
      message,
      borderRadius: effectiveBorderRadius,
    );
  }

  /// 建構傳送中的圖片訊息（顯示本地預覽）
  Widget _buildPendingImageMessage(
    ChatMessage message,
    BorderRadius borderRadius,
  ) {
    final pendingData = _pendingImageData[message.id];

    // 計算顯示尺寸
    final imageWidth = message.imageWidth ?? 200;
    final imageHeight = message.imageHeight ?? 200;
    final aspectRatio = imageWidth / imageHeight;

    final maxWidth = 200.w;
    final maxHeight = 300.h;
    double displayWidth = min(maxWidth, imageWidth.toDouble());
    double displayHeight = displayWidth / aspectRatio;

    if (displayHeight > maxHeight) {
      displayHeight = maxHeight;
      displayWidth = displayHeight * aspectRatio;
    }

    // 如果有本地圖片資訊，顯示本地預覽
    if (pendingData != null) {
      final localPath = pendingData['localPath'] as String?;
      final imageBytes = pendingData['imageBytes'] as Uint8List?;

      Widget imageWidget;

      // 優先使用 imageBytes，因為已經壓縮過
      if (imageBytes != null) {
        imageWidget = Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: displayWidth,
          height: displayHeight,
        );
      } else if (localPath != null) {
        imageWidget = Image.file(
          File(localPath),
          fit: BoxFit.cover,
          width: displayWidth,
          height: displayHeight,
        );
      } else {
        imageWidget = Container(
          color: Colors.grey[200],
          width: displayWidth,
          height: displayHeight,
        );
      }

      return Stack(
        children: [
          // 本地圖片預覽
          Container(
            width: displayWidth,
            height: displayHeight,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
            child: ClipRRect(borderRadius: borderRadius, child: imageWidget),
          ),
          // 半透明黑色遮罩（讓圖片變暗，表示傳送中）
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: borderRadius,
              ),
            ),
          ),
        ],
      );
    }

    // 如果沒有本地圖片資訊，顯示純載入狀態（備用）
    return Container(
      width: displayWidth,
      height: displayHeight,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
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

  /// 使用已知尺寸建構圖片訊息
  Widget _buildImageWithSize(
    ChatMessage message,
    double displayWidth,
    double displayHeight, {
    BorderRadius? borderRadius,
  }) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(12.r);
    // 使用穩定的 key，基於 message.id 和 imagePath，避免不必要的重建
    final imageKey = 'image_${message.id}_${message.imagePath}';

    // 檢查是否有本地預覽資訊（用於 placeholder）
    final pendingData = _pendingImageData[message.id];

    // 構建本地預覽或灰色背景的 placeholder
    Widget buildPlaceholder({bool withDarkOverlay = true}) {
      if (pendingData != null) {
        final imageBytes = pendingData['imageBytes'] as Uint8List?;
        final localPath = pendingData['localPath'] as String?;

        Widget? localImage;
        if (imageBytes != null) {
          localImage = Image.memory(
            imageBytes,
            fit: BoxFit.cover,
            width: displayWidth,
            height: displayHeight,
          );
        } else if (localPath != null) {
          localImage = Image.file(
            File(localPath),
            fit: BoxFit.cover,
            width: displayWidth,
            height: displayHeight,
          );
        }

        if (localImage != null) {
          return Stack(
            children: [
              ClipRRect(borderRadius: effectiveBorderRadius, child: localImage),
              if (withDarkOverlay)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: effectiveBorderRadius,
                    ),
                  ),
                ),
            ],
          );
        }
      }

      // 沒有本地預覽，顯示灰色背景和載入動畫
      return Container(
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
      );
    }

    // 檢查緩存中是否有 URL
    final imagePath = message.imagePath!;
    final cachedUrl = _chatImageUrlCache[imagePath];

    // 如果沒有緩存且不在載入中，觸發異步載入
    if (!_chatImageUrlCache.containsKey(imagePath)) {
      _loadChatImageUrlIfNeeded(imagePath);
    }

    // 如果緩存中沒有 URL（正在載入或載入失敗），顯示 placeholder
    if (cachedUrl == null) {
      return Container(
        key: ValueKey(imageKey),
        width: displayWidth,
        height: displayHeight,
        decoration: BoxDecoration(
          borderRadius: effectiveBorderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: effectiveBorderRadius,
          child: buildPlaceholder(),
        ),
      );
    }

    // 有緩存的 URL，直接顯示圖片
    return GestureDetector(
      key: ValueKey(imageKey),
      onTap: () {
        _openImageViewer(message);
      },
      child: Hero(
        tag: message.id,
        child: Container(
          width: displayWidth,
          height: displayHeight,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: Offset(0, 2.h),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: effectiveBorderRadius,
            child: CachedNetworkImage(
              imageUrl: cachedUrl,
              cacheManager: ImageCacheService().getCacheManager(CacheType.chat),
              cacheKey: imagePath, // 使用 imagePath 作為緩存 key
              fit: BoxFit.cover, // 使用 cover 填滿容器
              width: displayWidth,
              height: displayHeight,
              memCacheWidth: displayWidth.toInt(), // 限制記憶體緩存尺寸
              memCacheHeight: displayHeight.toInt(),
              placeholder:
                  (context, url) => buildPlaceholder(withDarkOverlay: false),
              imageBuilder: (context, imageProvider) {
                // 網路圖片載入完成，清理本地預覽資訊
                if (_pendingImageData.containsKey(message.id)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _pendingImageData.remove(message.id);
                  });
                }
                return Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  width: displayWidth,
                  height: displayHeight,
                );
              },
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

  /// 自動調整尺寸的圖片訊息（用於沒有尺寸資訊的情況）
  Widget _buildImageWithAutoSize(
    ChatMessage message, {
    BorderRadius? borderRadius,
  }) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(12.r);
    // 為了避免圖片載入時改變高度導致 ListView 跳動
    // 使用固定的初始容器，載入完成後也保持固定大小
    // 使用較大的預設尺寸，載入後會根據實際比例調整
    final displayWidth = 200.w;
    final displayHeight = 200.w; // 初始使用正方形，載入後會調整

    // 使用穩定的 key，基於 message.id 和 imagePath，避免不必要的重建
    final imageKey = 'image_${message.id}_${message.imagePath}';

    // 檢查是否有本地預覽資訊（用於 placeholder）
    final pendingData = _pendingImageData[message.id];

    // 構建本地預覽或灰色背景的 placeholder
    Widget buildPlaceholder({bool withDarkOverlay = true}) {
      if (pendingData != null) {
        final imageBytes = pendingData['imageBytes'] as Uint8List?;
        final localPath = pendingData['localPath'] as String?;

        Widget? localImage;
        if (imageBytes != null) {
          localImage = Image.memory(
            imageBytes,
            fit: BoxFit.cover,
            width: displayWidth,
            height: displayHeight,
          );
        } else if (localPath != null) {
          localImage = Image.file(
            File(localPath),
            fit: BoxFit.cover,
            width: displayWidth,
            height: displayHeight,
          );
        }

        if (localImage != null) {
          return Stack(
            children: [
              ClipRRect(borderRadius: effectiveBorderRadius, child: localImage),
              if (withDarkOverlay)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: effectiveBorderRadius,
                    ),
                  ),
                ),
            ],
          );
        }
      }

      // 沒有本地預覽，顯示灰色背景和載入動畫
      return Container(
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
      );
    }

    // 檢查緩存中是否有 URL
    final imagePath = message.imagePath!;
    final cachedUrl = _chatImageUrlCache[imagePath];

    // 如果沒有緩存且不在載入中，觸發異步載入
    if (!_chatImageUrlCache.containsKey(imagePath)) {
      _loadChatImageUrlIfNeeded(imagePath);
    }

    // 如果緩存中沒有 URL（正在載入或載入失敗），顯示 placeholder
    if (cachedUrl == null) {
      return Container(
        key: ValueKey(imageKey),
        width: displayWidth,
        height: displayHeight,
        decoration: BoxDecoration(
          borderRadius: effectiveBorderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: effectiveBorderRadius,
          child: buildPlaceholder(),
        ),
      );
    }

    // 有緩存的 URL，直接顯示圖片
    return GestureDetector(
      key: ValueKey(imageKey),
      onTap: () {
        _openImageViewer(message);
      },
      child: Hero(
        tag: message.id,
        child: Container(
          width: displayWidth,
          height: displayHeight,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: Offset(0, 2.h),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: effectiveBorderRadius,
            child: CachedNetworkImage(
              imageUrl: cachedUrl,
              cacheManager: ImageCacheService().getCacheManager(CacheType.chat),
              cacheKey: imagePath, // 使用 imagePath 作為緩存 key
              fit: BoxFit.cover, // 使用 cover 填滿容器
              width: displayWidth,
              height: displayHeight,
              memCacheWidth: displayWidth.toInt(), // 限制記憶體緩存尺寸
              memCacheHeight: displayHeight.toInt(),
              placeholder:
                  (context, url) => buildPlaceholder(withDarkOverlay: false),
              errorWidget:
                  (context, url, error) => Container(
                    width: displayWidth,
                    height: displayHeight,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
                  ),
              imageBuilder: (context, imageProvider) {
                // 當圖片載入完成後，儲存圖片尺寸以便下次使用
                // 只在尺寸尚未儲存時才儲存，避免重複操作
                if (message.imageWidth == null || message.imageHeight == null) {
                  _saveImageSize(message, imageProvider);
                }
                // 清理本地預覽資訊
                if (_pendingImageData.containsKey(message.id)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _pendingImageData.remove(message.id);
                  });
                }
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
    return Padding(
      padding: EdgeInsets.only(
        left: 15.w,
        right: 15.w,
        top: 10.h,
        bottom: max(5.h, MediaQuery.of(context).padding.bottom * 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 相機按鈕（向上移動一點）
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: _buildCameraButton(),
          ),

          SizedBox(width: 10.w),

          // 輸入框（包含內部的發送按鈕）
          Expanded(child: _buildMessageInput()),
        ],
      ),
    );
  }

  Widget _buildCameraButton() {
    bool isPressed = false;

    return StatefulBuilder(
      builder: (context, setButtonState) {
        return GestureDetector(
          onTapDown: (_) {
            setButtonState(() {
              isPressed = true;
            });
          },
          onTapUp: (_) {
            setButtonState(() {
              isPressed = false;
            });
            _sendImageMessage();
          },
          onTapCancel: () {
            setButtonState(() {
              isPressed = false;
            });
          },
          child: AnimatedScale(
            scale: isPressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: SizedBox(
              width: 35.w,
              height: 35.h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 底部陰影（按下時隱藏）
                  if (!isPressed)
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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    transform: Matrix4.translationValues(
                      0,
                      isPressed ? 2.h : 0,
                      0,
                    ),
                    child: Image.asset(
                      'assets/images/icon/camera.webp',
                      width: 35.w,
                      height: 35.h,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      constraints: BoxConstraints(
        minHeight: 50.h, // 確保有足夠高度顯示按鈕
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF23456B), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 輸入框
          Padding(
            padding: EdgeInsets.only(
              right: _hasText ? 50.w : 0, // 為發送按鈕預留空間
            ),
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              maxLines: null,
              minLines: 1,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                fontFamily: 'OtsutomeFont',
                fontSize: 16.sp,
                height: 1.2,
              ),
              decoration: InputDecoration(
                hintText: '輸入訊息...',
                border: InputBorder.none,
                isDense: true,
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'OtsutomeFont',
                  fontSize: 16.sp,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10.w,
                  vertical: 16.h,
                ),
              ),
            ),
          ),
          // 發送按鈕（只在有內容時顯示，貼齊底部）
          if (_hasText)
            Positioned(
              right: 8.w,
              bottom: 11.h, // 與 contentPadding 的 vertical 保持一致
              child: _buildSendButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    bool isPressed = false;

    return StatefulBuilder(
      builder: (context, setButtonState) {
        return GestureDetector(
          onTapDown: (_) {
            setButtonState(() {
              isPressed = true;
            });
          },
          onTapUp: (_) {
            setButtonState(() {
              isPressed = false;
            });
            _sendTextMessage();
            // 保持焦點，讓用戶可以連續輸入訊息
          },
          onTapCancel: () {
            setButtonState(() {
              isPressed = false;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            transform: Matrix4.translationValues(0, isPressed ? 2.h : 0, 0),
            child: SizedBox(
              width: 30.w,
              height: 30.h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 底部陰影（按下時隱藏）
                  if (!isPressed)
                    Positioned(
                      left: 0,
                      top: 2.h,
                      child: Image.asset(
                        'assets/images/icon/send.webp',
                        width: 30.w,
                        height: 30.h,
                        color: Colors.black.withOpacity(0.4),
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                  // 主圖標
                  Image.asset(
                    'assets/images/icon/send.webp',
                    width: 30.w,
                    height: 30.h,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
