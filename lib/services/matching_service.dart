import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tuckin/services/api_service.dart';
import 'package:tuckin/services/error_handler.dart';
import 'package:tuckin/utils/dinner_time_utils.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart'; // 需要AuthService來獲取token
import 'supabase_service.dart';

/// 加入配對回應模型
class JoinMatchingResponse {
  final String status;
  final String message;
  final String? groupId;
  final DateTime? deadline;

  JoinMatchingResponse({
    required this.status,
    required this.message,
    this.groupId,
    this.deadline,
  });

  factory JoinMatchingResponse.fromJson(Map<String, dynamic> json) {
    return JoinMatchingResponse(
      status: json['status'],
      message: json['message'],
      groupId: json['group_id'],
      deadline:
          json['deadline'] != null
              ? DinnerTimeUtils.parseTimezoneAwareDateTime(json['deadline'])
              : null,
    );
  }
}

/// 配對相關的API服務
class MatchingService {
  static final MatchingService _instance = MatchingService._internal();
  factory MatchingService() => _instance;
  MatchingService._internal();

  final ApiService _apiService = ApiService();
  final ErrorHandler _errorHandler = ErrorHandler();
  final AuthService _authService = AuthService(); // 引入AuthService
  final SupabaseService _supabaseService = SupabaseService();

  // 後端API基礎URL (從ApiService獲取或直接定義)
  // 假設ApiService已經有方法獲取baseUrl和headers
  // final String _baseUrl = ApiService().baseUrl;

  /// 加入配對請求模型 (目前後端似乎不需要特別的請求體，但保留結構)
  // class JoinMatchingRequest {
  //   // 可能需要的參數
  // }

  /// 用戶參加聚餐配對
  Future<JoinMatchingResponse> joinMatching() async {
    const String endpoint = '/matching/join'; // API端點路徑
    // 注意：確保ApiService中的baseUrl是正確的後端地址
    final Uri url = Uri.parse('${_apiService.baseUrl}$endpoint');

    try {
      // 從AuthService獲取當前用戶的JWT令牌
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw ApiError(message: '用戶未登入，無法參加配對');
      }
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw ApiError(message: '無法獲取用戶Session，無法參加配對');
      }
      final String token = session.accessToken;

      // 使用ApiService的handleRequest來包裝請求
      final result = await _apiService.handleRequest<JoinMatchingResponse>(
        request: () async {
          final httpResponse = await http.post(
            url,
            headers: {
              ..._apiService.headers, // 使用ApiService的通用請求頭
              'Authorization': 'Bearer $token', // 添加Authorization頭
            },
            // 後端目前不需要body，如果需要，在這裡添加
            body: jsonEncode({}), // 添加空的JSON body
          );

          // 檢查HTTP狀態碼
          if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
            // 強制使用UTF-8解碼
            final String decodedBody = utf8.decode(httpResponse.bodyBytes);
            // 解碼響應體
            final Map<String, dynamic> responseData = jsonDecode(
              decodedBody, // 使用解碼後的字串
            );
            return JoinMatchingResponse.fromJson(responseData);
          } else {
            // 處理非2xx的狀態碼
            debugPrint('加入配對失敗，狀態碼: ${httpResponse.statusCode}');
            // 強制使用UTF-8解碼
            final String decodedBody = utf8.decode(httpResponse.bodyBytes);
            debugPrint('回應內容 (UTF-8解碼後): $decodedBody');
            // 嘗試解析錯誤信息
            String errorMessage = '加入配對失敗 (${httpResponse.statusCode})';
            try {
              final errorData = jsonDecode(decodedBody);
              errorMessage = errorData['detail'] ?? errorMessage;
            } catch (_) {
              // 如果無法解析JSON，使用原始body或通用錯誤
              errorMessage =
                  decodedBody.isNotEmpty ? decodedBody : errorMessage;
            }
            throw ApiError(
              message: errorMessage,
              isServerError: httpResponse.statusCode >= 500,
            );
          }
        },
        // 可以為這個特定請求設置不同的超時時間
        timeout: const Duration(seconds: 30),
      );

      return result;
    } on ApiError catch (e) {
      // 由 ApiService 的 handleRequest 處理了常規錯誤，這裡可以選擇是否重新拋出或處理特定邏輯
      _errorHandler.handleApiError(e, () => joinMatching());
      rethrow; // 重新拋出，讓調用者知道出錯了
    } catch (e) {
      // 處理其他意外錯誤
      debugPrint('調用 joinMatching 時發生未知錯誤: $e');
      _errorHandler.handleApiError(
        ApiError(message: '參加配對時發生未知錯誤: $e', isServerError: true),
        () => joinMatching(),
      );
      rethrow;
    }
  }

  /// 獲取用戶當前的匹配群組信息
  Future<Map<String, dynamic>?> getCurrentMatchingInfo() async {
    try {
      // 獲取當前用戶ID
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw ApiError(message: '用戶未登入，無法獲取配對信息');
      }
      final userId = currentUser.id;

      // 從user_matching_info表獲取用戶當前的匹配群組信息
      return _apiService.handleRequest(
        request: () async {
          final response =
              await _supabaseService.client
                  .from('user_matching_info')
                  .select('*')
                  .eq('user_id', userId)
                  .order('created_at', ascending: false)
                  .maybeSingle();

          if (response == null) {
            debugPrint('用戶 $userId 目前沒有配對記錄');
            return null;
          }

          debugPrint('獲取到用戶 $userId 的配對信息: $response');
          return response;
        },
      );
    } on ApiError catch (e) {
      _errorHandler.handleApiError(e, () => getCurrentMatchingInfo());
      rethrow;
    } catch (e) {
      debugPrint('獲取用戶配對信息時發生錯誤: $e');
      _errorHandler.handleApiError(
        ApiError(message: '獲取用戶配對信息時發生未知錯誤: $e'),
        () => getCurrentMatchingInfo(),
      );
      rethrow;
    }
  }
}
