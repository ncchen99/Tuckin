import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'supabase_service.dart';
import 'api_service.dart';
import 'error_handler.dart';
import 'notification_service.dart';
import 'user_status_service.dart';

/// 認證服務，處理用戶登入、登出等認證相關功能
class AuthService {
  // 單例模式
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // 取得 Supabase 服務的實例
  final SupabaseService _supabaseService = SupabaseService();
  final ApiService _apiService = ApiService();
  final ErrorHandler _errorHandler = ErrorHandler();
  final UserStatusService _userStatusService = UserStatusService();

  // Google 登入實例
  GoogleSignIn? _googleSignIn;

  // 初始化認證服務
  Future<void> initialize() async {
    try {
      // 初始化 Supabase 服務
      await _supabaseService.initialize();
      debugPrint('AuthService 初始化完成');

      // 檢查當前用戶是否有效
      final currentUser = getCurrentUser();
      try {
        // 驗證令牌是否有效
        await _supabaseService.auth.refreshSession();
        debugPrint('AuthService: 用戶令牌有效');
      } catch (e) {
        // 令牌無效或過期，執行登出操作
        debugPrint('AuthService: 用戶令牌無效，執行登出 - $e');
        await signOut();
      }
    } catch (e) {
      debugPrint('AuthService 初始化錯誤: $e');
      _errorHandler.handleApiError(
        ApiError(message: '認證服務初始化失敗: $e', isServerError: true),
        () => initialize(),
      );
      // 發生錯誤時，嘗試登出以避免狀態不一致
      try {
        await signOut();
      } catch (_) {}
    }
  }

  // 使用 Google 登入
  Future<AuthResponse?> signInWithGoogle(BuildContext context) async {
    try {
      // 從環境變量中獲取 Google 客戶端 ID
      final androidClientId = dotenv.env['GOOGLE_CLIENT_ID_ANDROID'];
      final webClientId = dotenv.env['GOOGLE_CLIENT_ID_WEB'];

      debugPrint('使用 Google 客戶端 ID: $androidClientId');
      debugPrint('使用 Web 客戶端 ID: $webClientId');

      if (androidClientId == null || webClientId == null) {
        throw ApiError(message: 'Google 客戶端 ID 配置缺失', isServerError: false);
      }

      // 使用谷歌登入
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: androidClientId,
        serverClientId: webClientId,
      );

      // 啟動 Google 登入流程
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

      if (googleUser == null) {
        // 用戶取消登入
        return null;
      }

      // 獲取 Google 身份驗證
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 創建 OAuthCredential
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw ApiError(message: '無法獲取 Google 訪問令牌', isServerError: false);
      }

      if (idToken == null) {
        throw ApiError(message: '無法獲取 Google ID 令牌', isServerError: false);
      }

      // 使用 OAuth 登入 Supabase
      final response = await _supabaseService.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // 輸出JWT token以供調試使用
      final session = response.session;
      if (session != null) {
        debugPrint('=== JWT Token 開始 ===');
        final token = session.accessToken;
        for (int i = 0; i < token.length; i += 500) {
          int end = (i + 500 < token.length) ? i + 500 : token.length;
          debugPrint(token.substring(i, end));
        }
        debugPrint('=== JWT Token 結束 ===');
      }

      // 登入成功後，保存FCM token
      final notificationService = NotificationService();
      await notificationService.saveTokenToSupabase();

      return response;
    } catch (error) {
      debugPrint('Google 登入錯誤: $error');
      _errorHandler.handleApiError(
        ApiError(
          message: 'Google 登入失敗: $error',
          isServerError: error is ApiError ? error.isServerError : true,
        ),
        () => signInWithGoogle(context),
      );
      rethrow;
    }
  }

  // 登出
  Future<void> signOut() async {
    try {
      // 重置所有聚餐相關資料
      await _userStatusService.resetDiningData();
      debugPrint('AuthService: 已重置聚餐相關資料');

      // 清除所有通知（包括排程通知）
      await NotificationService().clearAllNotificationsOnLogout();

      // 登出 Google 賬號
      if (_googleSignIn != null) {
        await _googleSignIn!.disconnect();
        debugPrint('AuthService: Google 賬號已登出');
      }

      // 登出 Supabase
      await _supabaseService.auth.signOut();
      debugPrint('AuthService: 用戶已成功登出');
    } catch (e) {
      debugPrint('AuthService: 登出時發生錯誤 - $e');
      _errorHandler.handleApiError(
        ApiError(message: '登出失敗: $e', isServerError: true),
        () => signOut(),
      );
      rethrow;
    }
  }

  // 檢查用戶是否已登錄
  Future<bool> isLoggedIn() async {
    final user = await _supabaseService.getCurrentUser();
    return user != null;
  }

  // 獲取當前用戶
  Future<User?> getCurrentUser() async {
    return await _supabaseService.getCurrentUser();
  }

  // 檢查是否為成大信箱
  bool isNCKUEmail(String? email) {
    if (email == null) return false;
    return email.toLowerCase().contains('ncku.edu.tw');
  }
}
