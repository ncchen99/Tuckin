import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tuckin/services/services.dart';

/// 頁面階段狀態
enum DinnerPageStage {
  reserve, // 預約階段
  nextWeek, // 顯示下週聚餐
}

/// 聚餐時間信息類
class DinnerTimeInfo {
  /// 下次聚餐日期
  final DateTime nextDinnerDate;

  /// 聚餐時間 (年月日時分)
  final DateTime nextDinnerTime;

  /// 是否為單周（顯示星期一）
  final bool isSingleWeek;

  /// 顯示星期幾文字
  final String weekdayText;

  /// 當前頁面階段
  final DinnerPageStage currentStage;

  /// 預約取消截止時間
  final DateTime cancelDeadline;

  /// 參加階段開始時間
  final DateTime joinPhaseStart;

  /// 參加階段結束時間
  final DateTime joinPhaseEnd;

  DinnerTimeInfo({
    required this.nextDinnerDate,
    required this.nextDinnerTime,
    required this.isSingleWeek,
    required this.weekdayText,
    required this.currentStage,
    required this.cancelDeadline,
    required this.joinPhaseStart,
    required this.joinPhaseEnd,
  });
}

/// 聚餐時間計算工具類
class DinnerTimeUtils {
  /// 正確解析可能包含時區資訊的時間字串
  /// 如果時間字串包含時區資訊，將其轉換為本地時間
  /// 如果沒有時區資訊，假設是台灣時區(UTC+8)並轉換為本地時間
  static DateTime parseTimezoneAwareDateTime(String dateTimeString) {
    if (dateTimeString.contains('+') || dateTimeString.endsWith('Z')) {
      // 如果包含時區資訊，先轉換為 UTC 再轉為本地時間
      return DateTime.parse(dateTimeString).toLocal();
    } else {
      // 如果沒有時區資訊，假設是 UTC+8 (台灣時區)
      final utcTime = DateTime.parse(dateTimeString);
      return utcTime
          .subtract(const Duration(hours: 8))
          .toLocal()
          .add(const Duration(hours: 8));
    }
  }

  /// 獲取當前ISO 8601週數
  static int getIsoWeekNumber(DateTime date) {
    int dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    int dayOfWeek = date.weekday; // Monday = 1, Sunday = 7

    // Formula based on ISO 8601 standard
    int weekNumber = ((dayOfYear - dayOfWeek + 10) / 7).floor();

    if (weekNumber < 1) {
      // Belongs to the last week of the previous year.
      DateTime lastDayOfPrevYear = DateTime(date.year - 1, 12, 31);
      return getIsoWeekNumber(
        lastDayOfPrevYear,
      ); // Recurse for previous year's last week
    } else if (weekNumber == 53) {
      // Check if it should actually be week 1 of the next year.
      // This happens if Jan 1 of next year is a Monday, Tuesday, Wednesday, or Thursday.
      DateTime jan1NextYear = DateTime(date.year + 1, 1, 1);
      if (jan1NextYear.weekday >= DateTime.monday &&
          jan1NextYear.weekday <= DateTime.thursday) {
        // It's week 1 of the next year.
        return 1;
      } else {
        // It's genuinely week 53.
        return 53;
      }
    } else {
      // It's a regular week number (1-52).
      return weekNumber;
    }
  }

