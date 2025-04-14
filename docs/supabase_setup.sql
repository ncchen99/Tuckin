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

-- 創建 RLS 政策
ALTER TABLE user_device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- 設定 RLS 政策
CREATE POLICY "使用者可以查看自己的設備令牌" ON user_device_tokens
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "使用者可以管理自己的設備令牌" ON user_device_tokens
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "使用者可以查看自己的通知" ON user_notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "服務可以為任何用戶創建通知" ON user_notifications
  FOR INSERT WITH CHECK (true);

-- 創建發送通知的函數
CREATE OR REPLACE FUNCTION send_push_notification(
  receiver_user_id UUID,
  title TEXT,
  body TEXT,
  data JSONB DEFAULT '{}'::jsonb
) RETURNS VOID AS $$
DECLARE
  token_record RECORD;
BEGIN
  -- 插入通知記錄
  INSERT INTO user_notifications (user_id, title, body, data)
  VALUES (receiver_user_id, title, body, data);
  
  -- 循環處理每個設備 token
  FOR token_record IN 
    SELECT token FROM user_device_tokens 
    WHERE user_id = receiver_user_id
  LOOP
    -- 此處發送通知邏輯需要使用 Edge Functions 或 Webhooks 連接到 FCM
    -- 這裡先記錄操作
    RAISE NOTICE 'Sending notification to user % with token %', receiver_user_id, token_record.token;
    
    -- 實際實現時，這裡需要調用 Edge Function 或 Webhook 發送到 FCM
    -- 可以添加 supabase.functions.http.post('YOUR_EDGE_FUNCTION_URL', {})
    
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 創建狀態變更觸發器函數
CREATE OR REPLACE FUNCTION notify_status_change() RETURNS TRIGGER AS $$
BEGIN
  -- 檢查是否變更為 waiting_confirmation 狀態
  IF NEW.status = 'waiting_confirmation' AND 
     (OLD.status IS NULL OR OLD.status <> 'waiting_confirmation') THEN
    
    -- 調用發送通知函數
    PERFORM send_push_notification(
      NEW.user_id,
      '聚餐邀請！',
      '我們已找到朋友！請確認是否參加聚餐',
      jsonb_build_object(
        'type', 'attendance_confirmation',
        'status', 'waiting_confirmation',
        'screen', '/attendance_confirmation'
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 綁定觸發器到 user_status 表
DROP TRIGGER IF EXISTS user_status_change_trigger ON user_status;
CREATE TRIGGER user_status_change_trigger
  AFTER UPDATE OR INSERT ON user_status
  FOR EACH ROW
  EXECUTE FUNCTION notify_status_change();

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