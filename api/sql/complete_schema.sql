-- TuckIn應用程式整合資料庫結構
-- 根據所有資料表.md整合的完整架構

-- 首先建立基礎表格

-- 使用者個人資料表
create table public.user_profiles (
  id serial not null,
  user_id uuid not null,
  nickname text not null,
  gender text not null,
  personal_desc text null,
  avatar_path text null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint user_profiles_pkey primary key (id),
  constraint user_profiles_user_id_fkey foreign KEY (user_id) references auth.users (id)
) TABLESPACE pg_default;

create index IF not exists idx_user_profiles_user_id on public.user_profiles using btree (user_id) TABLESPACE pg_default;

create trigger update_user_profiles_updated_at BEFORE
update on user_profiles for EACH row
execute FUNCTION update_timestamp_column ();

-- 食物偏好基礎表 (先建立此表，避免外鍵參考錯誤)
CREATE TABLE IF NOT EXISTS food_preferences (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    description TEXT,
    image_path VARCHAR(200),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name)
);

-- 用戶個性測驗結果表
CREATE TABLE IF NOT EXISTS user_personality_results (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    personality_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- 用戶食物偏好表 (多對多關係)
CREATE TABLE IF NOT EXISTS user_food_preferences (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    preference_id INTEGER NOT NULL REFERENCES food_preferences(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, preference_id)
);

-- 用戶狀態表
CREATE TABLE IF NOT EXISTS user_status (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'initial', -- 初始狀態
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- 先刪除現有的約束
ALTER TABLE user_status
DROP CONSTRAINT IF EXISTS status_check;

-- 然後添加包含新狀態的約束
ALTER TABLE user_status
ADD CONSTRAINT status_check
CHECK (status IN (
    'initial', -- 初始狀態
    'booking', -- 預約階段
    'waiting_matching', -- 等待配對階段
    'waiting_restaurant', -- 等待餐廳確認階段
    'waiting_other_users', -- 等待其他用戶階段
    'waiting_attendance', -- 等待出席階段
    'matching_failed', -- 配對失敗階段
    'confirmation_timeout', -- 逾時未確認階段
    'low_attendance', -- 團體出席率過低階段
    'rating' -- 評分階段
));

-- 創建設備令牌表，用於保存 FCM tokens
CREATE TABLE IF NOT EXISTS user_device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(user_id, token)
);

-- 創建通知表，用於記錄所有發送的通知
CREATE TABLE IF NOT EXISTS user_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  read_at TIMESTAMP WITH TIME ZONE
);

-- 創建 matching_groups 表（配對算法用）
CREATE TABLE IF NOT EXISTS matching_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_ids UUID[] NOT NULL,
    is_complete BOOLEAN DEFAULT FALSE,
    male_count INTEGER DEFAULT 0,
    female_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'waiting_confirmation',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    school_only BOOLEAN DEFAULT FALSE
);

-- 創建 user_matching_info 表（儲存配對相關信息）
CREATE TABLE IF NOT EXISTS user_matching_info (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    matching_group_id UUID REFERENCES matching_groups(id),
    confirmation_deadline TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 創建 restaurants 表
CREATE TABLE IF NOT EXISTS restaurants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    category TEXT,
    description TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    image_path TEXT,
    business_hours TEXT,
    google_place_id TEXT,
    is_user_added BOOLEAN DEFAULT FALSE,
    added_by_user_id UUID REFERENCES auth.users(id), -- 新增此餐廳的用戶ID
    phone TEXT,
    website TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 創建 restaurant_votes 表
CREATE TABLE IF NOT EXISTS restaurant_votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES matching_groups(id),
    user_id UUID REFERENCES auth.users(id),
    is_system_recommendation BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 使用部分索引建立唯一約束，只對user_id非空的記錄生效
CREATE UNIQUE INDEX IF NOT EXISTS unique_restaurant_vote_per_user 
ON restaurant_votes (restaurant_id, group_id, user_id) 
WHERE user_id IS NOT NULL;

-- 創建用戶配對偏好表
CREATE TABLE IF NOT EXISTS user_matching_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    prefer_school_only BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 創建 dining_events 表
CREATE TABLE IF NOT EXISTS dining_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matching_group_id UUID NOT NULL REFERENCES matching_groups(id),
    restaurant_id UUID REFERENCES restaurants(id),
    name TEXT NOT NULL,
    date TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending_confirmation' CHECK (status IN ('pending_confirmation', 'confirming', 'confirmed', 'completed')),
    description TEXT,
    candidate_restaurant_ids UUID[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status_change_time TIMESTAMP WITH TIME ZONE,
    attendee_count INTEGER,
    reservation_name TEXT,
    reservation_phone TEXT
);

-- 創建評價會話表（用於追蹤一次評價過程）
CREATE TABLE IF NOT EXISTS rating_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dining_event_id UUID NOT NULL REFERENCES dining_events(id) ON DELETE CASCADE,
    from_user_id UUID NOT NULL REFERENCES auth.users(id),
    session_token TEXT NOT NULL UNIQUE,
    user_sequence JSONB NOT NULL, -- 僅存儲索引和nickname，不存儲實際user_id
    user_mapping JSONB NOT NULL, -- 僅後端用，存儲索引到user_id的映射
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    UNIQUE(dining_event_id, from_user_id)
);

