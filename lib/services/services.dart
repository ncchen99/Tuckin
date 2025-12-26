/// 統一導出所有服務
///
/// 服務分類：
/// - core: 核心基礎服務 (API, Supabase, Auth, ErrorHandler)
/// - data: 資料存取服務 (Database, Realtime)
/// - api: 後端 API 業務服務 (Matching, Dining, Restaurant, Places, User, Chat)
/// - local: 本地服務 (UserStatus, Notification, ImageCache, Time)
library;

// 核心服務
export 'core/api_service.dart';
export 'core/auth_service.dart';
export 'core/error_handler.dart';
export 'core/supabase_service.dart';

// 資料層服務
export 'data/database_service.dart';
export 'data/realtime_service.dart';

// API 業務服務
export 'api/chat_service.dart';
export 'api/dining_service.dart';
export 'api/matching_service.dart';
export 'api/places_service.dart';
export 'api/restaurant_service.dart';
export 'api/user_service.dart';

// 本地服務
export 'local/image_cache_service.dart';
export 'local/notification_service.dart';
export 'local/time_service.dart';
export 'local/user_status_service.dart';
export 'local/system_config_service.dart';
export 'local/app_initializer_service.dart';
