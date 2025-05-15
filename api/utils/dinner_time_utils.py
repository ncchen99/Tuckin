from datetime import datetime, timedelta
import enum
import pytz

# 設定臺灣時區
TW_TIMEZONE = pytz.timezone('Asia/Taipei')

# 頁面階段狀態
class DinnerPageStage(enum.Enum):
    RESERVE = "reserve"  # 預約階段
    NEXT_WEEK = "nextWeek"  # 顯示下週聚餐

# 聚餐時間信息類
class DinnerTimeInfo:
    def __init__(
        self,
        next_dinner_date,
        next_dinner_time,
        is_single_week,
        weekday_text,
        current_stage,
        cancel_deadline,
        restaurant_selection_start,
        restaurant_selection_end,
        questionnaire_notification_time,
    ):
        self.next_dinner_date = next_dinner_date  # 下次聚餐日期
        self.next_dinner_time = next_dinner_time  # 聚餐時間 (年月日時分)
        self.is_single_week = is_single_week  # 是否為單周（顯示星期一）
        self.weekday_text = weekday_text  # 顯示星期幾文字
        self.current_stage = current_stage  # 當前頁面階段
        self.cancel_deadline = cancel_deadline  # 預約取消截止時間
        self.restaurant_selection_start = restaurant_selection_start  # 餐廳選擇時段開始時間
        self.restaurant_selection_end = restaurant_selection_end  # 餐廳選擇時段結束時間
        self.questionnaire_notification_time = questionnaire_notification_time  # 聚餐后問卷推播時間

    def to_dict(self):
        """將對象轉換為字典格式"""
        return {
            "next_dinner_date": self.next_dinner_date.isoformat(),
            "next_dinner_time": self.next_dinner_time.isoformat(),
            "is_single_week": self.is_single_week,
            "weekday_text": self.weekday_text,
            "current_stage": self.current_stage.value,
            "cancel_deadline": self.cancel_deadline.isoformat(),
            "restaurant_selection_start": self.restaurant_selection_start.isoformat(),
            "restaurant_selection_end": self.restaurant_selection_end.isoformat(),
            "questionnaire_notification_time": self.questionnaire_notification_time.isoformat(),
        }