-- 創建用戶評價資料表
CREATE TABLE IF NOT EXISTS user_ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dining_event_id UUID NOT NULL,
    from_user_id UUID NOT NULL REFERENCES auth.users(id),
    to_user_id UUID NOT NULL REFERENCES auth.users(id),
    rating_type TEXT NOT NULL CHECK (rating_type IN ('like', 'dislike', 'no_show')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(dining_event_id, from_user_id, to_user_id)
);

-- 用戶只能新增自己發出的評價
CREATE POLICY ratings_insert_own ON user_ratings 
FOR INSERT TO authenticated 
WITH CHECK (from_user_id = auth.uid());

-- 用戶只能更新自己發出的評價（因為使用 upsert）
CREATE POLICY ratings_update_own ON user_ratings 
FOR UPDATE TO authenticated 
USING (from_user_id = auth.uid());

-- 創建聚餐歷史紀錄表
CREATE TABLE IF NOT EXISTS dining_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    original_event_id UUID NOT NULL UNIQUE, -- 保存原始的dining_event_id
    restaurant_id UUID,
    restaurant_name TEXT,
    event_name TEXT NOT NULL,
    event_date TIMESTAMP WITH TIME ZONE NOT NULL,
    attendee_count INTEGER,
    user_ids UUID[] NOT NULL,
    school_only BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 為歷史紀錄表創建索引以提高查詢效能
CREATE INDEX IF NOT EXISTS idx_dining_history_user_ids ON dining_history USING GIN (user_ids);
CREATE INDEX IF NOT EXISTS idx_dining_history_event_date ON dining_history(event_date);
CREATE INDEX IF NOT EXISTS idx_dining_history_original_event_id ON dining_history(original_event_id);

-- 創建觸發器以自動更新updated_at時間戳
CREATE OR REPLACE FUNCTION update_timestamp_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 為每個需要自動更新時間戳的表創建觸發器
CREATE TRIGGER update_user_profiles_updated_at
BEFORE UPDATE ON user_profiles
FOR EACH ROW
EXECUTE FUNCTION update_timestamp_column();

CREATE TRIGGER update_user_personality_results_updated_at
BEFORE UPDATE ON user_personality_results
FOR EACH ROW
EXECUTE FUNCTION update_timestamp_column();

CREATE TRIGGER update_user_status_updated_at
BEFORE UPDATE ON user_status
FOR EACH ROW
EXECUTE FUNCTION update_timestamp_column();


-- 創建設備令牌管理觸發器函數
CREATE OR REPLACE FUNCTION manage_user_device_tokens() RETURNS TRIGGER AS $$
BEGIN
  -- 刪除該用戶的其他裝置令牌（保留當前插入的令牌）
  DELETE FROM user_device_tokens
  WHERE user_id = NEW.user_id
    AND id != NEW.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 綁定觸發器到 user_device_tokens 表
DROP TRIGGER IF EXISTS user_device_tokens_manage_trigger ON user_device_tokens;
CREATE TRIGGER user_device_tokens_manage_trigger
  AFTER INSERT ON user_device_tokens
  FOR EACH ROW
  EXECUTE FUNCTION manage_user_device_tokens();



-- 創建狀態變更觸發器函數
CREATE OR REPLACE FUNCTION process_dining_event_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- 只處理狀態變為 'confirming' 的情況
    IF NEW.status = 'confirming' THEN
        -- 記錄狀態變更時間
        NEW.status_change_time = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 創建觸發器
DROP TRIGGER IF EXISTS dining_event_status_change_trigger ON dining_events;
CREATE TRIGGER dining_event_status_change_trigger
BEFORE UPDATE ON dining_events
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION process_dining_event_status_change();

