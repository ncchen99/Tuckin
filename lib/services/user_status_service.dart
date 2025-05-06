import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserStatusService with ChangeNotifier {
  DateTime? _confirmedDinnerTime;
  String? _dinnerRestaurantId;
  DateTime? _replyDeadline;
  DateTime? _cancelDeadline;

  // 新增欄位
  String? _matchingGroupId;
  String? _diningEventId;
  Map<String, dynamic>? _restaurantInfo;

  // 新增餐廳預訂相關欄位
  String? _eventStatus; // 聚餐事件狀態
  String? _reservationName; // 預訂人姓名
  String? _reservationPhone; // 預訂人電話
  String? _userStatus; // 用戶狀態

  // 新增幫忙訂位狀態
  bool _isHelpingWithReservation = false; // 是否正在幫忙訂位
  DateTime? _helpingReservationStartTime; // 開始幫忙訂位的時間戳

  // 新增用餐人數
  int? _attendees;

  // SharedPreferences 的鍵值
  static const String _confirmedDinnerTimeKey = 'confirmed_dinner_time';
  static const String _dinnerRestaurantIdKey = 'dinner_restaurant_id';
  static const String _replyDeadlineKey = 'reply_deadline';
  static const String _cancelDeadlineKey = 'cancel_deadline';

  // 新增鍵值
  static const String _matchingGroupIdKey = 'matching_group_id';
  static const String _diningEventIdKey = 'dining_event_id';
  static const String _restaurantInfoKey = 'restaurant_info';
  static const String _eventStatusKey = 'event_status';
  static const String _reservationNameKey = 'reservation_name';
  static const String _reservationPhoneKey = 'reservation_phone';
  static const String _userStatusKey = 'user_status';
  static const String _isHelpingWithReservationKey =
      'is_helping_with_reservation'; // 新增幫忙訂位狀態的鍵值
  static const String _helpingReservationStartTimeKey =
      'helping_reservation_start_time'; // 新增幫忙訂位開始時間的鍵值
  static const String _attendeesKey = 'attendees'; // 新增用餐人數的鍵值

  // 幫忙訂位的有效時間(秒)
  static const int helpingReservationValiditySeconds = 596; // 9分56秒

  UserStatusService() {
    _loadFromPrefs();
    debugPrint('UserStatusService 已創建，並開始從持久化存儲載入數據');
  }

  // Getter 方法
  DateTime? get confirmedDinnerTime => _confirmedDinnerTime;
  String? get dinnerRestaurantId => _dinnerRestaurantId;
  DateTime? get replyDeadline => _replyDeadline;
  DateTime? get cancelDeadline => _cancelDeadline;

  // 新增的 Getter
  String? get matchingGroupId => _matchingGroupId;
  String? get diningEventId => _diningEventId;
  Map<String, dynamic>? get restaurantInfo => _restaurantInfo;
  String? get eventStatus => _eventStatus;
  String? get reservationName => _reservationName;
  String? get reservationPhone => _reservationPhone;
  String? get userStatus => _userStatus;
  bool get isHelpingWithReservation => _isHelpingWithReservation;
  DateTime? get helpingReservationStartTime => _helpingReservationStartTime;
  int? get attendees => _attendees; // 用餐人數的getter

  // 格式化日期時間為可讀字符串
  String get formattedDinnerTime {
    if (_confirmedDinnerTime == null) return '未確定';
    return DateFormat('yyyy-MM-dd HH:mm').format(_confirmedDinnerTime!);
  }

  // 格式化取消截止時間為可讀字符串
  String get formattedCancelDeadline {
    if (_cancelDeadline == null) return '未確定';
    return DateFormat('yyyy-MM-dd HH:mm').format(_cancelDeadline!);
  }

  // 判斷是否可以取消預約
  bool get canCancelReservation {
    if (_cancelDeadline == null) return false;
    return DateTime.now().isBefore(_cancelDeadline!);
  }

  // 判斷幫忙訂位時間是否有效
  bool get isHelpingReservationValid {
    if (_helpingReservationStartTime == null || !_isHelpingWithReservation) {
      return false;
    }

    // 檢查訂位開始時間是否在有效期內（596秒）
    final validUntil = _helpingReservationStartTime!.add(
      Duration(seconds: helpingReservationValiditySeconds),
    );
    return DateTime.now().isBefore(validUntil);
  }

  // 從 SharedPreferences 載入資料
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 載入聚餐時間
      final dinnerTimeMillis = prefs.getInt(_confirmedDinnerTimeKey);
      if (dinnerTimeMillis != null) {
        _confirmedDinnerTime = DateTime.fromMillisecondsSinceEpoch(
          dinnerTimeMillis,
        );
      }

      // 載入餐廳ID
      _dinnerRestaurantId = prefs.getString(_dinnerRestaurantIdKey);

      // 載入回覆截止時間
      final replyDeadlineMillis = prefs.getInt(_replyDeadlineKey);
      if (replyDeadlineMillis != null) {
        _replyDeadline = DateTime.fromMillisecondsSinceEpoch(
          replyDeadlineMillis,
        );
      }

      // 載入取消截止時間
      final cancelDeadlineMillis = prefs.getInt(_cancelDeadlineKey);
      if (cancelDeadlineMillis != null) {
        _cancelDeadline = DateTime.fromMillisecondsSinceEpoch(
          cancelDeadlineMillis,
        );
      }

      // 新增：載入配對組ID
      _matchingGroupId = prefs.getString(_matchingGroupIdKey);

      // 新增：載入聚餐事件ID
      _diningEventId = prefs.getString(_diningEventIdKey);

      // 新增：載入餐廳詳細信息
      final restaurantInfoString = prefs.getString(_restaurantInfoKey);
      if (restaurantInfoString != null) {
        try {
          _restaurantInfo =
              json.decode(restaurantInfoString) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('解析餐廳信息時出錯: $e');
          _restaurantInfo = null;
        }
      }

      // 新增：載入聚餐事件狀態
      _eventStatus = prefs.getString(_eventStatusKey);

      // 新增：載入預訂人姓名
      _reservationName = prefs.getString(_reservationNameKey);

      // 新增：載入預訂人電話
      _reservationPhone = prefs.getString(_reservationPhoneKey);

      // 新增：載入用戶狀態
      _userStatus = prefs.getString(_userStatusKey);

      // 新增：載入幫忙訂位狀態
      _isHelpingWithReservation =
          prefs.getBool(_isHelpingWithReservationKey) ?? false;

      // 新增：載入幫忙訂位開始時間
      final startTimeMillis = prefs.getInt(_helpingReservationStartTimeKey);
      if (startTimeMillis != null) {
        _helpingReservationStartTime = DateTime.fromMillisecondsSinceEpoch(
          startTimeMillis,
        );
      }

      // 新增：載入用餐人數
      _attendees = prefs.getInt(_attendeesKey);

      debugPrint('從持久化儲存中載入 UserStatusService 資料:');
      if (_confirmedDinnerTime != null) {
        debugPrint('- 聚餐時間: $formattedDinnerTime');
      }
      if (_cancelDeadline != null) {
        debugPrint('- 取消截止時間: $formattedCancelDeadline');
        debugPrint('- 可以取消預約: $canCancelReservation');
      }
      if (_matchingGroupId != null) {
        debugPrint('- 配對組ID: $_matchingGroupId');
      }
      if (_diningEventId != null) {
        debugPrint('- 聚餐事件ID: $_diningEventId');
      }
      if (_restaurantInfo != null) {
        debugPrint('- 餐廳信息已載入');
      }
      if (_eventStatus != null) {
        debugPrint('- 聚餐事件狀態: $_eventStatus');
      }
      if (_reservationName != null) {
        debugPrint('- 預訂人姓名: $_reservationName');
      }
      if (_userStatus != null) {
        debugPrint('- 用戶狀態: $_userStatus');
      }
      if (_isHelpingWithReservation) {
        debugPrint('- 正在幫忙訂位');
        if (_helpingReservationStartTime != null) {
          final isValid = isHelpingReservationValid;
          final formattedTime = DateFormat(
            'yyyy-MM-dd HH:mm:ss',
          ).format(_helpingReservationStartTime!);
          debugPrint('- 幫忙訂位開始時間: $formattedTime, 是否有效: $isValid');
        }
      }

      if (_attendees != null) {
        debugPrint('- 用餐人數: $_attendees');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('載入 UserStatusService 資料時出錯: $e');
    }
  }

  // 儲存資料到 SharedPreferences
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 儲存聚餐時間
      if (_confirmedDinnerTime != null) {
        await prefs.setInt(
          _confirmedDinnerTimeKey,
          _confirmedDinnerTime!.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove(_confirmedDinnerTimeKey);
      }

      // 儲存餐廳ID
      if (_dinnerRestaurantId != null) {
        await prefs.setString(_dinnerRestaurantIdKey, _dinnerRestaurantId!);
      } else {
        await prefs.remove(_dinnerRestaurantIdKey);
      }

      // 儲存回覆截止時間
      if (_replyDeadline != null) {
        await prefs.setInt(
          _replyDeadlineKey,
          _replyDeadline!.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove(_replyDeadlineKey);
      }

      // 儲存取消截止時間
      if (_cancelDeadline != null) {
        await prefs.setInt(
          _cancelDeadlineKey,
          _cancelDeadline!.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove(_cancelDeadlineKey);
      }

      // 新增：儲存配對組ID
      if (_matchingGroupId != null) {
        await prefs.setString(_matchingGroupIdKey, _matchingGroupId!);
      } else {
        await prefs.remove(_matchingGroupIdKey);
      }

      // 新增：儲存聚餐事件ID
      if (_diningEventId != null) {
        await prefs.setString(_diningEventIdKey, _diningEventId!);
      } else {
        await prefs.remove(_diningEventIdKey);
      }

      // 新增：儲存餐廳詳細信息
      if (_restaurantInfo != null) {
        final restaurantInfoString = json.encode(_restaurantInfo);
        await prefs.setString(_restaurantInfoKey, restaurantInfoString);
      } else {
        await prefs.remove(_restaurantInfoKey);
      }

      // 新增：儲存聚餐事件狀態
      if (_eventStatus != null) {
        await prefs.setString(_eventStatusKey, _eventStatus!);
      } else {
        await prefs.remove(_eventStatusKey);
      }

      // 新增：儲存預訂人姓名
      if (_reservationName != null) {
        await prefs.setString(_reservationNameKey, _reservationName!);
      } else {
        await prefs.remove(_reservationNameKey);
      }

      // 新增：儲存預訂人電話
      if (_reservationPhone != null) {
        await prefs.setString(_reservationPhoneKey, _reservationPhone!);
      } else {
        await prefs.remove(_reservationPhoneKey);
      }

      // 新增：儲存用戶狀態
      if (_userStatus != null) {
        await prefs.setString(_userStatusKey, _userStatus!);
      } else {
        await prefs.remove(_userStatusKey);
      }

      // 新增：儲存幫忙訂位狀態
      await prefs.setBool(
        _isHelpingWithReservationKey,
        _isHelpingWithReservation,
      );

      // 新增：儲存幫忙訂位開始時間
      if (_helpingReservationStartTime != null) {
        await prefs.setInt(
          _helpingReservationStartTimeKey,
          _helpingReservationStartTime!.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove(_helpingReservationStartTimeKey);
      }

      // 儲存用餐人數
      if (_attendees != null) {
        await prefs.setInt(_attendeesKey, _attendees!);
      } else {
        await prefs.remove(_attendeesKey);
      }

      debugPrint('成功將 UserStatusService 資料儲存到持久化儲存');
    } catch (e) {
      debugPrint('儲存 UserStatusService 資料時出錯: $e');
    }
  }

  // 設置用戶狀態
  void setUserStatus(String status) {
    if (_userStatus != status) {
      _userStatus = status;
      _saveToPrefs();
      notifyListeners();
    }
  }

  // 設置幫忙訂位狀態
  void setHelpingWithReservation(bool isHelping) {
    if (_isHelpingWithReservation != isHelping) {
      _isHelpingWithReservation = isHelping;

      // 當設置為true時，同時設置開始時間
      if (isHelping) {
        _helpingReservationStartTime = DateTime.now();
        debugPrint(
          '設置幫忙訂位開始時間: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_helpingReservationStartTime!)}',
        );
      } else {
        _helpingReservationStartTime = null;
        debugPrint('清除幫忙訂位開始時間');
      }

      _saveToPrefs();
      notifyListeners();
      debugPrint('已更新幫忙訂位狀態為: $isHelping');
    }
  }

  // 更新幫忙訂位開始時間
  void updateHelpingReservationStartTime() {
    if (_isHelpingWithReservation) {
      _helpingReservationStartTime = DateTime.now();
      debugPrint(
        '更新幫忙訂位開始時間: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_helpingReservationStartTime!)}',
      );
      _saveToPrefs();
      notifyListeners();
    }
  }

  void updateStatus({
    DateTime? confirmedDinnerTime,
    String? dinnerRestaurantId,
    DateTime? replyDeadline,
    DateTime? cancelDeadline,
    String? matchingGroupId,
    String? diningEventId,
    Map<String, dynamic>? restaurantInfo,
    String? eventStatus,
    String? reservationName,
    String? reservationPhone,
    bool? isHelpingWithReservation,
    DateTime? helpingReservationStartTime,
    int? attendees, // 新增用餐人數參數
  }) {
    bool changed = false;
    if (confirmedDinnerTime != null &&
        _confirmedDinnerTime != confirmedDinnerTime) {
      _confirmedDinnerTime = confirmedDinnerTime;
      changed = true;
    }
    if (dinnerRestaurantId != null &&
        _dinnerRestaurantId != dinnerRestaurantId) {
      _dinnerRestaurantId = dinnerRestaurantId;
      changed = true;
    }
    if (replyDeadline != null && _replyDeadline != replyDeadline) {
      _replyDeadline = replyDeadline;
      changed = true;
    }
    if (cancelDeadline != null && _cancelDeadline != cancelDeadline) {
      _cancelDeadline = cancelDeadline;
      changed = true;
    }

    // 新增：更新配對組ID
    if (matchingGroupId != null && _matchingGroupId != matchingGroupId) {
      _matchingGroupId = matchingGroupId;
      changed = true;
    }

    // 新增：更新聚餐事件ID
    if (diningEventId != null && _diningEventId != diningEventId) {
      _diningEventId = diningEventId;
      changed = true;
    }

    // 新增：更新聚餐事件狀態
    if (eventStatus != null && _eventStatus != eventStatus) {
      _eventStatus = eventStatus;
      changed = true;
    }

    // 新增：更新預訂人姓名
    if (reservationName != null && _reservationName != reservationName) {
      _reservationName = reservationName;
      changed = true;
    }

    // 新增：更新預訂人電話
    if (reservationPhone != null && _reservationPhone != reservationPhone) {
      _reservationPhone = reservationPhone;
      changed = true;
    }

    // 更新餐廳詳細信息
    if (restaurantInfo != null) {
      // 由於Map的比較較複雜，這裡簡單判斷是否需要更新
      if (_restaurantInfo == null ||
          json.encode(_restaurantInfo) != json.encode(restaurantInfo)) {
        _restaurantInfo = restaurantInfo;
        changed = true;
      }
    }

    // 新增：更新幫忙訂位狀態
    if (isHelpingWithReservation != null &&
        _isHelpingWithReservation != isHelpingWithReservation) {
      _isHelpingWithReservation = isHelpingWithReservation;

      // 當設置為true時，同時設置開始時間
      if (isHelpingWithReservation && helpingReservationStartTime == null) {
        _helpingReservationStartTime = DateTime.now();
        debugPrint(
          '在updateStatus中設置幫忙訂位開始時間: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_helpingReservationStartTime!)}',
        );
      } else if (!isHelpingWithReservation) {
        _helpingReservationStartTime = null;
        debugPrint('在updateStatus中清除幫忙訂位開始時間');
      }

      changed = true;
      debugPrint('已更新幫忙訂位狀態為: $isHelpingWithReservation');
    }

    // 新增：更新幫忙訂位開始時間
    if (helpingReservationStartTime != null &&
        _helpingReservationStartTime != helpingReservationStartTime) {
      _helpingReservationStartTime = helpingReservationStartTime;
      changed = true;
      debugPrint(
        '已更新幫忙訂位開始時間: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_helpingReservationStartTime!)}',
      );
    }

    // 更新用餐人數
    if (attendees != null) {
      _attendees = attendees;
      debugPrint('已更新用餐人數: $attendees');
    }

    if (changed) {
      _saveToPrefs();
      notifyListeners();
    }
  }

  // 重置所有聚餐相關資料
  Future<void> resetDiningData() async {
    _confirmedDinnerTime = null;
    _dinnerRestaurantId = null;
    _replyDeadline = null;
    _cancelDeadline = null;
    _matchingGroupId = null;
    _diningEventId = null;
    _restaurantInfo = null;
    _eventStatus = null;
    _reservationName = null;
    _reservationPhone = null;
    _isHelpingWithReservation = false;
    _helpingReservationStartTime = null;
    _attendees = null;

    await _saveToPrefs();
    notifyListeners();
    debugPrint('已重置所有聚餐相關資料');
  }

  // 用於測試持久化邏輯的方法
  Future<bool> testPersistence() async {
    try {
      // 儲存一個測試時間到 SharedPreferences
      final testTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();

      // 寫入測試數據
      await prefs.setInt('test_time', testTime.millisecondsSinceEpoch);
      debugPrint(
        '寫入測試時間: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(testTime)}',
      );

      // 讀取測試數據
      final storedTimeMillis = prefs.getInt('test_time');
      if (storedTimeMillis == null) {
        debugPrint('無法讀取測試時間');
        return false;
      }

      final storedTime = DateTime.fromMillisecondsSinceEpoch(storedTimeMillis);
      debugPrint(
        '讀取測試時間: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(storedTime)}',
      );

      // 清除測試數據
      await prefs.remove('test_time');

      // 檢查時間是否匹配 (允許最多 1 秒的差異)
      final difference = storedTime.difference(testTime).inMilliseconds.abs();
      final isMatch = difference < 1000;

      debugPrint('測試結果: ${isMatch ? '成功' : '失敗'}, 時間差異: $difference 毫秒');
      return isMatch;
    } catch (e) {
      debugPrint('測試持久化邏輯時出錯: $e');
      return false;
    }
  }
}
