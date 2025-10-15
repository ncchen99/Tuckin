-- 為 user_profiles 表添加 avatar_path 字段的遷移腳本
-- 執行日期：2025年10月

-- 添加 avatar_path 字段（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'user_profiles' 
        AND column_name = 'avatar_path'
    ) THEN
        ALTER TABLE user_profiles ADD COLUMN avatar_path TEXT NULL;
        RAISE NOTICE '已添加 avatar_path 字段到 user_profiles 表';
    ELSE
        RAISE NOTICE 'avatar_path 字段已存在於 user_profiles 表';
    END IF;
END $$;


-- 添加註釋說明
COMMENT ON COLUMN user_profiles.avatar_path IS '用戶頭像在私有 R2 bucket 中的路徑（格式：avatars/user_id.webp）';

