-- 創建 users_profiles_view 視圖
CREATE OR REPLACE VIEW users_profiles_view AS
SELECT
    user_id,
    nickname,
    personal_desc
FROM user_profiles;


-- 創建 dining_events 表
CREATE TABLE IF NOT EXISTS dining_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matching_group_id UUID NOT NULL REFERENCES matching_groups(id),
    restaurant_id UUID REFERENCES restaurants(id),
    name TEXT NOT NULL,
    date TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT NOT NULL DEFAULT 'confirmed',
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 創建 dining_event_participants 表
CREATE TABLE IF NOT EXISTS dining_event_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES dining_events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    attendance_status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'confirmed', 'declined'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(event_id, user_id)
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 創建 restaurant_votes 表
CREATE TABLE IF NOT EXISTS restaurant_votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES matching_groups(id),
    user_id UUID REFERENCES auth.users(id),
    is_system_recommendation BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(restaurant_id, group_id, user_id) WHERE user_id IS NOT NULL
);

-- 創建 matching_groups 表（配對算法用）
CREATE TABLE IF NOT EXISTS matching_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_ids UUID[] NOT NULL,
    personality_type TEXT NOT NULL,
    is_complete BOOLEAN DEFAULT FALSE,
    male_count INTEGER DEFAULT 0,
    female_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'waiting_confirmation',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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
CREATE INDEX IF NOT EXISTS idx_dining_event_participants_event_id ON dining_event_participants(event_id);
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
ALTER TABLE dining_event_participants ENABLE ROW LEVEL SECURITY;
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
CREATE POLICY service_all ON dining_event_participants FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
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
    USING (group_id IN (
        SELECT group_id FROM group_uuid_mapping 
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

-- 創建 ratings 表 對其他用戶的評價
-- TODO: 需要設計 ratings 表的 schema
