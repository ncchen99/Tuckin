import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 基礎 Supabase 服務，負責初始化和提供 Supabase 客戶端實例
class SupabaseService {
  // 單例模式
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  // Supabase 客戶端實例
  late final SupabaseClient _supabaseClient;

  // 獲取 Supabase 客戶端
  SupabaseClient get client => _supabaseClient;

  // 初始化 Supabase
  Future<void> initialize() async {
    try {
      // 檢查環境變數文件內容
      final envVars = dotenv.env;
      debugPrint('環境變數數量: ${envVars.length}');

      // 從 .env 文件中讀取配置
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      debugPrint('Supabase URL: $supabaseUrl');
      debugPrint('Supabase Anon Key 長度: ${supabaseAnonKey.length}');

      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        throw Exception(
          '警告: Supabase 配置缺失。請確保 .env 文件中有 SUPABASE_URL 和 SUPABASE_ANON_KEY',
        );
      }

      // 使用硬編碼的值作為備份
      final url =
          supabaseUrl.isNotEmpty
              ? supabaseUrl
              : 'https://vnovnsunudotmlkrrvqk.supabase.co';

      final anonKey =
          supabaseAnonKey.isNotEmpty
              ? supabaseAnonKey
              : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZub3Zuc3VudWRvdG1sa3JydnFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIyMjYxMjAsImV4cCI6MjA1NzgwMjEyMH0.5F5d-ULYVDsmx86r-ULMaS3pDfjJR05yKjaWEq69-5k';

      debugPrint('初始化 Supabase 使用 URL: $url');

      await Supabase.initialize(url: url, anonKey: anonKey);
      _supabaseClient = Supabase.instance.client;
      debugPrint('Supabase 初始化成功');
    } catch (error) {
      debugPrint('Supabase 初始化錯誤: $error');
      rethrow;
    }
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
      final response = await _supabaseClient.auth.signInWithIdToken(
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
    await _supabaseClient.auth.signOut();
  }

  // 檢查用戶是否已登錄
  bool isLoggedIn() {
    return _supabaseClient.auth.currentUser != null;
  }

  // 獲取當前用戶
  User? getCurrentUser() {
    return _supabaseClient.auth.currentUser;
  }
}
