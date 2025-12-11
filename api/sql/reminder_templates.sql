-- 提醒訊息模板表
-- 用於存儲不同情境的提醒訊息，支持多樣化的通知內容

CREATE TABLE IF NOT EXISTS reminder_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- 提醒類型：booking_reminder（預約提醒）、attendance_reminder（出席提醒）
    reminder_type TEXT NOT NULL CHECK (reminder_type IN (
        'booking_reminder',      -- 預約聚餐提醒（match 前一天 9:00）
        'attendance_reminder'    -- 參加聚餐提醒（聚餐當天 9:00）
    )),
    
    -- 訊息風格/分類標籤
    style_tag TEXT,  -- 例如：'warm'(溫暖), 'fun'(活潑), 'urgent'(緊急)
    
    -- 通知標題
    title TEXT NOT NULL,
    
    -- 通知內容（支持佔位符：{time}, {location}, {date}, {restaurant_name}）
    body TEXT NOT NULL,
    
    -- 是否啟用
    is_active BOOLEAN DEFAULT TRUE,
    
    -- 權重（用於隨機選擇時的權重分配，數字越大被選中機率越高）
    weight INTEGER DEFAULT 1 CHECK (weight >= 1),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 建立索引
CREATE INDEX IF NOT EXISTS idx_reminder_templates_type ON reminder_templates(reminder_type);
CREATE INDEX IF NOT EXISTS idx_reminder_templates_active ON reminder_templates(is_active);

-- 為 reminder_templates 表啟用 RLS
ALTER TABLE reminder_templates ENABLE ROW LEVEL SECURITY;

-- 只有服務角色可以完全訪問
CREATE POLICY service_all_reminder_templates ON reminder_templates
FOR ALL TO authenticated
USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');

-- 更新 schedule_table 的 task_type 約束，新增兩種提醒類型
ALTER TABLE schedule_table
DROP CONSTRAINT IF EXISTS schedule_table_task_type_check;

ALTER TABLE schedule_table
ADD CONSTRAINT schedule_table_task_type_check
CHECK (task_type IN (
    'match',                -- 每週一次大配對
    'restaurant_vote_end',  -- 餐廳投票結束
    'event_end',            -- 活動結束（將 confirmed → completed）
    'rating_end',           -- 評分結束（轉存歷史與清理資料）
    'reminder_booking',     -- 預約聚餐提醒（match 前一天 9:00）
    'reminder_attendance'   -- 參加聚餐提醒（聚餐當天 9:00）
));

-- 更新 schedule_table 的 status 約束，新增 'processing' 狀態（用於背景執行中）
ALTER TABLE schedule_table
DROP CONSTRAINT IF EXISTS schedule_table_status_check;

ALTER TABLE schedule_table
ADD CONSTRAINT schedule_table_status_check
CHECK (status IN ('pending', 'processing', 'done', 'failed'));

-- 插入預設的提醒訊息模板
-- ===== 預約聚餐提醒 (booking_reminder) =====
INSERT INTO reminder_templates (reminder_type, style_tag, title, body, weight) VALUES
-- 溫暖邀請型
('booking_reminder', 'warm', '新的一週，新的相遇 ✨', '本週聚餐開放預約囉！來找個時間，認識有趣的靈魂吧', 2),
('booking_reminder', 'warm', '週末好時光 🌟', '新的一週即將開始，來預約一場溫暖的聚餐吧！', 1),

-- 活潑趣味型
('booking_reminder', 'fun', '美食召喚中 🎉', '美食 + 新朋友 = 完美的一週！現在就預約下週聚餐', 2),
('booking_reminder', 'fun', '餐桌冒險等你來 🍽️', '想認識有趣的人嗎？快來預約本週聚餐！', 1),

-- 簡潔提醒型
('booking_reminder', 'simple', '本週聚餐開放預約', '別錯過這次認識新朋友的機會，現在就來預約吧！', 1)

ON CONFLICT DO NOTHING;

-- ===== 參加聚餐提醒 (attendance_reminder) =====
INSERT INTO reminder_templates (reminder_type, style_tag, title, body, weight) VALUES
-- 溫暖提醒型
('attendance_reminder', 'warm', '今晚見！💫', '別忘了你和新朋友的約會，{time} 在 {restaurant_name} 等你', 2),
('attendance_reminder', 'warm', '準備好了嗎？✨', '今晚的餐桌上，會有精彩的故事等著你', 1),

-- 活潑趣味型
('attendance_reminder', 'fun', '倒數計時！🎊', '今天就是聚餐日！記得 {time} 準時出現喔', 2),
('attendance_reminder', 'fun', '美食時間到 🍜', '今晚 {time}，{restaurant_name} 有一桌精彩等著你！', 1),

-- 簡潔提醒型
('attendance_reminder', 'simple', '聚餐提醒', '今天 {time} 的聚餐記得出席，地點：{restaurant_name}', 1)

ON CONFLICT DO NOTHING;

-- 為 reminder_templates 表添加更新時間觸發器
CREATE TRIGGER update_reminder_templates_updated_at
BEFORE UPDATE ON reminder_templates
FOR EACH ROW
EXECUTE FUNCTION update_timestamp_column();

COMMENT ON TABLE reminder_templates IS '提醒訊息模板表，存儲不同情境的提醒訊息';
COMMENT ON COLUMN reminder_templates.reminder_type IS '提醒類型：booking_reminder(預約提醒)、attendance_reminder(出席提醒)';
COMMENT ON COLUMN reminder_templates.style_tag IS '訊息風格標籤：warm(溫暖)、fun(活潑)、urgent(緊急)、simple(簡潔)';
COMMENT ON COLUMN reminder_templates.weight IS '隨機選擇權重，數字越大被選中機率越高';