# 聚餐時間計算工具類
class DinnerTimeUtils:
    @staticmethod
    def get_iso_week_number(date):
        """獲取當前ISO 8601週數"""
        day_of_year = (date - datetime(date.year, 1, 1)).days + 1
        day_of_week = date.isoweekday()  # Monday = 1, Sunday = 7

        # Formula based on ISO 8601 standard
        week_number = ((day_of_year - day_of_week + 10) // 7)

        if week_number < 1:
            # Belongs to the last week of the previous year.
            last_day_of_prev_year = datetime(date.year - 1, 12, 31)
            return DinnerTimeUtils.get_iso_week_number(last_day_of_prev_year)
        elif week_number == 53:
            # Check if it should actually be week 1 of the next year.
            # This happens if Jan 1 of next year is a Monday, Tuesday, Wednesday, or Thursday.
            jan1_next_year = datetime(date.year + 1, 1, 1)
            if 1 <= jan1_next_year.isoweekday() <= 4:
                # It's week 1 of the next year.
                return 1
            else:
                # It's genuinely week 53.
                return 53
        else:
            # It's a regular week number (1-52).
            return week_number

    @staticmethod
    def calculate_dinner_time_info(user_status=None):
        """計算下次聚餐時間信息"""
        # 獲取臺灣當前時間
        now = datetime.now(TW_TIMEZONE)
        current_day = now.isoweekday()

        # 計算當前是第幾週（使用 ISO 8601 標準）
        week_number = DinnerTimeUtils.get_iso_week_number(now.replace(tzinfo=None))

        # 判斷當前週是單數週還是雙數週
        is_single_week = week_number % 2 == 1

        # 計算本週的聚餐日期
        target_weekday = 1 if is_single_week else 4  # 1=星期一, 4=星期四

        # 計算本週日期
        # 先計算到本週一的天數 (週日是7，週一是1，所以用當前日期 - 週幾 + 1)
        days_to_monday = 0 if current_day == 1 else (current_day - 1)
        # 本週一的日期
        this_week_monday = now.replace(tzinfo=None) - timedelta(days=days_to_monday)
        
        # 本週的目標聚餐日 (從本週一開始計算)
        this_week_target = this_week_monday + timedelta(days=(target_weekday - 1))

        # 計算下一週的週數
        next_week_number = week_number + 1
        # 判斷下一週是單數週還是雙數週
        is_next_week_single = next_week_number % 2 == 1
        # 設定下一週的目標聚餐日是星期一還是星期四
        next_target_weekday = 1 if is_next_week_single else 4
        # 下一週的週一
        next_week_monday = this_week_monday + timedelta(days=7)
        # 下週的目標聚餐日 (從下週一開始計算)
        next_week_target = next_week_monday + timedelta(days=(next_target_weekday - 1))

        # 計算下下週的目標聚餐日
        after_next_week_number = week_number + 2
        is_after_next_week_single = after_next_week_number % 2 == 1
        after_next_target_weekday = 1 if is_after_next_week_single else 4
        after_next_week_monday = this_week_monday + timedelta(days=14)
        after_next_week_target = after_next_week_monday + timedelta(days=(after_next_target_weekday - 1))

        # 先計算本週的聚餐日期 (已在上面計算為 this_week_target)
        current_week_target = this_week_target

        # 決定要顯示的聚餐日期（這週、下週或下下週）
        # 根據用戶要求，只需判斷聚餐時間是否已過或即將到來
        dinner_date_time = datetime(
            current_week_target.year,
            current_week_target.month,
            current_week_target.day,
            18,  # 聚餐時間：晚上6點
            0,
        )
        # 將時間設置為臺灣時區
        dinner_date_time = TW_TIMEZONE.localize(dinner_date_time)

        # 計算距離聚餐時間的小時數
        time_until_dinner = dinner_date_time - now
        time_until_dinner_hours = time_until_dinner.total_seconds() / 3600

        # 修改判斷邏輯：判斷當前時間是否已過本週聚餐時間或距離聚餐時間小於61小時
        if now > dinner_date_time or time_until_dinner_hours < 61:
            # 如果已經過了本週聚餐時間或時間太近，顯示下週聚餐
            dinner_date_time = TW_TIMEZONE.localize(datetime(
                next_week_target.year,
                next_week_target.month,
                next_week_target.day,
                18,  # 聚餐時間：晚上6點
                0,
            ))
            selected_dinner_date = next_week_target
            
            # 計算距離下週聚餐時間的小時數
            time_until_next_dinner = dinner_date_time - now
            time_until_next_dinner_hours = time_until_next_dinner.total_seconds() / 3600
            
            # 如果下週聚餐時間也已過或時間太近
            if now > dinner_date_time or time_until_next_dinner_hours < 61:
                dinner_date_time = TW_TIMEZONE.localize(datetime(
                    after_next_week_target.year,
                    after_next_week_target.month,
                    after_next_week_target.day,
                    18,  # 聚餐時間：晚上6點
                    0,
                ))
                selected_dinner_date = after_next_week_target
                print('選擇下下週聚餐，因為下週聚餐時間也過近')
            else:
                print('選擇下週聚餐，因為本週聚餐時間過近')
        else:
            # 顯示本週聚餐
            selected_dinner_date = current_week_target
            print('選擇本週聚餐')

        # 根據選定的聚餐日期計算餐廳選擇時段的開始時間和結束時間
        # 餐廳選擇時段開始：聚餐前60小時
        # 餐廳選擇時段結束：聚餐前36小時
        restaurant_selection_start = dinner_date_time - timedelta(hours=60)
        restaurant_selection_end = dinner_date_time - timedelta(hours=36)

        # 計算取消預約的截止時間
        cancel_deadline = TW_TIMEZONE.localize(datetime(
            selected_dinner_date.year,
            selected_dinner_date.month,
            selected_dinner_date.day,
            6,  # 早上6點
            0,
        ) - timedelta(days=2))

        # 計算聚餐后問卷推播時間（聚餐后4小時）
        questionnaire_notification_time = dinner_date_time + timedelta(hours=4)

        # 根據聚餐日期設定星期幾文字
        weekday_map = {
            1: "星期一",
            2: "星期二",
            3: "星期三",
            4: "星期四",
            5: "星期五",
            6: "星期六", 
            7: "星期日"
        }
        weekday_text = weekday_map.get(selected_dinner_date.isoweekday(), "未知")

        # 確定當前頁面階段
        if user_status is not None and user_status != 'booking':
            current_stage = DinnerPageStage.NEXT_WEEK
        else:
            current_stage = DinnerPageStage.RESERVE

        # 打印調試信息
        print(f'當前週數: {week_number} ({"單週" if is_single_week else "雙週"})')
        print(f'當前階段: {current_stage}')
        print(f'選擇的聚餐日期: {selected_dinner_date.strftime("%Y-%m-%d")} ({weekday_text})')
        print(f'聚餐時間: {dinner_date_time.strftime("%Y-%m-%d %H:%M")}')
        print(f'餐廳選擇時段開始: {restaurant_selection_start.strftime("%Y-%m-%d %H:%M")}')
        print(f'餐廳選擇時段結束: {restaurant_selection_end.strftime("%Y-%m-%d %H:%M")}')
        print(f'取消預約截止時間: {cancel_deadline.strftime("%Y-%m-%d %H:%M")}')
        print(f'聚餐后問卷推播時間: {questionnaire_notification_time.strftime("%Y-%m-%d %H:%M")}')

        return DinnerTimeInfo(
            next_dinner_date=selected_dinner_date,
            next_dinner_time=dinner_date_time,
            is_single_week=is_single_week,
            weekday_text=weekday_text,
            current_stage=current_stage,
            cancel_deadline=cancel_deadline,
            restaurant_selection_start=restaurant_selection_start,
            restaurant_selection_end=restaurant_selection_end,
            questionnaire_notification_time=questionnaire_notification_time,
        )

    @staticmethod
    def get_cancel_deadline_text(dinner_date):
        """取得取消預約截止日期的文字說明"""
        # 取得聚餐日期的前兩天早上6點（即預約取消截止時間）
        cancel_deadline = datetime(
            dinner_date.year,
            dinner_date.month,
            dinner_date.day,
            6,  # 早上6點
            0,
        ) - timedelta(days=2)

        # 確定是星期幾
        weekday_map = {
            1: "周一",
            2: "周二",
            3: "周三",
            4: "周四",
            5: "周五",
            6: "周六",
            7: "周日"
        }
        weekday_text = weekday_map.get(cancel_deadline.isoweekday(), "未知")

        return f'{weekday_text} 6:00 前可以取消預約'

    @staticmethod
    def should_run_matching_api():
        """判斷是否可以執行聚餐大配對API（在cancel_deadline時間點）"""
        # 獲取當前臺灣時間
        now = datetime.now(TW_TIMEZONE)
        
        # 計算下次聚餐信息
        dinner_info = DinnerTimeUtils.calculate_dinner_time_info()
        
        # 允許5分鐘的時間誤差
        time_error_margin = timedelta(minutes=5)
        
        # 判斷當前時間是否接近取消截止時間
        time_diff = abs(now - dinner_info.cancel_deadline)
        return time_diff <= time_error_margin

    @staticmethod
    def should_run_restaurant_selection_end_api():
        """判斷是否可以執行餐廳選擇時間截止時的統計API"""
        # 獲取當前臺灣時間
        now = datetime.now(TW_TIMEZONE)
        
        # 計算下次聚餐信息
        dinner_info = DinnerTimeUtils.calculate_dinner_time_info()
        
        # 允許5分鐘的時間誤差
        time_error_margin = timedelta(minutes=5)
        
        # 判斷當前時間是否接近餐廳選擇結束時間
        time_diff = abs(now - dinner_info.restaurant_selection_end)
        return time_diff <= time_error_margin

    @staticmethod
    def should_run_questionnaire_api():
        """判斷是否可以執行更改聚餐用戶狀態並推播問卷的API"""
        # 獲取當前臺灣時間
        now = datetime.now(TW_TIMEZONE)
        
        # 計算下次聚餐信息
        dinner_info = DinnerTimeUtils.calculate_dinner_time_info()
        
        # 允許5分鐘的時間誤差
        time_error_margin = timedelta(minutes=5)
        
        # 判斷當前時間是否接近問卷推播時間
        time_diff = abs(now - dinner_info.questionnaire_notification_time)
        return time_diff <= time_error_margin 