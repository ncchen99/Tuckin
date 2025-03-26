-- 創建 users_profiles_view 視圖
CREATE OR REPLACE VIEW users_profiles_view AS
SELECT
    user_id,
    nickname,
    personal_desc
FROM user_profiles;

-- 創建 group_uuid_mapping 表
CREATE TABLE IF NOT EXISTS group_uuid_mapping (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 創建 dining_events 表
CREATE TABLE IF NOT EXISTS dining_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id TEXT NOT NULL,
    restaurant_id TEXT,
    name TEXT NOT NULL,
    date TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT NOT NULL DEFAULT 'planned',
    description TEXT,
    creator_id UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 創建 dining_event_participants 表
CREATE TABLE IF NOT EXISTS dining_event_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES dining_events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    is_attending BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
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
    group_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    vote_value INTEGER NOT NULL CHECK (vote_value BETWEEN 1 AND 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(restaurant_id, group_id, user_id)
);

-- 創建 ratings 表
CREATE TABLE IF NOT EXISTS ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurant_id UUID NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    score INTEGER NOT NULL CHECK (score BETWEEN 1 AND 5),
    comment TEXT,
    uncomfortable_rating BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(restaurant_id, user_id)
);

-- 創建 matching_scores 表
CREATE TABLE IF NOT EXISTS matching_scores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    target_user_id UUID NOT NULL REFERENCES auth.users(id),
    score DOUBLE PRECISION DEFAULT 0.0,
    last_calculated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, target_user_id)
);

-- 創建 user_notifications 表
CREATE TABLE IF NOT EXISTS user_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);

-- 創建必要的索引來優化查詢性能
CREATE INDEX IF NOT EXISTS idx_dining_events_group_id ON dining_events(group_id);
CREATE INDEX IF NOT EXISTS idx_dining_events_restaurant_id ON dining_events(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_dining_event_participants_event_id ON dining_event_participants(event_id);
CREATE INDEX IF NOT EXISTS idx_restaurant_votes_group_id ON restaurant_votes(group_id);
CREATE INDEX IF NOT EXISTS idx_restaurant_votes_restaurant_id ON restaurant_votes(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_ratings_restaurant_id ON ratings(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_matching_scores_user_id ON matching_scores(user_id);
CREATE INDEX IF NOT EXISTS idx_matching_scores_target_user_id ON matching_scores(target_user_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_user_id ON user_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_read_at ON user_notifications(read_at);

-- 設置 RLS 權限，以下為範例，實際使用時應根據需求進行調整
ALTER TABLE dining_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE dining_event_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;
ALTER TABLE restaurant_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE matching_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_uuid_mapping ENABLE ROW LEVEL SECURITY;

-- 為管理員提供所有表的完全存取權限
CREATE POLICY admin_all ON dining_events FOR ALL TO authenticated USING (auth.uid() IN (SELECT auth.uid() FROM auth.users WHERE auth.uid() IN (SELECT id FROM admins)));
CREATE POLICY admin_all ON dining_event_participants FOR ALL TO authenticated USING (auth.uid() IN (SELECT auth.uid() FROM auth.users WHERE auth.uid() IN (SELECT id FROM admins)));
CREATE POLICY admin_all ON restaurants FOR ALL TO authenticated USING (auth.uid() IN (SELECT auth.uid() FROM auth.users WHERE auth.uid() IN (SELECT id FROM admins)));
CREATE POLICY admin_all ON restaurant_votes FOR ALL TO authenticated USING (auth.uid() IN (SELECT auth.uid() FROM auth.users WHERE auth.uid() IN (SELECT id FROM admins)));
CREATE POLICY admin_all ON ratings FOR ALL TO authenticated USING (auth.uid() IN (SELECT auth.uid() FROM auth.users WHERE auth.uid() IN (SELECT id FROM admins)));
CREATE POLICY admin_all ON matching_scores FOR ALL TO authenticated USING (auth.uid() IN (SELECT auth.uid() FROM auth.users WHERE auth.uid() IN (SELECT id FROM admins)));
CREATE POLICY admin_all ON group_uuid_mapping FOR ALL TO authenticated USING (auth.uid() IN (SELECT auth.uid() FROM auth.users WHERE auth.uid() IN (SELECT id FROM admins)));

-- 為用戶提供對餐廳表的讀取權限
CREATE POLICY restaurants_read ON restaurants FOR SELECT TO authenticated USING (true);

-- 為用戶提供對自己評分的讀寫權限
CREATE POLICY ratings_own ON ratings FOR ALL TO authenticated USING (auth.uid() = user_id);
CREATE POLICY ratings_read ON ratings FOR SELECT TO authenticated USING (true);

-- 為群組成員提供對群組聚餐事件的讀取權限
CREATE POLICY dining_events_group_read ON dining_events 
    FOR SELECT TO authenticated 
    USING (group_id IN (
        SELECT group_id FROM group_uuid_mapping 
        WHERE user_id = auth.uid()
    ));

-- 為群組成員提供對群組餐廳投票的讀取權限
CREATE POLICY restaurant_votes_group_read ON restaurant_votes 
    FOR SELECT TO authenticated 
    USING (group_id IN (
        SELECT group_id FROM group_uuid_mapping 
        WHERE user_id = auth.uid()
    )); 