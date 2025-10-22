class ChatMessage {
  final String id;
  final String diningEventId;
  final String userId;
  final String? content;
  final String messageType; // 'text' or 'image'
  final String? imagePath;
  final DateTime createdAt;

  // 額外資訊（不儲存在資料庫，用於 UI 顯示）
  String? senderNickname;
  String? senderAvatarPath;
  String? senderGender;

  ChatMessage({
    required this.id,
    required this.diningEventId,
    required this.userId,
    this.content,
    required this.messageType,
    this.imagePath,
    required this.createdAt,
    this.senderNickname,
    this.senderAvatarPath,
    this.senderGender,
  });

  /// 從 Supabase JSON 轉換
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      diningEventId: json['dining_event_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String?,
      messageType: json['message_type'] as String,
      imagePath: json['image_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      senderNickname: json['sender_nickname'] as String?,
      senderAvatarPath: json['sender_avatar_path'] as String?,
      senderGender: json['sender_gender'] as String?,
    );
  }

  /// 轉換為 Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dining_event_id': diningEventId,
      'user_id': userId,
      'content': content,
      'message_type': messageType,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// 從本地資料庫 Map 轉換
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      diningEventId: map['dining_event_id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String?,
      messageType: map['message_type'] as String,
      imagePath: map['image_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      senderNickname: map['sender_nickname'] as String?,
      senderAvatarPath: map['sender_avatar_path'] as String?,
      senderGender: map['sender_gender'] as String?,
    );
  }

  /// 轉換為本地資料庫 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dining_event_id': diningEventId,
      'user_id': userId,
      'content': content,
      'message_type': messageType,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
      'sender_nickname': senderNickname,
      'sender_avatar_path': senderAvatarPath,
      'sender_gender': senderGender,
    };
  }

  /// 複製並更新
  ChatMessage copyWith({
    String? id,
    String? diningEventId,
    String? userId,
    String? content,
    String? messageType,
    String? imagePath,
    DateTime? createdAt,
    String? senderNickname,
    String? senderAvatarPath,
    String? senderGender,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      diningEventId: diningEventId ?? this.diningEventId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      senderNickname: senderNickname ?? this.senderNickname,
      senderAvatarPath: senderAvatarPath ?? this.senderAvatarPath,
      senderGender: senderGender ?? this.senderGender,
    );
  }

  /// 判斷是否為圖片訊息
  bool get isImage => messageType == 'image';

  /// 判斷是否為文字訊息
  bool get isText => messageType == 'text';

  @override
  String toString() {
    return 'ChatMessage(id: $id, type: $messageType, userId: $userId, content: $content)';
  }
}

