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
    dining_event_id UUID NOT NULL REFERENCES dining_events(id) ON DELETE CASCADE,
    from_user_id UUID NOT NULL REFERENCES auth.users(id),
    to_user_id UUID NOT NULL REFERENCES auth.users(id),
    rating_type TEXT NOT NULL CHECK (rating_type IN ('like', 'dislike', 'no_show')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(dining_event_id, from_user_id, to_user_id)
);

-- 創建必要的索引
CREATE INDEX IF NOT EXISTS idx_rating_sessions_dining_event_id ON rating_sessions(dining_event_id);
CREATE INDEX IF NOT EXISTS idx_rating_sessions_from_user_id ON rating_sessions(from_user_id);
CREATE INDEX IF NOT EXISTS idx_rating_sessions_session_token ON rating_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_user_ratings_from_user_id ON user_ratings(from_user_id);
CREATE INDEX IF NOT EXISTS idx_user_ratings_to_user_id ON user_ratings(to_user_id);
CREATE INDEX IF NOT EXISTS idx_user_ratings_dining_event_id ON user_ratings(dining_event_id);

-- 設置 RLS 權限
ALTER TABLE rating_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ratings ENABLE ROW LEVEL SECURITY;

-- 為API服務提供完全存取權限
CREATE POLICY service_all ON rating_sessions FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');
CREATE POLICY service_all ON user_ratings FOR ALL TO authenticated USING (current_setting('request.jwt.claims', true)::json->>'app' = 'service_role');

-- 用戶只能查看自己的評價會話
CREATE POLICY sessions_select_own ON rating_sessions FOR SELECT TO authenticated USING (from_user_id = auth.uid());

-- 用戶只能查看自己發出的評價
CREATE POLICY ratings_select_own ON user_ratings FOR SELECT TO authenticated USING (from_user_id = auth.uid());

-- 用戶只能新增自己發出的評價
CREATE POLICY ratings_insert_own ON user_ratings FOR INSERT TO authenticated WITH CHECK (from_user_id = auth.uid()); 