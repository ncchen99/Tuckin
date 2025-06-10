import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final now = DateTime.now();
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

    // 本週的目標聚餐日
    DateTime thisWeekTarget = thisWeekSunday.add(Duration(days: targetWeekday));

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
      // 已經過了本週聚餐或距離本週聚餐時間小於61小時 (即聚餐前兩天早上6點之後)
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
    // 參加階段結束：聚餐前37小時 (即聚餐前一天+13小時，前一天早上6點)
    DateTime joinPhaseStart = dinnerTime.subtract(const Duration(hours: 60));
    DateTime joinPhaseEnd = dinnerTime.subtract(const Duration(hours: 37));

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

  /// 取得取消預約截止日期的文字說明
  static String getCancelDeadlineText(DateTime dinnerDate) {
    // 取得聚餐日期的前兩天早上6點（即預約取消截止時間）
    DateTime cancelDeadline = DateTime(
      dinnerDate.year,
      dinnerDate.month,
      dinnerDate.day,
      6, // 早上6點
      0,
    ).subtract(const Duration(days: 2));

    // 確定是星期幾
    String weekdayText = '';
    switch (cancelDeadline.weekday) {
      case DateTime.monday:
        weekdayText = '周一';
        break;
      case DateTime.tuesday:
        weekdayText = '周二';
        break;
      case DateTime.wednesday:
        weekdayText = '周三';
        break;
      case DateTime.thursday:
        weekdayText = '周四';
        break;
      case DateTime.friday:
        weekdayText = '周五';
        break;
      case DateTime.saturday:
        weekdayText = '周六';
        break;
      case DateTime.sunday:
        weekdayText = '周日';
        break;
    }

    return '$weekdayText 6:00 前可以取消預約';
  }
}
