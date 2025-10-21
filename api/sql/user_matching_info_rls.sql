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

-- 修改 RLS policy
DROP POLICY IF EXISTS "用戶可以讀取同組成員的配對資訊" ON public.user_matching_info;

CREATE POLICY "用戶可以讀取同組成員的配對資訊"
ON public.user_matching_info
FOR SELECT
USING (
  matching_group_id = public.get_user_matching_group_id(auth.uid())
  AND matching_group_id IS NOT NULL
);