-- 創建定期檢查和重置狀態的函數
CREATE OR REPLACE FUNCTION reset_confirming_dining_events()
RETURNS void AS $$
BEGIN
    -- 更新所有狀態為'confirming'且已經超過10分鐘的事件
    UPDATE dining_events
    SET status = 'pending_confirmation',
        updated_at = NOW()
    WHERE status = 'confirming'
    AND status_change_time < NOW() - INTERVAL '10 minutes';
END;
$$ LANGUAGE plpgsql;



-- 創建必要的索引來優化查詢性能
CREATE INDEX IF NOT EXISTS idx_dining_events_group_id ON dining_events(matching_group_id);
CREATE INDEX IF NOT EXISTS idx_dining_events_restaurant_id ON dining_events(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_restaurant_votes_group_id ON restaurant_votes(group_id);
CREATE INDEX IF NOT EXISTS idx_restaurant_votes_restaurant_id ON restaurant_votes(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_user_id ON user_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_read_at ON user_notifications(read_at);
CREATE INDEX IF NOT EXISTS idx_user_status_user_id ON user_status(user_id);
CREATE INDEX IF NOT EXISTS idx_user_status_status ON user_status(status);
CREATE INDEX IF NOT EXISTS idx_user_matching_info_user_id ON user_matching_info(user_id);
CREATE INDEX IF NOT EXISTS idx_user_matching_info_matching_group_id ON user_matching_info(matching_group_id);
CREATE INDEX IF NOT EXISTS idx_matching_groups_status ON matching_groups(status);
CREATE INDEX IF NOT EXISTS idx_user_matching_preferences_user_id ON user_matching_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_rating_sessions_dining_event_id ON rating_sessions(dining_event_id);
CREATE INDEX IF NOT EXISTS idx_rating_sessions_from_user_id ON rating_sessions(from_user_id);
CREATE INDEX IF NOT EXISTS idx_rating_sessions_session_token ON rating_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_user_ratings_from_user_id ON user_ratings(from_user_id);
CREATE INDEX IF NOT EXISTS idx_user_ratings_to_user_id ON user_ratings(to_user_id);
CREATE INDEX IF NOT EXISTS idx_user_ratings_dining_event_id ON user_ratings(dining_event_id);
CREATE INDEX IF NOT EXISTS idx_restaurants_added_by_user_id ON restaurants(added_by_user_id);

-- === 排程任務表：schedule_table ===
-- 用於儲存系統層級的時間驅動任務（由 GCP Scheduler 觸發 API 來批次執行）
CREATE TABLE IF NOT EXISTS schedule_table (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_type TEXT NOT NULL CHECK (task_type IN (
        'match',                -- 每週一次大配對
        'restaurant_vote_end',  -- 餐廳投票結束
        'event_end',            -- 活動結束（將 confirmed → completed）
        'rating_end'            -- 評分結束（轉存歷史與清理資料）
    )),
    scheduled_time TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','done','failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT schedule_task_unique UNIQUE (task_type, scheduled_time)
);

-- 索引優化常見查詢
CREATE INDEX IF NOT EXISTS idx_schedule_table_scheduled_time ON schedule_table(scheduled_time);
CREATE INDEX IF NOT EXISTS idx_schedule_table_status ON schedule_table(status);
CREATE INDEX IF NOT EXISTS idx_schedule_table_task_type ON schedule_table(task_type);

-- 為排程表啟用 RLS
ALTER TABLE schedule_table ENABLE ROW LEVEL SECURITY;

-- 為排程表設置 RLS 策略
CREATE POLICY service_all_schedule ON schedule_table
FOR ALL TO authenticated
USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');

-- 設置 RLS 權限
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_personality_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_food_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE dining_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurant_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE matching_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_matching_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_matching_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE rating_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE dining_history ENABLE ROW LEVEL SECURITY;


-- 創建基本政策，允許用戶讀取自己的資料
CREATE POLICY user_profiles_select ON user_profiles
    FOR SELECT USING (auth.uid() = user_id);

-- ✅ 新增一條 Policy：允許查詢同組組員的資料
CREATE POLICY "用戶可以查詢同組組員的資料"
ON public.user_profiles
FOR SELECT
USING (
  user_id IN (
    SELECT umi.user_id
    FROM public.user_matching_info umi
    WHERE umi.matching_group_id IN (
      SELECT matching_group_id
      FROM public.user_matching_info
      WHERE user_id = auth.uid()
    )
  )
);


-- 允許所有已認證用戶讀取食物偏好表
CREATE POLICY food_preferences_select ON food_preferences
    FOR SELECT USING (auth.role() = 'authenticated');

-- 用戶個性測驗結果表 RLS 策略
CREATE POLICY user_personality_results_select ON user_personality_results
    FOR SELECT USING (auth.uid() = user_id);

-- 用戶食物偏好表 RLS 策略
CREATE POLICY user_food_preferences_select ON user_food_preferences
    FOR SELECT USING (auth.uid() = user_id);

-- 用戶狀態表 RLS 策略
CREATE POLICY user_status_select ON user_status
    FOR SELECT USING (auth.uid() = user_id);

-- 為API服務提供所有表的完全存取權限
CREATE POLICY service_all ON dining_events FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON restaurants FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON restaurant_votes FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON matching_groups FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON user_status FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON user_matching_info FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON user_matching_preferences FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON rating_sessions FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON user_ratings FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all_history ON dining_history FOR ALL TO authenticated 
    USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');

-- 設置令牌和通知表的RLS政策
CREATE POLICY "使用者可以查看自己的設備令牌" ON user_device_tokens
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "使用者可以管理自己的設備令牌" ON user_device_tokens
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "使用者可以查看自己的通知" ON user_notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "服務可以為任何用戶創建通知" ON user_notifications
  FOR INSERT WITH CHECK (true);

-- 為用戶提供對餐廳表的讀取權限
CREATE POLICY restaurants_read ON restaurants FOR SELECT TO authenticated USING (true);

-- 用戶可以刪除自己新增的餐廳
CREATE POLICY user_delete_own_restaurant ON restaurants
    FOR DELETE TO authenticated
    USING (added_by_user_id = auth.uid());

-- 為群組成員提供對群組聚餐事件的讀取權限
CREATE POLICY dining_events_group_read ON dining_events 
    FOR SELECT TO authenticated 
    USING (matching_group_id IN (
        SELECT matching_group_id FROM user_matching_info 
        WHERE user_id = auth.uid()
    ));


-- 允許用戶讀取自己的配對資訊
CREATE POLICY "用戶可以讀取自己的配對資訊"
ON public.user_matching_info
FOR SELECT
USING (user_id = auth.uid());

-- 創建函數來獲取用戶的 matching_group_id
CREATE OR REPLACE FUNCTION public.get_user_matching_group_id(p_user_id uuid)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT matching_group_id
  FROM public.user_matching_info
  WHERE user_id = p_user_id
  LIMIT 1;
$$;

CREATE POLICY "用戶可以讀取同組成員的配對資訊"
ON public.user_matching_info
FOR SELECT
USING (
  matching_group_id = public.get_user_matching_group_id(auth.uid())
  AND matching_group_id IS NOT NULL
);

-- 用戶只能查看自己的評價會話
CREATE POLICY sessions_select_own ON rating_sessions FOR SELECT TO authenticated USING (from_user_id = auth.uid());

-- 用戶只能查看自己發出的評價
CREATE POLICY ratings_select_own ON user_ratings FOR SELECT TO authenticated USING (from_user_id = auth.uid());

-- 用戶只能新增自己發出的評價
CREATE POLICY ratings_insert_own ON user_ratings FOR INSERT TO authenticated WITH CHECK (from_user_id = auth.uid());

-- 用戶配對偏好表的RLS政策
CREATE POLICY user_view_own_preferences ON user_matching_preferences FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY user_insert_own_preferences ON user_matching_preferences FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY user_update_own_preferences ON user_matching_preferences FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- 添加安全性備註
COMMENT ON TABLE user_matching_info IS '此表允許用戶查看自己的數據，API服務可完全訪問';
COMMENT ON TABLE matching_groups IS '此表僅限API服務訪問';

-- 插入食物偏好數據，與前端頁面保持一致
INSERT INTO food_preferences (id, name, category, image_path) VALUES
    (1, '台灣料理', '料理類別', 'assets/images/dish/taiwanese.webp'),
    (2, '日式料理', '料理類別', 'assets/images/dish/japanese.webp'),
    (3, '日式咖哩', '料理類別', 'assets/images/dish/japanese_curry.webp'),
    (4, '韓式料理', '料理類別', 'assets/images/dish/korean.webp'),
    (5, '泰式料理', '料理類別', 'assets/images/dish/thai.webp'),
    (6, '義式料理', '料理類別', 'assets/images/dish/italian.webp'),
    (7, '美式餐廳', '料理類別', 'assets/images/dish/american.webp'),
    (8, '中式料理', '料理類別', 'assets/images/dish/chinese.webp'),
    (9, '港式飲茶', '料理類別', 'assets/images/dish/hongkong.webp'),
    (10, '印度料理', '料理類別', 'assets/images/dish/indian.webp'),
    (11, '墨西哥菜', '料理類別', 'assets/images/dish/mexican.webp'),
    (12, '越南料理', '料理類別', 'assets/images/dish/vietnamese.webp'),
    (13, '素食料理', '特殊飲食', 'assets/images/dish/vegetarian.webp'),
    (14, '漢堡速食', '料理類別', 'assets/images/dish/burger.webp'),
    (15, '披薩料理', '料理類別', 'assets/images/dish/pizza.webp'),
    (16, '燒烤料理', '料理類別', 'assets/images/dish/barbecue.webp'),
    (17, '火鍋料理', '料理類別', 'assets/images/dish/hotpot.webp')
ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name,
    category = EXCLUDED.category,
    image_path = EXCLUDED.image_path;

-- 確保序列從最大ID之後開始，避免插入新記錄時ID衝突
SELECT setval('food_preferences_id_seq', (SELECT MAX(id) FROM food_preferences));

-- 為所有用戶創建初始狀態記錄
INSERT INTO user_status (user_id, status)
SELECT user_id, 'initial' FROM user_profiles
WHERE NOT EXISTS (
    SELECT 1 FROM user_status WHERE user_status.user_id = user_profiles.user_id
);

-- 為所有用戶創建配對偏好記錄，預設設置為"是"(prefer_school_only=true)
INSERT INTO user_matching_preferences (user_id, prefer_school_only)
SELECT user_id, true FROM user_profiles
WHERE NOT EXISTS (
    SELECT 1 FROM user_matching_preferences 
    WHERE user_matching_preferences.user_id = user_profiles.user_id
);

-- 允許用戶查詢自己參與過的聚餐歷史
CREATE POLICY dining_history_select ON dining_history
    FOR SELECT TO authenticated
    USING (auth.uid() = ANY(user_ids)); 

-- === 系統配置表：system_config ===
-- 用於儲存 APP 版本資訊和服務狀態
CREATE TABLE IF NOT EXISTS system_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(50) NOT NULL UNIQUE,
    config_value TEXT,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 創建索引
CREATE INDEX IF NOT EXISTS idx_system_config_key ON system_config(config_key);

-- 為系統配置表啟用 RLS
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;

-- 允許所有已認證用戶讀取系統配置（公開資訊）
CREATE POLICY system_config_select ON system_config
    FOR SELECT TO authenticated
    USING (true);

-- 服務角色可以完全管理系統配置
CREATE POLICY service_all_system_config ON system_config
    FOR ALL TO authenticated
    USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');

-- 插入預設系統配置
INSERT INTO system_config (config_key, config_value, description) VALUES
    ('latest_app_version', '2.0.0', '最新 APP 版本號'),
    ('min_required_version', '2.0.0', '最低要求 APP 版本號（低於此版本必須更新）'),
    ('is_service_enabled', 'true', '服務是否啟用（true/false）'),
    ('service_disabled_reason', '', '服務暫停原因'),
    ('estimated_restore_time', '', '預計恢復時間（ISO 8601 格式）'),
    ('update_url_android', 'https://play.google.com/store/apps/details?id=com.tuckin.app', 'Android 更新連結'),
    ('update_url_ios', 'https://apps.apple.com/tw/app/tuckin/id6751713165', 'iOS 更新連結')
ON CONFLICT (config_key) DO NOTHING;

-- 創建自動更新時間戳觸發器
CREATE TRIGGER update_system_config_updated_at
BEFORE UPDATE ON system_config
FOR EACH ROW
EXECUTE FUNCTION update_timestamp_column();

CREATE OR REPLACE FUNCTION get_group_votes(group_uuid UUID)
RETURNS TABLE (
    id UUID,
    restaurant_id UUID,
    group_id UUID,
    is_system_recommendation BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM user_matching_info 
        WHERE user_id = auth.uid() AND matching_group_id = group_uuid
    ) THEN
        RETURN QUERY
        SELECT rv.id, rv.restaurant_id, rv.group_id, rv.is_system_recommendation, rv.created_at
        FROM restaurant_votes rv
        WHERE rv.group_id = group_uuid;
    END IF;
    RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;