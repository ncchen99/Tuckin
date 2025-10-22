import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  Database? _database;
  final Map<String, StreamSubscription> _realtimeSubscriptions = {};
  final Map<String, StreamController<List<ChatMessage>>> _messageControllers =
      {};

  /// 初始化本地資料庫
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'chat_messages.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE chat_messages (
            id TEXT PRIMARY KEY,
            dining_event_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            content TEXT,
            message_type TEXT NOT NULL,
            image_path TEXT,
            created_at TEXT NOT NULL,
            sender_nickname TEXT,
            sender_avatar_path TEXT,
            sender_gender TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_dining_event_id ON chat_messages(dining_event_id)',
        );
        await db.execute(
          'CREATE INDEX idx_created_at ON chat_messages(created_at)',
        );
      },
    );
  }

  /// 訂閱指定聚餐事件的即時訊息
  Stream<List<ChatMessage>> subscribeToMessages(String diningEventId) {
    // 如果已經有這個聊天室的 StreamController，直接返回
    if (_messageControllers.containsKey(diningEventId)) {
      return _messageControllers[diningEventId]!.stream;
    }

    // 建立新的 StreamController
    final controller = StreamController<List<ChatMessage>>.broadcast();
    _messageControllers[diningEventId] = controller;

    // 先從本地資料庫載入歷史訊息
    _loadLocalMessages(diningEventId).then((localMessages) {
      if (!controller.isClosed) {
        controller.add(localMessages);
      }
    });

    // 從 Supabase 拉取最新訊息並合併
    _fetchAndMergeMessages(diningEventId);

    // 訂閱 Realtime 更新
    final subscription = Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('dining_event_id', diningEventId)
        .order('created_at')
        .listen((data) async {
          debugPrint('收到 Realtime 更新: ${data.length} 則訊息');

          // 將訊息轉換為 ChatMessage 並補充發送者資訊
          final messages = await _convertAndEnrichMessages(data);

          // 儲存到本地資料庫
          await _saveMessagesToLocal(messages);

          // 發送到 Stream
          if (!controller.isClosed) {
            controller.add(messages);
          }
        });

    _realtimeSubscriptions[diningEventId] = subscription;

    return controller.stream;
  }

  /// 取消訂閱
  Future<void> unsubscribeFromMessages(String diningEventId) async {
    final subscription = _realtimeSubscriptions.remove(diningEventId);
    await subscription?.cancel();

    final controller = _messageControllers.remove(diningEventId);
    await controller?.close();

    debugPrint('已取消訂閱聊天室: $diningEventId');
  }

  /// 從本地資料庫載入訊息
  Future<List<ChatMessage>> _loadLocalMessages(String diningEventId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'chat_messages',
        where: 'dining_event_id = ?',
        whereArgs: [diningEventId],
        orderBy: 'created_at ASC',
      );

      return maps.map((map) => ChatMessage.fromMap(map)).toList();
    } catch (e) {
      debugPrint('載入本地訊息失敗: $e');
      return [];
    }
  }

  /// 從 Supabase 拉取訊息並與本地合併
  Future<void> _fetchAndMergeMessages(String diningEventId) async {
    try {
      final response = await Supabase.instance.client
          .from('chat_messages')
          .select()
          .eq('dining_event_id', diningEventId)
          .order('created_at');

      final messages = await _convertAndEnrichMessages(
        response as List<dynamic>,
      );

      // 儲存到本地
      await _saveMessagesToLocal(messages);

      // 更新 Stream
      final controller = _messageControllers[diningEventId];
      if (controller != null && !controller.isClosed) {
        controller.add(messages);
      }
    } catch (e) {
      debugPrint('拉取遠端訊息失敗: $e');
    }
  }

  /// 轉換訊息並補充發送者資訊
  Future<List<ChatMessage>> _convertAndEnrichMessages(
    List<dynamic> data,
  ) async {
    final List<ChatMessage> messages = [];

    for (final item in data) {
      final message = ChatMessage.fromJson(item as Map<String, dynamic>);

      // 查詢發送者資訊
      try {
        final profile =
            await Supabase.instance.client
                .from('user_profiles')
                .select('nickname, avatar_path, gender')
                .eq('user_id', message.userId)
                .single();

        messages.add(
          message.copyWith(
            senderNickname: profile['nickname'] as String?,
            senderAvatarPath: profile['avatar_path'] as String?,
            senderGender: profile['gender'] as String?,
          ),
        );
      } catch (e) {
        debugPrint('查詢發送者資訊失敗: $e');
        messages.add(message);
      }
    }

    return messages;
  }

  /// 儲存訊息到本地資料庫（使用 upsert 邏輯）
  Future<void> _saveMessagesToLocal(List<ChatMessage> messages) async {
    try {
      final db = await database;
      final batch = db.batch();

      for (final message in messages) {
        batch.insert(
          'chat_messages',
          message.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('儲存訊息到本地失敗: $e');
    }
  }

  /// 發送文字訊息
  Future<bool> sendTextMessage(String diningEventId, String content) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        debugPrint('用戶未登入');
        return false;
      }

      final messageId = _uuid.v4();

      // 插入訊息到 Supabase
      await Supabase.instance.client.from('chat_messages').insert({
        'id': messageId,
        'dining_event_id': diningEventId,
        'user_id': currentUser.id,
        'content': content,
        'message_type': 'text',
      });

      // 發送通知
      await _sendChatNotification(
        diningEventId,
        content.length > 50 ? '${content.substring(0, 50)}...' : content,
        'text',
      );

      debugPrint('文字訊息已發送');
      return true;
    } catch (e) {
      debugPrint('發送文字訊息失敗: $e');
      return false;
    }
  }

  /// 拍照並發送圖片訊息
  Future<bool> sendImageMessage(String diningEventId) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        debugPrint('用戶未登入');
        return false;
      }

      // 1. 使用相機拍照
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (photo == null) {
        debugPrint('用戶取消拍照');
        return false;
      }

      // 2. 壓縮圖片為 WebP 格式
      final imageBytes = await FlutterImageCompress.compressWithFile(
        photo.path,
        format: CompressFormat.webp,
        quality: 85,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (imageBytes == null) {
        debugPrint('圖片壓縮失敗');
        return false;
      }

      // 3. 生成訊息 ID
      final messageId = _uuid.v4();

      // 4. 獲取上傳 URL
      final uploadData = await _getImageUploadUrl(diningEventId, messageId);
      if (uploadData == null) {
        debugPrint('獲取上傳 URL 失敗');
        return false;
      }

      final uploadUrl = uploadData['upload_url'] as String;
      final imagePath = uploadData['image_path'] as String;

      // 5. 上傳圖片到 R2
      final uploadSuccess = await _uploadImageToR2(uploadUrl, imageBytes);
      if (!uploadSuccess) {
        debugPrint('上傳圖片失敗');
        return false;
      }

      // 6. 插入訊息到 Supabase
      await Supabase.instance.client.from('chat_messages').insert({
        'id': messageId,
        'dining_event_id': diningEventId,
        'user_id': currentUser.id,
        'message_type': 'image',
        'image_path': imagePath,
      });

      // 7. 發送通知
      await _sendChatNotification(diningEventId, '[圖片]', 'image');

      debugPrint('圖片訊息已發送');
      return true;
    } catch (e) {
      debugPrint('發送圖片訊息失敗: $e');
      return false;
    }
  }

  /// 獲取圖片上傳 URL
  Future<Map<String, dynamic>?> _getImageUploadUrl(
    String diningEventId,
    String messageId,
  ) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        debugPrint('未找到用戶 token');
        return null;
      }

      final url = Uri.parse('${_apiService.baseUrl}/chat/image/upload-url');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'dining_event_id': diningEventId,
          'message_id': messageId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      } else {
        debugPrint('獲取上傳 URL 失敗: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('獲取上傳 URL 時發生錯誤: $e');
      return null;
    }
  }

  /// 上傳圖片到 R2
  Future<bool> _uploadImageToR2(String uploadUrl, Uint8List imageBytes) async {
    try {
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': 'image/webp'},
        body: imageBytes,
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('上傳圖片時發生錯誤: $e');
      return false;
    }
  }

  /// 獲取圖片讀取 URL
  Future<String?> getImageUrl(String imagePath) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        debugPrint('未找到用戶 token');
        return null;
      }

      final url = Uri.parse('${_apiService.baseUrl}/chat/image/url');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'image_path': imagePath}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['url'] as String?;
      } else {
        debugPrint('獲取圖片 URL 失敗: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('獲取圖片 URL 時發生錯誤: $e');
      return null;
    }
  }

  /// 發送聊天通知
  Future<void> _sendChatNotification(
    String diningEventId,
    String messagePreview,
    String messageType,
  ) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        debugPrint('未找到用戶 token');
        return;
      }

      final url = Uri.parse('${_apiService.baseUrl}/chat/notify');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'dining_event_id': diningEventId,
          'message_preview': messagePreview,
          'message_type': messageType,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('聊天通知已發送');
      } else {
        debugPrint('發送聊天通知失敗: ${response.body}');
      }
    } catch (e) {
      debugPrint('發送聊天通知時發生錯誤: $e');
    }
  }

  /// APP 回到前台時同步新訊息
  Future<void> syncMessages(String diningEventId) async {
    debugPrint('同步聊天室訊息: $diningEventId');
    await _fetchAndMergeMessages(diningEventId);
  }

  /// 清理資源
  Future<void> dispose() async {
    for (final subscription in _realtimeSubscriptions.values) {
      await subscription.cancel();
    }
    _realtimeSubscriptions.clear();

    for (final controller in _messageControllers.values) {
      await controller.close();
    }
    _messageControllers.clear();

    await _database?.close();
    _database = null;
  }
}

