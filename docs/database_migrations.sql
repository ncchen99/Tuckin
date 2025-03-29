-- 首先建立基礎表格

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
    'waiting_confirmation', -- 等待確認階段
    'waiting_other_users', -- 等待其他用戶階段
    'waiting_attendance', -- 等待出席階段
    'matching_failed', -- 配對失敗階段
    'rating' -- 評分階段
));

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

-- 為表添加基本的行級安全性策略
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_personality_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_food_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_preferences ENABLE ROW LEVEL SECURITY;

-- 創建基本政策，允許用戶讀取自己的資料
CREATE POLICY user_profiles_select ON user_profiles
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_personality_results_select ON user_personality_results
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_food_preferences_select ON user_food_preferences
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_status_select ON user_status
    FOR SELECT USING (auth.uid() = user_id);

-- 允許所有已認證用戶讀取食物偏好表
CREATE POLICY food_preferences_select ON food_preferences
    FOR SELECT USING (auth.role() = 'authenticated');

-- 插入食物偏好數據，與前端頁面保持一致
INSERT INTO food_preferences (id, name, category, image_path) VALUES
    (1, '台灣料理', '料理類別', 'assets/images/dish/taiwanese.png'),
    (2, '日式料理', '料理類別', 'assets/images/dish/japanese.png'),
    (3, '日式咖哩', '料理類別', 'assets/images/dish/japanese_curry.png'),
    (4, '韓式料理', '料理類別', 'assets/images/dish/korean.png'),
    (5, '泰式料理', '料理類別', 'assets/images/dish/thai.png'),
    (6, '義式料理', '料理類別', 'assets/images/dish/italian.png'),
    (7, '美式餐廳', '料理類別', 'assets/images/dish/american.png'),
    (8, '中式料理', '料理類別', 'assets/images/dish/chinese.png'),
    (9, '港式飲茶', '料理類別', 'assets/images/dish/hongkong.png'),
    (10, '印度料理', '料理類別', 'assets/images/dish/indian.png'),
    (11, '墨西哥菜', '料理類別', 'assets/images/dish/mexican.png'),
    (12, '越南料理', '料理類別', 'assets/images/dish/vietnamese.png'),
    (13, '素食料理', '特殊飲食', 'assets/images/dish/vegetarian.png'),
    (14, '漢堡速食', '料理類別', 'assets/images/dish/burger.png'),
    (15, '披薩料理', '料理類別', 'assets/images/dish/pizza.png'),
    (16, '燒烤料理', '料理類別', 'assets/images/dish/barbecue.png'),
    (17, '火鍋料理', '料理類別', 'assets/images/dish/hotpot.png')
ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name,
    category = EXCLUDED.category,
    image_path = EXCLUDED.image_path;

-- 確保序列從最大ID之後開始，避免插入新記錄時ID衝突
SELECT setval('food_preferences_id_seq', (SELECT MAX(id) FROM food_preferences));

-- 遷移現有資料
-- 注意：這些指令應該在刪除原始欄位之前執行

-- 1. 將現有用戶的個性類型從user_profiles遷移到user_personality_results（如果欄位存在）：
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'user_profiles' AND column_name = 'personality_type'
    ) THEN
        INSERT INTO user_personality_results (user_id, personality_type)
        SELECT user_id, personality_type FROM user_profiles
        WHERE personality_type IS NOT NULL
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
END $$;

-- 2. 將現有用戶的食物偏好從user_profiles遷移到user_food_preferences（如果欄位存在）：
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'user_profiles' AND column_name = 'food_preferences_json'
    ) THEN
        INSERT INTO user_food_preferences (user_id, preference_id)
        SELECT 
            p.user_id,
            (jsonb_array_elements_text(p.food_preferences_json))::integer as preference_id
        FROM 
            user_profiles p
        WHERE 
            p.food_preferences_json IS NOT NULL AND 
            jsonb_array_length(p.food_preferences_json) > 0
        ON CONFLICT (user_id, preference_id) DO NOTHING;
    END IF;
END $$;

-- 3. 為所有用戶創建初始狀態記錄：
INSERT INTO user_status (user_id, status)
SELECT user_id, 'initial' FROM user_profiles
WHERE NOT EXISTS (
    SELECT 1 FROM user_status WHERE user_status.user_id = user_profiles.user_id
);

-- 最後，移除原始欄位（在資料遷移完成後）
ALTER TABLE IF EXISTS user_profiles
DROP COLUMN IF EXISTS personality_type,
DROP COLUMN IF EXISTS food_preferences_json;

-- 用戶個性測驗結果表 RLS 策略
CREATE POLICY user_personality_results_select ON user_personality_results
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_personality_results_insert ON user_personality_results
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_personality_results_update ON user_personality_results
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY user_personality_results_delete ON user_personality_results
    FOR DELETE USING (auth.uid() = user_id);

-- 用戶食物偏好表 RLS 策略
CREATE POLICY user_food_preferences_select ON user_food_preferences
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_food_preferences_insert ON user_food_preferences
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_food_preferences_update ON user_food_preferences
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY user_food_preferences_delete ON user_food_preferences
    FOR DELETE USING (auth.uid() = user_id);

-- 用戶狀態表 RLS 策略
CREATE POLICY user_status_select ON user_status
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY user_status_insert ON user_status
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_status_update ON user_status
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY user_status_delete ON user_status
    FOR DELETE USING (auth.uid() = user_id); 