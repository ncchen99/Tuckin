-- 餐廳擁有者欄位遷移
-- 新增 added_by_user_id 欄位來追蹤是誰新增的餐廳

-- 1. 新增 added_by_user_id 欄位到 restaurants 表
ALTER TABLE restaurants 
ADD COLUMN IF NOT EXISTS added_by_user_id UUID REFERENCES auth.users(id);

-- 2. 為新欄位創建索引以優化查詢
CREATE INDEX IF NOT EXISTS idx_restaurants_added_by_user_id 
ON restaurants(added_by_user_id);

-- 3. 添加註釋說明欄位用途
COMMENT ON COLUMN restaurants.added_by_user_id IS '新增此餐廳的用戶ID，NULL 表示系統新增';

-- 4. 創建 RLS 政策：允許用戶刪除自己新增的餐廳
CREATE POLICY user_delete_own_restaurant ON restaurants
    FOR DELETE TO authenticated
    USING (added_by_user_id = auth.uid());

