

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
    status_change_time TIMESTAMP WITH TIME ZONE
);

-- 確保 dining_events 表中存在 status_change_time 欄位
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'dining_events' 
        AND column_name = 'status_change_time'
    ) THEN
        ALTER TABLE dining_events ADD COLUMN status_change_time TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

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

-- 註解: 此函數保留供後端服務調用
-- 後端應定期調用此函數以重置超時的confirming狀態

-- 更新現有記錄的status以符合新的限制條件
DO $$
BEGIN
    -- 將舊的 'confirmed' 值更新為 'completed'（如果有任何時間早於現在的confirmed事件）
    UPDATE dining_events
    SET status = 'completed'
    WHERE status = 'confirmed' AND date < NOW();
    
    -- 將任何不在允許列表中的狀態更新為 'pending_confirmation'
    UPDATE dining_events
    SET status = 'pending_confirmation'
    WHERE status NOT IN ('pending_confirmation', 'confirming', 'confirmed', 'completed');
END $$;

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
    phone TEXT,
    website TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS is_user_added BOOLEAN DEFAULT FALSE;
ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS website TEXT;

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

-- 創建 matching_groups 表（配對算法用）
CREATE TABLE IF NOT EXISTS matching_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_ids UUID[] NOT NULL,
    personality_type TEXT NOT NULL,
    is_complete BOOLEAN DEFAULT FALSE,
    male_count INTEGER DEFAULT 0,
    female_count INTEGER DEFAULT 0,
    school_only BOOLEAN DEFAULT FALSE,
    status TEXT DEFAULT 'waiting_confirmation',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 為已有的群組添加school_only欄位（如果欄位不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'matching_groups' 
        AND column_name = 'school_only'
    ) THEN
        ALTER TABLE matching_groups ADD COLUMN school_only BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- 創建 user_status 表（跟踪用戶配對狀態）