  /// 計算下次聚餐時間信息
  static DinnerTimeInfo calculateDinnerTimeInfo({String? userStatus}) {
    final now = TimeService().now();
    final currentDay = now.weekday;

    // 計算當前是第幾週（使用 ISO 8601 標準）
    final int weekNumber = getIsoWeekNumber(now);

    // 判斷當前週是單數週還是雙數週
    final bool isSingleWeek = weekNumber % 2 == 1;

    // 計算本週的聚餐日期 (先計算本週的開始日期，然後加上對應的天數)
    final int targetWeekday =
        isSingleWeek ? DateTime.monday : DateTime.thursday;

    // 計算本週日期 (回到本週日，然後加上目標天數)
    // 先計算到本週日的天數 (週日是7，週一是1，所以用7減週幾)
    int daysToSunday =
        currentDay == DateTime.sunday ? 0 : (DateTime.sunday - currentDay);

    // 本週日的日期
    DateTime thisWeekSunday = now.subtract(Duration(days: 7 - daysToSunday));

    // 本週的目標聚餐日（計算用，但實際選擇邏輯在後面）
    // DateTime thisWeekTarget = thisWeekSunday.add(Duration(days: targetWeekday));

    // 計算下一週的週數
    final int nextWeekNumber = weekNumber + 1;
    // 判斷下一週是單數週還是雙數週
    final bool isNextWeekSingle = nextWeekNumber % 2 == 1;
    // 設定下一週的目標聚餐日是星期一還是星期四
    final int nextTargetWeekday =
        isNextWeekSingle ? DateTime.monday : DateTime.thursday;
    // 下一週的星期日
    final DateTime nextWeekSunday = thisWeekSunday.add(const Duration(days: 7));
    // 下週的目標聚餐日
    DateTime nextWeekTarget = nextWeekSunday.add(
      Duration(days: nextTargetWeekday),
    );

    // 計算下下週的目標聚餐日
    final int afterNextWeekNumber = weekNumber + 2;
    final bool isAfterNextWeekSingle = afterNextWeekNumber % 2 == 1;
    final int afterNextTargetWeekday =
        isAfterNextWeekSingle ? DateTime.monday : DateTime.thursday;
    final DateTime afterNextWeekSunday = thisWeekSunday.add(
      const Duration(days: 14),
    );
    DateTime afterNextWeekTarget = afterNextWeekSunday.add(
      Duration(days: afterNextTargetWeekday),
    );

    // 先計算本週的聚餐日期
    final DateTime currentWeekTarget = thisWeekSunday.add(
      Duration(days: targetWeekday),
    );

    // 先決定要顯示的聚餐日期（這週、下週或下下週）
    // 如果距離聚餐時間小於61小時（相當於聚餐日前兩天+13小時，即前兩天早上6點）
    DateTime dinnerDateTime = DateTime(
      currentWeekTarget.year,
      currentWeekTarget.month,
      currentWeekTarget.day,
      18, // 聚餐時間：晚上6點
      0,
    );
    Duration timeUntilDinner = dinnerDateTime.difference(now);

    // 計算下週聚餐的時間
    DateTime nextDinnerDateTime = DateTime(
      nextWeekTarget.year,
      nextWeekTarget.month,
      nextWeekTarget.day,
      18, // 聚餐時間：晚上6點
      0,
    );
    Duration timeUntilNextDinner = nextDinnerDateTime.difference(now);

    DateTime selectedDinnerDate;

    // 決定要顯示哪一週的聚餐
    if (now.isAfter(currentWeekTarget) || timeUntilDinner.inHours < 60) {
      // 已經過了本週聚餐或距離本週聚餐時間小於60小時 (即聚餐前兩天早上6點之後)
      if (now.isAfter(nextWeekTarget) || timeUntilNextDinner.inHours < 60) {
        // 如果下週聚餐也已經過了或時間也太接近，則顯示下下週聚餐
        selectedDinnerDate = afterNextWeekTarget;
        debugPrint('選擇下下週聚餐，因為本週和下週聚餐時間太近，使用下下週的日期計算相關時間');
      } else {
        // 顯示下週聚餐
        selectedDinnerDate = nextWeekTarget;
        debugPrint('選擇下週聚餐，因為本週聚餐時間太近，使用下週的日期計算相關時間');
      }
    } else {
      // 顯示本週聚餐
      selectedDinnerDate = currentWeekTarget;
      debugPrint('選擇本週聚餐，使用本週的日期計算相關時間');
    }

    // 計算聚餐時間
    final DateTime dinnerTime = DateTime(
      selectedDinnerDate.year,
      selectedDinnerDate.month,
      selectedDinnerDate.day,
      18, // 聚餐時間：晚上6點
      0,
    );

    // 根據選定的聚餐日期計算參加階段的開始時間和結束時間
    // 參加階段開始：聚餐前60小時 (即聚餐前兩天+13小時，前兩天早上6點)
    // 參加階段結束：聚餐前36小時 (即聚餐前一天+13小時，前一天早上6點)
    DateTime joinPhaseStart = dinnerTime.subtract(const Duration(hours: 60));
    DateTime joinPhaseEnd = dinnerTime.subtract(const Duration(hours: 36));

    // 計算取消預約的截止時間 (與joinPhaseStart相同，即聚餐前兩天早上6點)
    // 這是一個重要時間點，用戶必須在此時間前取消預約，否則將計入缺席紀錄
    DateTime cancelDeadline = joinPhaseStart;

    // 根據聚餐日期設定星期幾文字
    String weekdayText = '';
    if (selectedDinnerDate.weekday == DateTime.monday) {
      weekdayText = '星期一';
    } else if (selectedDinnerDate.weekday == DateTime.thursday) {
      weekdayText = '星期四';
    } else {
      // 處理潛在錯誤，雖然正常情況下不應發生
      weekdayText = '未知';
      debugPrint('錯誤：計算出的聚餐日既不是星期一也不是星期四: $selectedDinnerDate');
    }

    // 確定當前頁面階段
    DinnerPageStage currentStage;

    // 如果提供了用戶狀態且不是booking，則顯示下週聚餐
    if (userStatus != null && userStatus != 'booking') {
      currentStage = DinnerPageStage.nextWeek;
    } else {
      // 全部統一為預約階段，移除參加階段邏輯
      currentStage = DinnerPageStage.reserve;
    }

    // 打印調試信息
    debugPrint('當前週數: $weekNumber (${isSingleWeek ? "單週" : "雙週"})');
    debugPrint('當前階段: $currentStage');
    debugPrint(
      '選擇的聚餐日期: ${DateFormat('yyyy-MM-dd').format(selectedDinnerDate)} ($weekdayText)',
    );
    debugPrint('聚餐時間: ${DateFormat('yyyy-MM-dd HH:mm').format(dinnerTime)}');
    debugPrint(
      '參加階段開始: ${DateFormat('yyyy-MM-dd HH:mm').format(joinPhaseStart)}',
    );
    debugPrint(
      '參加階段結束: ${DateFormat('yyyy-MM-dd HH:mm').format(joinPhaseEnd)}',
    );
    debugPrint(
      '取消預約截止時間: ${DateFormat('yyyy-MM-dd HH:mm').format(cancelDeadline)}',
    );

    return DinnerTimeInfo(
      nextDinnerDate: selectedDinnerDate,
      nextDinnerTime: dinnerTime,
      isSingleWeek: isSingleWeek,
      weekdayText: weekdayText,
      currentStage: currentStage,
      cancelDeadline: cancelDeadline,
      joinPhaseStart: joinPhaseStart,
      joinPhaseEnd: joinPhaseEnd,
    );
  }

