import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserStatusService with ChangeNotifier {
  DateTime? _confirmedDinnerTime;
  String? _dinnerRestaurantId;
  DateTime? _replyDeadline;
  DateTime? _cancelDeadline;

  // SharedPreferences 的鍵值
  static const String _confirmedDinnerTimeKey = 'confirmed_dinner_time';
  static const String _dinnerRestaurantIdKey = 'dinner_restaurant_id';
  static const String _replyDeadlineKey = 'reply_deadline';
  static const String _cancelDeadlineKey = 'cancel_deadline';

  UserStatusService() {
    _loadFromPrefs();
    debugPrint('UserStatusService 已創建，並開始從持久化存儲載入數據');
  }

  DateTime? get confirmedDinnerTime => _confirmedDinnerTime;
  String? get dinnerRestaurantId => _dinnerRestaurantId;
  DateTime? get replyDeadline => _replyDeadline;
  DateTime? get cancelDeadline => _cancelDeadline;

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

      debugPrint('從持久化儲存中載入 UserStatusService 資料:');
      if (_confirmedDinnerTime != null) {
        debugPrint('- 聚餐時間: ${formattedDinnerTime}');
      }
      if (_cancelDeadline != null) {
        debugPrint('- 取消截止時間: ${formattedCancelDeadline}');
        debugPrint('- 可以取消預約: ${canCancelReservation}');
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

      debugPrint('成功將 UserStatusService 資料儲存到持久化儲存');
    } catch (e) {
      debugPrint('儲存 UserStatusService 資料時出錯: $e');
    }
  }

  void updateStatus({
    DateTime? confirmedDinnerTime,
    String? dinnerRestaurantId,
    DateTime? replyDeadline,
    DateTime? cancelDeadline,
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

    if (changed) {
      notifyListeners();
      _saveToPrefs(); // 當資料更新時儲存到持久化儲存
      debugPrint('UserStatusService 狀態已更新並持久化:');
      if (_confirmedDinnerTime != null) {
        debugPrint('- 聚餐時間: ${formattedDinnerTime}');
      }
      if (_cancelDeadline != null) {
        debugPrint('- 取消截止時間: ${formattedCancelDeadline}');
        debugPrint('- 可以取消預約: ${canCancelReservation}');
      }
    }
  }

  void clearStatus() {
    _confirmedDinnerTime = null;
    _dinnerRestaurantId = null;
    _replyDeadline = null;
    _cancelDeadline = null;
    notifyListeners();
    _saveToPrefs(); // 清除持久化儲存的資料
    debugPrint('User status cleared and persistence data removed.');
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
