import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'supabase_service.dart';

/// 認證服務，處理用戶登入、登出等認證相關功能
class AuthService {
  // 單例模式
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  // 取得 Supabase 服務的實例
  final SupabaseService _supabaseService = SupabaseService();

  // 初始化認證服務
  Future<void> initialize() async {
    // 初始化 Supabase 服務
    await _supabaseService.initialize();
    debugPrint('AuthService 初始化完成');
  }

  // 使用 Google 登入
  Future<AuthResponse?> signInWithGoogle(BuildContext context) async {
    try {
      // 從環境變量中獲取 Google 客戶端 ID
      final androidClientId = dotenv.env['GOOGLE_CLIENT_ID_ANDROID'];
      // Web 客戶端 ID，從 google-services.json 中獲取
      final webClientId = dotenv.env['GOOGLE_CLIENT_ID_WEB'];

      debugPrint('使用 Google 客戶端 ID: $androidClientId');
      debugPrint('使用 Web 客戶端 ID: $webClientId');

      // 使用谷歌登入
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: androidClientId,
        serverClientId: webClientId, // 使用 Web 客戶端 ID 作為 serverClientId
      );

      // 啟動 Google 登入流程
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

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
        throw Exception('無法獲取 Google 訪問令牌');
      }

      if (idToken == null) {
        throw Exception('無法獲取 Google ID 令牌');
      }

      // 使用 OAuth 登入 Supabase
      final response = await _supabaseService.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return response;
    } catch (error) {
      debugPrint('Google 登入錯誤: $error');
      rethrow;
    }
  }

  // 登出
  Future<void> signOut() async {
    await _supabaseService.client.auth.signOut();
  }

  // 檢查用戶是否已登錄
  bool isLoggedIn() {
    return _supabaseService.client.auth.currentUser != null;
  }

  // 獲取當前用戶
  User? getCurrentUser() {
    return _supabaseService.client.auth.currentUser;
  }

  // 檢查是否為成大信箱
  bool isNCKUEmail(String? email) {
    if (email == null) return false;
    return email.toLowerCase().contains('ncku.edu.tw');
  }
}