  /// 為聚餐流程提供穩定的聚餐時間計算（聚餐後+4小時才切換）
  /// 規則：只有在當週聚餐時間過後 4 小時，才會切換到「下週」的聚餐日期；
  /// 否則（含聚餐前與聚餐後 4 小時內）都顯示「本週」的聚餐日期與時間。
  static DinnerTimeInfo calculateDinnerTimeInfoForFlow() {
    final now = TimeService().now();

    // 依據目前時間判斷本週是單/雙週，進而決定聚餐是週一或週四
    final int weekNumber = getIsoWeekNumber(now);
    final bool isSingleWeek = weekNumber % 2 == 1;
    final int targetWeekday =
        isSingleWeek ? DateTime.monday : DateTime.thursday;

    // 計算本週日（沿用現有演算法以保持一致性）
    final int currentDay = now.weekday;
    int daysToSunday =
        currentDay == DateTime.sunday ? 0 : (DateTime.sunday - currentDay);
    DateTime thisWeekSunday = now.subtract(Duration(days: 7 - daysToSunday));

    // 本週的聚餐日期與時間（18:00）
    final DateTime currentWeekTarget = thisWeekSunday.add(
      Duration(days: targetWeekday),
    );
    final DateTime currentDinnerTime = DateTime(
      currentWeekTarget.year,
      currentWeekTarget.month,
      currentWeekTarget.day,
      18,
      0,
    );

    // 下週的聚餐日期與時間（18:00）
    final int nextWeekNumber = weekNumber + 1;
    final bool isNextWeekSingle = nextWeekNumber % 2 == 1;
    final int nextTargetWeekday =
        isNextWeekSingle ? DateTime.monday : DateTime.thursday;
    final DateTime nextWeekSunday = thisWeekSunday.add(const Duration(days: 7));
    final DateTime nextWeekTarget = nextWeekSunday.add(
      Duration(days: nextTargetWeekday),
    );
    final DateTime nextDinnerTime = DateTime(
      nextWeekTarget.year,
      nextWeekTarget.month,
      nextWeekTarget.day,
      18,
      0,
    );

    // 切換門檻：當週聚餐時間 + 4 小時
    final DateTime switchToNextThreshold = currentDinnerTime.add(
      const Duration(hours: 4),
    );

    DateTime selectedDinnerDate;
    DateTime selectedDinnerTime;

    if (now.isAfter(switchToNextThreshold)) {
      // 超過當週聚餐時間 + 4 小時 → 顯示下週
      selectedDinnerDate = nextWeekTarget;
      selectedDinnerTime = nextDinnerTime;
      debugPrint('流程模式：已超過當週聚餐+4小時，顯示下週聚餐');
    } else {
      // 其餘時間（包含聚餐前與聚餐後 4 小時內）→ 顯示本週
      selectedDinnerDate = currentWeekTarget;
      selectedDinnerTime = currentDinnerTime;
      debugPrint('流程模式：尚未超過當週聚餐+4小時，顯示本週聚餐');
    }

    // 仍沿用既有欄位計算，方便前端共用顯示
    final DateTime joinPhaseStart = selectedDinnerTime.subtract(
      const Duration(hours: 60),
    );
    final DateTime joinPhaseEnd = selectedDinnerTime.subtract(
      const Duration(hours: 36),
    );
    final DateTime cancelDeadline = joinPhaseStart;

    String weekdayText = '';
    if (selectedDinnerDate.weekday == DateTime.monday) {
      weekdayText = '星期一';
    } else if (selectedDinnerDate.weekday == DateTime.thursday) {
      weekdayText = '星期四';
    } else {
      weekdayText = '未知';
      debugPrint('錯誤：流程模式計算的聚餐日既不是星期一也不是星期四: $selectedDinnerDate');
    }

    // 流程模式不區分頁面階段，固定為預約階段以維持 UI 一致
    const DinnerPageStage currentStage = DinnerPageStage.reserve;

    debugPrint(
      '流程模式 - 選擇的聚餐日期: ${DateFormat('yyyy-MM-dd').format(selectedDinnerDate)} ($weekdayText)',
    );
    debugPrint(
      '流程模式 - 聚餐時間: ${DateFormat('yyyy-MM-dd HH:mm').format(selectedDinnerTime)}',
    );
    debugPrint(
      '流程模式 - 切換門檻(聚餐+4h): ${DateFormat('yyyy-MM-dd HH:mm').format(switchToNextThreshold)}',
    );

    return DinnerTimeInfo(
      nextDinnerDate: selectedDinnerDate,
      nextDinnerTime: selectedDinnerTime,
      isSingleWeek: isSingleWeek,
      weekdayText: weekdayText,
      currentStage: currentStage,
      cancelDeadline: cancelDeadline,
      joinPhaseStart: joinPhaseStart,
      joinPhaseEnd: joinPhaseEnd,
    );
  }

