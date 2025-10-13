import os
from dotenv import load_dotenv

# 載入環境變數
load_dotenv()

# Supabase 配置
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

# Firebase 配置
FIREBASE_CONFIG = os.getenv("FIREBASE_CONFIG")

# Google Places API 配置
GOOGLE_PLACES_API_KEY = os.getenv("GOOGLE_PLACES_API_KEY")

# JWT 密鑰
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7天

# Cloudflare R2 配置
R2_ACCOUNT_ID = os.getenv("R2_ACCOUNT_ID")
R2_ACCESS_KEY_ID = os.getenv("R2_ACCESS_KEY_ID")
R2_SECRET_ACCESS_KEY = os.getenv("R2_SECRET_ACCESS_KEY")
R2_ENDPOINT_URL = os.getenv("R2_ENDPOINT_URL")
R2_BUCKET_NAME = os.getenv("R2_BUCKET_NAME") 
R2_PUBLIC_URL = os.getenv("R2_PUBLIC_URL", "https://pub-5dc9d25894314a5cbfa4a5aab3c6cd6b.r2.dev")

# Cloudflare R2 私有 Bucket 配置（用於用戶頭像）
R2_PRIVATE_BUCKET_NAME = os.getenv("R2_PRIVATE_BUCKET_NAME")

# 開發模式配置
DEV_MODE = os.getenv("DEV_MODE", "false").lower() == "true"
DEV_USER_ID = os.getenv("DEV_USER_ID", "test-user-id")

# Cron Job API 密鑰
CRON_API_KEY = os.getenv("CRON_API_KEY", "")
