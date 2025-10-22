-- 聊天訊息表
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dining_event_id UUID NOT NULL REFERENCES public.dining_events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT,
    message_type TEXT NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'image')),
    image_path TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 建立索引以提升查詢效能
CREATE INDEX IF NOT EXISTS idx_chat_messages_dining_event_id ON public.chat_messages(dining_event_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id ON public.chat_messages(user_id);

-- 啟用 Realtime 訂閱
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;

-- RLS 政策：啟用 RLS
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- RLS 政策：用戶只能查看自己參與的聚餐事件的訊息
CREATE POLICY "Users can view messages from their dining events"
ON public.chat_messages
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM public.dining_events de
        JOIN public.user_matching_info umi ON de.matching_group_id = umi.matching_group_id
        WHERE de.id = chat_messages.dining_event_id
        AND umi.user_id = auth.uid()
    )
);

-- RLS 政策：用戶只能在自己參與的聚餐事件中發送訊息
CREATE POLICY "Users can insert messages to their dining events"
ON public.chat_messages
FOR INSERT
WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
        SELECT 1
        FROM public.dining_events de
        JOIN public.user_matching_info umi ON de.matching_group_id = umi.matching_group_id
        WHERE de.id = dining_event_id
        AND umi.user_id = auth.uid()
    )
);

-- RLS 政策：用戶只能刪除自己的訊息
CREATE POLICY "Users can delete their own messages"
ON public.chat_messages
FOR DELETE
USING (user_id = auth.uid());

-- 註解
COMMENT ON TABLE public.chat_messages IS '聊天訊息表，儲存聚餐事件的聊天訊息';
COMMENT ON COLUMN public.chat_messages.id IS '訊息唯一識別碼';
COMMENT ON COLUMN public.chat_messages.dining_event_id IS '所屬聚餐事件 ID';
COMMENT ON COLUMN public.chat_messages.user_id IS '發送者用戶 ID';
COMMENT ON COLUMN public.chat_messages.content IS '訊息內容（文字訊息）';
COMMENT ON COLUMN public.chat_messages.message_type IS '訊息類型：text（文字）或 image（圖片）';
COMMENT ON COLUMN public.chat_messages.image_path IS '圖片路徑（R2 上的路徑，僅圖片訊息）';
COMMENT ON COLUMN public.chat_messages.created_at IS '訊息建立時間';