  // ================== 時間格式化方法 ==================

  /// 獲取星期幾的中文全稱
  static String getWeekdayText(DateTime? dateTime) {
    if (dateTime == null) return '星期待定';
    final weekdayNames = ['', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return weekdayNames[dateTime.weekday];
  }

  /// 獲取星期幾的中文簡稱
  static String getWeekdayShort(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final weekdayNames = ['', '一', '二', '三', '四', '五', '六', '日'];
    return weekdayNames[dateTime.weekday];
  }

  /// 格式化聚餐時間為可讀字符串
  static String formatDinnerTime(DateTime? dateTime) {
    if (dateTime == null) return '未確定';
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }

  /// 格式化取消截止時間為可讀字符串
  static String formatCancelDeadline(DateTime? dateTime) {
    if (dateTime == null) return '未確定';
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }

  /// 獲取格式化的聚餐日期（M月d日）
  static String formatDinnerDate(DateTime? dateTime) {
    if (dateTime == null) return '--月--日';
    return DateFormat('M 月 d 日').format(dateTime);
  }

  /// 獲取格式化的聚餐時間（HH:mm）
  static String formatDinnerTimeOnly(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 獲取聚餐日期的完整描述（M月d日（weekday）HH:mm）
  static String getFullDinnerTimeDescription(DateTime? dateTime) {
    if (dateTime == null) return '-- 月 -- 日（-）--:--';
    final weekdayShort = getWeekdayShort(dateTime);
    final timeOnly = formatDinnerTimeOnly(dateTime);
    return '${dateTime.month}月${dateTime.day}日（$weekdayShort）$timeOnly';
  }

  /// 獲取聚餐日期與時間的簡潔描述（M月d日 HH:mm）
  static String getDinnerTimeDescriptionSimple(DateTime? dateTime) {
    if (dateTime == null) return '時間待定';
    final timeOnly = formatDinnerTimeOnly(dateTime);
    return '${dateTime.month}月${dateTime.day}日 $timeOnly';
  }

  /// 獲取取消截止時間的完整描述（M月d日(weekday) HH:mm 前可以取消預約）
  static String getCancelDeadlineDescription(DateTime? cancelDeadline) {
    if (cancelDeadline == null) return '計算中...';
    final weekdayNames = ['', '一', '二', '三', '四', '五', '六', '日'];
    final weekdayText = weekdayNames[cancelDeadline.weekday];
    final cancelTime =
        '${cancelDeadline.hour}:${cancelDeadline.minute.toString().padLeft(2, '0')}';
    return '${cancelDeadline.month}月${cancelDeadline.day}日($weekdayText) $cancelTime 前可以取消預約';
  }
}
