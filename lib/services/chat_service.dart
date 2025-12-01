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
import 'package:shared_preferences/shared_preferences.dart';
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
      version: 2,
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
            sender_gender TEXT,
            image_width INTEGER,
            image_height INTEGER,
            send_status TEXT,
            fixed_avatar_index INTEGER
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_dining_event_id ON chat_messages(dining_event_id)',
        );
        await db.execute(
          'CREATE INDEX idx_created_at ON chat_messages(created_at)',
        );

        // 建立固定頭像表
        await db.execute('''
          CREATE TABLE user_fixed_avatars (
            user_id TEXT NOT NULL,
            dining_event_id TEXT NOT NULL,
            fixed_avatar_index INTEGER NOT NULL,
            PRIMARY KEY (user_id, dining_event_id)
          )
        ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          // 新增欄位
          await db.execute(
            'ALTER TABLE chat_messages ADD COLUMN image_width INTEGER',
          );
          await db.execute(
            'ALTER TABLE chat_messages ADD COLUMN image_height INTEGER',
          );
          await db.execute(
            'ALTER TABLE chat_messages ADD COLUMN send_status TEXT',
          );
          await db.execute(
            'ALTER TABLE chat_messages ADD COLUMN fixed_avatar_index INTEGER',
          );

          // 建立固定頭像表
          await db.execute('''
            CREATE TABLE user_fixed_avatars (
              user_id TEXT NOT NULL,
              dining_event_id TEXT NOT NULL,
              fixed_avatar_index INTEGER NOT NULL,
              PRIMARY KEY (user_id, dining_event_id)
            )
          ''');
        }
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
        .order('created_at', ascending: true)
        .listen((data) async {
          debugPrint('收到 Realtime 更新: ${data.length} 則訊息');

          // 將訊息轉換為 ChatMessage 並補充發送者資訊
          final messages = await _convertAndEnrichMessages(data);

          // 確保訊息按 created_at 升序排序（從舊到新）
          messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

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

      final messages = maps.map((map) => ChatMessage.fromMap(map)).toList();

      // 確保訊息按 created_at 升序排序（從舊到新）
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return messages;
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
          .order('created_at', ascending: true);

      final remoteMessages = await _convertAndEnrichMessages(
        response as List<dynamic>,
      );

      // 載入本地訊息以進行合併
      final localMessages = await _loadLocalMessages(diningEventId);
      final localMessagesMap = {for (var m in localMessages) m.id: m};

      final messages =
          remoteMessages.map((remoteMessage) {
            final localMessage = localMessagesMap[remoteMessage.id];
            if (localMessage != null) {
              // 如果遠端訊息沒有圖片尺寸，則保留本地已有的尺寸
              return remoteMessage.copyWith(
                imageWidth: remoteMessage.imageWidth ?? localMessage.imageWidth,
                imageHeight:
                    remoteMessage.imageHeight ?? localMessage.imageHeight,
              );
            }
            return remoteMessage;
          }).toList();

      // 確保訊息按 created_at 升序排序（從舊到新）
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

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

    // 確保訊息按 created_at 升序排序（從舊到新）
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

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

  /// 選擇圖片（拍照）並返回圖片資訊
  /// 返回 Map 包含: localPath, imageBytes, width, height
  /// 如果用戶取消或失敗則返回 null
  Future<Map<String, dynamic>?> pickImageFromCamera() async {
    try {
      // 1. 使用相機拍照
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (photo == null) {
        debugPrint('用戶取消拍照');
        return null;
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
        return null;
      }

      // 解碼圖片以獲取尺寸
      final decodedImage = await decodeImageFromList(imageBytes);
      final imageWidth = decodedImage.width;
      final imageHeight = decodedImage.height;

      return {
        'localPath': photo.path,
        'imageBytes': imageBytes,
        'width': imageWidth,
        'height': imageHeight,
      };
    } catch (e) {
      debugPrint('選擇圖片失敗: $e');
      return null;
    }
  }

  /// 上傳並發送已選擇的圖片訊息
  /// 返回 true 表示成功，false 表示失敗
  Future<bool> uploadAndSendImage(
    String diningEventId,
    Uint8List imageBytes,
    int imageWidth,
    int imageHeight,
  ) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        debugPrint('用戶未登入');
        return false;
      }

      // 生成訊息 ID
      final messageId = _uuid.v4();

      // 獲取上傳 URL
      final uploadData = await _getImageUploadUrl(diningEventId, messageId);
      if (uploadData == null) {
        debugPrint('獲取上傳 URL 失敗');
        return false;
      }

      final uploadUrl = uploadData['upload_url'] as String;
      final imagePath = uploadData['image_path'] as String;

      // 上傳圖片到 R2
      final uploadSuccess = await _uploadImageToR2(uploadUrl, imageBytes);
      if (!uploadSuccess) {
        debugPrint('上傳圖片失敗');
        return false;
      }

      // 插入訊息到 Supabase
      await Supabase.instance.client.from('chat_messages').insert({
        'id': messageId,
        'dining_event_id': diningEventId,
        'user_id': currentUser.id,
        'message_type': 'image',
        'image_path': imagePath,
        'image_width': imageWidth,
        'image_height': imageHeight,
      });

      // 發送通知
      await _sendChatNotification(diningEventId, '[圖片]', 'image');

      debugPrint('圖片訊息已發送');
      return true;
    } catch (e) {
      debugPrint('發送圖片訊息失敗: $e');
      return false;
    }
  }

  /// 拍照並發送圖片訊息（保留舊方法以兼容）
  Future<bool> sendImageMessage(String diningEventId) async {
    final imageData = await pickImageFromCamera();
    if (imageData == null) return false;

    return await uploadAndSendImage(
      diningEventId,
      imageData['imageBytes'] as Uint8List,
      imageData['width'] as int,
      imageData['height'] as int,
    );
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

  /// 獲取圖片讀取 URL（帶緩存）
  /// 使用 imagePath 作為緩存 key，避免每次重新獲取 URL
  Future<String?> getImageUrl(String imagePath) async {
    try {
      // 先檢查本地緩存（使用 SharedPreferences 緩存 URL）
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'chat_image_url_$imagePath';
      final cachedUrl = prefs.getString(cacheKey);

      // 如果緩存存在且未過期（presigned URL 通常有效期 1 小時）
      // 我們設置緩存時間為 50 分鐘，確保 URL 仍然有效
      final cacheTimeKey = '${cacheKey}_time';
      final cacheTime = prefs.getInt(cacheTimeKey);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (cachedUrl != null && cacheTime != null) {
        final cacheAge = now - cacheTime;
        // 50 分鐘 = 50 * 60 * 1000 毫秒
        if (cacheAge < 50 * 60 * 1000) {
          debugPrint('使用緩存的圖片 URL: $imagePath');
          return cachedUrl;
        }
      }

      // 緩存不存在或已過期，重新獲取
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
        final imageUrl = data['url'] as String?;

        // 緩存 URL 和時間戳
        if (imageUrl != null) {
          await prefs.setString(cacheKey, imageUrl);
          await prefs.setInt(cacheTimeKey, now);
          debugPrint('已緩存圖片 URL: $imagePath');
        }

        return imageUrl;
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

  /// 獲取或生成用戶在特定聊天室的固定頭像索引
  Future<int> getFixedAvatarIndex(
    String userId,
    String diningEventId,
    String? gender,
  ) async {
    try {
      final db = await database;

      // 先查詢是否已有固定頭像
      final List<Map<String, dynamic>> result = await db.query(
        'user_fixed_avatars',
        where: 'user_id = ? AND dining_event_id = ?',
        whereArgs: [userId, diningEventId],
      );

      if (result.isNotEmpty) {
        return result.first['fixed_avatar_index'] as int;
      }

      // 沒有則生成新的隨機索引（1-6）
      final random = DateTime.now().millisecondsSinceEpoch % 6 + 1;

      await db.insert('user_fixed_avatars', {
        'user_id': userId,
        'dining_event_id': diningEventId,
        'fixed_avatar_index': random,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      return random;
    } catch (e) {
      debugPrint('獲取固定頭像索引失敗: $e');
      return 1; // 預設返回 1
    }
  }

  /// 儲存圖片尺寸到本地資料庫
  Future<void> saveImageDimensions(
    String messageId,
    int width,
    int height,
  ) async {
    try {
      final db = await database;
      await db.update(
        'chat_messages',
        {'image_width': width, 'image_height': height},
        where: 'id = ?',
        whereArgs: [messageId],
      );
      debugPrint('已儲存圖片尺寸: $width x $height');
    } catch (e) {
      debugPrint('儲存圖片尺寸失敗: $e');
    }
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