CREATE TABLE IF NOT EXISTS user_status (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    status TEXT NOT NULL DEFAULT 'waiting_matching',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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

-- 創建用戶狀態擴展視圖（保持與原結構兼容）
CREATE OR REPLACE VIEW user_status_extended AS
SELECT 
    us.id, 
    us.user_id, 
    us.status, 
    umi.matching_group_id AS group_id,
    umi.confirmation_deadline,
    us.created_at, 
    us.updated_at
FROM 
    user_status us
LEFT JOIN 
    user_matching_info umi ON us.user_id = umi.user_id;

-- 創建必要的索引來優化查詢性能
CREATE INDEX IF NOT EXISTS idx_dining_events_group_id ON dining_events(group_id);
CREATE INDEX IF NOT EXISTS idx_dining_events_restaurant_id ON dining_events(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_restaurant_votes_group_id ON restaurant_votes(group_id);
CREATE INDEX IF NOT EXISTS idx_restaurant_votes_restaurant_id ON restaurant_votes(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_ratings_restaurant_id ON ratings(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_user_id ON user_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_read_at ON user_notifications(read_at);
CREATE INDEX IF NOT EXISTS idx_user_status_user_id ON user_status(user_id);
CREATE INDEX IF NOT EXISTS idx_user_status_status ON user_status(status);
CREATE INDEX IF NOT EXISTS idx_user_matching_info_user_id ON user_matching_info(user_id);
CREATE INDEX IF NOT EXISTS idx_user_matching_info_matching_group_id ON user_matching_info(matching_group_id);
CREATE INDEX IF NOT EXISTS idx_matching_groups_personality_type ON matching_groups(personality_type);
CREATE INDEX IF NOT EXISTS idx_matching_groups_status ON matching_groups(status);

-- 設置 RLS 權限，以下為範例，實際使用時應根據需求進行調整
ALTER TABLE dining_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurant_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE matching_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_uuid_mapping ENABLE ROW LEVEL SECURITY;
ALTER TABLE matching_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_matching_info ENABLE ROW LEVEL SECURITY;

-- 為API服務提供所有表的完全存取權限
CREATE POLICY service_all ON dining_events FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON restaurants FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON restaurant_votes FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON ratings FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON matching_scores FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON group_uuid_mapping FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON matching_groups FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON user_status FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON user_matching_info FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');

-- 為用戶提供對餐廳表的讀取權限
CREATE POLICY restaurants_read ON restaurants FOR SELECT TO authenticated USING (true);

-- 為群組成員提供對群組聚餐事件的讀取權限
CREATE POLICY dining_events_group_read ON dining_events 
    FOR SELECT TO authenticated 
    USING (matching_group_id IN (
        SELECT matching_group_id FROM user_matching_info 
        WHERE user_id = auth.uid()
    ));

-- 刪除現有的用戶級別訪問策略（針對user_status, user_matching_info和matching_groups）
DROP POLICY IF EXISTS user_matching_info_self ON user_matching_info;
DROP POLICY IF EXISTS matching_groups_member ON matching_groups;

-- 為user_matching_info表添加用戶訪問權限
CREATE POLICY user_view_own_matching_info ON user_matching_info 
    FOR SELECT TO authenticated 
    USING (user_id = auth.uid());

-- 對user_status_extended視圖應用RLS
ALTER VIEW user_status_extended SECURITY INVOKER;

-- 添加安全性備註
COMMENT ON TABLE user_matching_info IS '此表允許用戶查看自己的數據，API服務可完全訪問';
COMMENT ON TABLE matching_groups IS '此表僅限API服務訪問';

-- 確保 restaurant_votes 表中存在 is_system_recommendation 欄位
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'restaurant_votes' 
        AND column_name = 'is_system_recommendation'
    ) THEN
        ALTER TABLE restaurant_votes ADD COLUMN is_system_recommendation BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- 創建用戶配對偏好表
CREATE TABLE IF NOT EXISTS user_matching_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    prefer_school_only BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 設置 RLS 權限
ALTER TABLE user_matching_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY service_all ON user_matching_preferences FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY user_view_own_preferences ON user_matching_preferences FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY user_insert_own_preferences ON user_matching_preferences FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY user_update_own_preferences ON user_matching_preferences FOR UPDATE TO authenticated USING (user_id = auth.uid());

-- 創建必要的索引
CREATE INDEX IF NOT EXISTS idx_user_matching_preferences_user_id ON user_matching_preferences(user_id);

-- 為所有現有用戶創建配對偏好記錄，預設設置為"是"(prefer_school_only=true)
INSERT INTO user_matching_preferences (user_id, prefer_school_only)
SELECT user_id, true FROM user_profiles
WHERE NOT EXISTS (
    SELECT 1 FROM user_matching_preferences 
    WHERE user_matching_preferences.user_id = user_profiles.user_id
);

-- 創建用戶評價資料表
CREATE TABLE IF NOT EXISTS user_ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dining_event_id UUID NOT NULL REFERENCES dining_events(id) ON DELETE CASCADE,
    from_user_id UUID NOT NULL REFERENCES auth.users(id),
    to_user_id UUID NOT NULL REFERENCES auth.users(id),
    rating_type TEXT NOT NULL CHECK (rating_type IN ('like', 'dislike', 'no_show')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(dining_event_id, from_user_id, to_user_id)
);

-- 創建必要的索引
CREATE INDEX IF NOT EXISTS idx_user_ratings_from_user_id ON user_ratings(from_user_id);
CREATE INDEX IF NOT EXISTS idx_user_ratings_to_user_id ON user_ratings(to_user_id);
CREATE INDEX IF NOT EXISTS idx_user_ratings_dining_event_id ON user_ratings(dining_event_id);

-- 設置 RLS 權限
ALTER TABLE user_ratings ENABLE ROW LEVEL SECURITY;

-- 為API服務提供完全存取權限
CREATE POLICY service_all ON user_ratings FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');

-- -- 用戶只能查看自己發出的評價
-- CREATE POLICY user_ratings_select_own ON user_ratings FOR SELECT TO authenticated USING (from_user_id = auth.uid());

-- -- 用戶只能新增自己發出的評價
-- CREATE POLICY user_ratings_insert_own ON user_ratings FOR INSERT TO authenticated WITH CHECK (from_user_id = auth.uid());

-- -- 用戶只能更新自己發出的評價
-- CREATE POLICY user_ratings_update_own ON user_ratings FOR UPDATE TO authenticated USING (from_user_id = auth.uid());
