import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_service.dart';
import 'error_handler.dart';

/// 基礎 Supabase 服務，負責初始化和提供 Supabase 客戶端實例
class SupabaseService {
  // 單例模式
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Supabase 客戶端實例
  late final SupabaseClient _supabaseClient;
  final ApiService _apiService = ApiService();
  final ErrorHandler _errorHandler = ErrorHandler();

  // 獲取 Supabase 客戶端
  SupabaseClient get client {
    return _supabaseClient;
  }

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
        throw ApiError(
          message:
              'Supabase 配置缺失。請確保 .env 文件中有 SUPABASE_URL 和 SUPABASE_ANON_KEY',
          isServerError: false,
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

      await _apiService.handleRequest(
        request:
            () => Supabase.initialize(
              url: url,
              anonKey: anonKey,
              // 確保啟用實時功能
              realtimeClientOptions: const RealtimeClientOptions(
                eventsPerSecond: 10,
              ),
            ),
      );

      _supabaseClient = Supabase.instance.client;

      // 確認實時功能已啟用
      final realtimeEnabled = _supabaseClient.realtime != null;
      debugPrint('Supabase 初始化成功，實時功能: ${realtimeEnabled ? "已啟用" : "未啟用"}');

      // 測試一下實時連接是否正常
      try {
        final channel = _supabaseClient.channel('test_connection');
        await channel.subscribe();
        debugPrint('Supabase 實時連接測試成功，可以訂閱資料變更');
        await channel.unsubscribe();
      } catch (e) {
        debugPrint('Supabase 實時連接測試失敗: $e');
      }
    } catch (error) {
      debugPrint('Supabase 初始化錯誤: $error');
      _errorHandler.handleApiError(
        ApiError(message: 'Supabase 初始化失敗: $error', isServerError: true),
        () => initialize(),
      );
      rethrow;
    }
  }

  // 獲取當前用戶
  Future<User?> getCurrentUser() async {
    try {
      return await _apiService.handleRequest(
        request: () async => _supabaseClient.auth.currentUser,
      );
    } catch (error) {
      debugPrint('獲取當前用戶錯誤: $error');
      _errorHandler.handleApiError(
        ApiError(message: '獲取當前用戶失敗: $error', isServerError: true),
        () => getCurrentUser(),
      );
      return null;
    }
  }

  // 獲取 auth 實例
  GoTrueClient get auth {
    return _supabaseClient.auth;
  }

  // 刷新會話
  Future<void> refreshSession() async {
    try {
      await _apiService.handleRequest(
        request: () => _supabaseClient.auth.refreshSession(),
      );
    } catch (error) {
      debugPrint('刷新會話錯誤: $error');
      _errorHandler.handleApiError(
        ApiError(message: '刷新會話失敗: $error', isServerError: true),
        () => refreshSession(),
      );
      rethrow;
    }
  }

  // 檢查連接狀態
  Future<bool> checkConnection() async {
    try {
      await _apiService.handleRequest(
        request: () async {
          final session = _supabaseClient.auth.currentSession;
          return session != null;
        },
      );
      return true;
    } catch (error) {
      debugPrint('檢查連接狀態錯誤: $error');
      return false;
    }
  }
}
