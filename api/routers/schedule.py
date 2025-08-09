from fastapi import APIRouter, Depends, HTTPException, status
from supabase import Client
from datetime import datetime, timedelta, timezone, time as dtime, date as ddate
from typing import Dict, Any, List, Tuple
import pytz

from dependencies import get_supabase_service, verify_cron_api_key

router = APIRouter()

# 與前端/後端其他邏輯一致，採用台灣時區
TW_TZ = pytz.timezone("Asia/Taipei")


def _get_iso_week_number(dt: datetime) -> int:
    # 使用 dinner_time_utils 的邏輯：以 ISO 週數為準
    from datetime import datetime as _dt
    date = _dt(dt.year, dt.month, dt.day)
    day_of_year = (date - _dt(date.year, 1, 1)).days + 1
    day_of_week = date.isoweekday()
    week_number = ((day_of_year - day_of_week + 10) // 7)
    if week_number < 1:
        last_day_prev_year = _dt(date.year - 1, 12, 31)
        return _get_iso_week_number(last_day_prev_year)
    elif week_number == 53:
        jan1_next_year = _dt(date.year + 1, 1, 1)
        if 1 <= jan1_next_year.isoweekday() <= 4:
            return 1
        else:
            return 53
    else:
        return week_number


def _is_single_week(dt: datetime) -> bool:
    return _get_iso_week_number(dt) % 2 == 1


def _target_dinner_weekday(dt: datetime) -> int:
    # 單數週：星期一(1)；雙數週：星期四(4)
    return 1 if _is_single_week(dt) else 4


def _localize(year: int, month: int, day: int, hour: int, minute: int) -> datetime:
    return TW_TZ.localize(datetime(year, month, day, hour, minute))


def _to_utc_iso(dt_local: datetime) -> str:
    return dt_local.astimezone(timezone.utc).isoformat()


@router.post("/generate", dependencies=[Depends(verify_cron_api_key)])
async def generate_schedule(
    supabase: Client = Depends(get_supabase_service)
) -> Dict[str, Any]:
    """
    依單數週/雙數週規則產生未來排程：
    - 單數週：聚餐為週一 18:00（台北時間）
      * match：週六 06:00（兩天前早上六點）
      * restaurant_vote_end：週日 06:00（match 後 24 小時）
      * event_end：週一 22:00（聚餐後 4 小時）
      * rating_end：週三 22:00（event_end 後 48 小時）
    - 雙數週：聚餐為週四 18:00（台北時間）
      * match：週二 06:00
      * restaurant_vote_end：週三 06:00
      * event_end：週四 22:00
      * rating_end：週六 22:00

    若 schedule_table 覆蓋不足未來 14 天，則一次補齊到未來 30 天。
    """
    try:
        now_utc = datetime.now(timezone.utc)
        now_local = now_utc.astimezone(TW_TZ)

        # 取得 schedule_table 目前最後的排程時間
        last_row = (
            supabase.table("schedule_table")
            .select("scheduled_time")
            .order("scheduled_time", desc=True)
            .limit(1)
            .execute()
        )

        latest_time_utc: datetime | None = None
        if last_row.data:
            raw = last_row.data[0].get("scheduled_time")
            try:
                latest_time_utc = datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
                if latest_time_utc.tzinfo is None:
                    latest_time_utc = latest_time_utc.replace(tzinfo=timezone.utc)
            except Exception:
                latest_time_utc = None

        ensure_until_utc = now_utc + timedelta(days=14)
        generate_until_utc = now_utc + timedelta(days=30)

        if latest_time_utc and latest_time_utc >= ensure_until_utc:
            return {
                "success": True,
                "message": "未來排程數量充足，無需新增",
                "latest_scheduled_time": latest_time_utc.isoformat(),
                "created": 0,
            }

        # 從（最新已排程時間 + 1 天）的當地午夜開始，或今天起
        start_local_date: ddate = (
            latest_time_utc.astimezone(TW_TZ).date() + timedelta(days=1)
            if latest_time_utc else now_local.date()
        )
        end_local_date: ddate = generate_until_utc.astimezone(TW_TZ).date()

        to_insert: List[Dict[str, Any]] = []
        current = start_local_date
        while current <= end_local_date:
            # 依當地日期決定該週聚餐日
            current_dt_local = TW_TZ.localize(datetime(current.year, current.month, current.day, 0, 0))
            target_weekday = _target_dinner_weekday(current_dt_local)  # 1=Mon,4=Thu

            # 找到該週的週一
            weekday = current_dt_local.isoweekday()
            this_week_monday = current_dt_local - timedelta(days=weekday - 1)
            dinner_day_local = this_week_monday + timedelta(days=target_weekday - 1)

            # 聚餐時間 18:00（台北）
            dinner_time_local = _localize(dinner_day_local.year, dinner_day_local.month, dinner_day_local.day, 18, 0)

            # match = 聚餐日 - 2 天 的 06:00
            match_day = dinner_time_local.date() - timedelta(days=2)
            match_local = _localize(match_day.year, match_day.month, match_day.day, 6, 0)

            # restaurant_vote_end = match 後 24 小時 → 聚餐日 - 1 天 的 06:00
            vote_day = dinner_time_local.date() - timedelta(days=1)
            vote_local = _localize(vote_day.year, vote_day.month, vote_day.day, 6, 0)

            # event_end = 聚餐當日 22:00
            event_end_local = _localize(dinner_time_local.year, dinner_time_local.month, dinner_time_local.day, 22, 0)

            # rating_end = event_end 後 48 小時 → 次次日 22:00
            rating_base = event_end_local + timedelta(hours=48)
            rating_end_local = _localize(rating_base.year, rating_base.month, rating_base.day, 22, 0)

            # 加入四個任務（僅加入在當前 now_utc 之後的）
            for task_type, dt_local in [
                ("match", match_local),
                ("restaurant_vote_end", vote_local),
                ("event_end", event_end_local),
                ("rating_end", rating_end_local),
            ]:
                dt_utc = dt_local.astimezone(timezone.utc)
                if dt_utc > now_utc:
                    to_insert.append({
                        "task_type": task_type,
                        "scheduled_time": dt_utc.isoformat(),
                        "status": "pending",
                    })

            current += timedelta(days=1)

        created = 0
        if to_insert:
            # upsert 避免重複
            resp = (
                supabase.table("schedule_table")
                .upsert(to_insert, on_conflict="task_type,scheduled_time")
                .execute()
            )
            created = len(resp.data) if getattr(resp, "data", None) else 0

        return {
            "success": True,
            "message": "排程生成完成",
            "created": created,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
        }

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"產生排程時發生錯誤: {str(e)}",
        )


