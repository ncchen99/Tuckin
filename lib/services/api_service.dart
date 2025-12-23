import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiError implements Exception {
  final String message;
  final bool isTimeout;
  final bool isServerError;
  final bool isNetworkError;

  ApiError({
    required this.message,
    this.isTimeout = false,
    this.isServerError = false,
    this.isNetworkError = false,
  });

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // 默認超時時間為15秒（iOS可能需要更長時間）
  static const Duration defaultTimeout = Duration(seconds: 15);

  // 後端API基礎URL
  final String baseUrl = 'https://tuckin.fly.dev/api';
  // kDebugMode
  //     ? 'http://10.0.2.2:8000/api' // Debug 模式下，模擬器連接本地主機的 URL
  //     : 'https://tuckin-api-c6943d8e20da.herokuapp.com/api'; // Release 模式下的生產 URL

  // 通用請求頭
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// 包裝 API 請求並處理錯誤
  Future<T> handleRequest<T>({
    required Future<T> Function() request,
    Duration timeout = defaultTimeout,
  }) async {
    try {
      // 使用 timeout 來限制請求時間
      final result = await request().timeout(timeout);
      return result;
    } on TimeoutException {
      debugPrint('API請求超時');
      throw ApiError(
        message: '請求超時，請檢查您的網路連接',
        isTimeout: true,
        isNetworkError: true,
      );
    } on SocketException catch (e) {
      debugPrint('網絡連接錯誤: $e');
      throw ApiError(message: '網絡連接錯誤，請檢查您的網絡設置', isNetworkError: true);
    } on PostgrestException catch (e) {
      debugPrint('Supabase錯誤: ${e.message}');
      throw ApiError(message: '伺服器錯誤: ${e.message}', isServerError: true);
    } on AuthException catch (e) {
      debugPrint('Supabase認證錯誤: ${e.message}');
      // 檢查錯誤信息中是否包含網絡相關的錯誤
      final bool isNetworkRelated =
          e.message.contains('SocketException') == true ||
          e.message.contains('Connection') == true ||
          e.message.contains('timed out') == true;
      throw ApiError(
        message: isNetworkRelated ? '網絡連接錯誤，請檢查您的網絡設置' : '認證錯誤: ${e.message}',
        isServerError: !isNetworkRelated,
        isNetworkError: isNetworkRelated,
      );
    } catch (e) {
      debugPrint('API請求錯誤: $e');
      // 檢查錯誤信息中是否包含網絡相關的錯誤
      final String errorString = e.toString().toLowerCase();
      final bool isNetworkRelated =
          errorString.contains('socket') ||
          errorString.contains('connection') ||
          errorString.contains('timeout');
      throw ApiError(
        message: isNetworkRelated ? '網絡連接錯誤，請檢查您的網絡設置' : '發生錯誤: $e',
        isServerError: !isNetworkRelated,
        isNetworkError: isNetworkRelated,
      );
    }
  }

  /// 發送GET請求
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      // 獲取當前Session以獲取token
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;

      // 構建請求頭，添加授權token
      final requestHeaders = {...headers};
      if (token != null) {
        requestHeaders['Authorization'] = 'Bearer $token';
      }

      // 構建完整URL
      String url = baseUrl + endpoint;
      if (queryParameters != null && queryParameters.isNotEmpty) {
        final queryString =
            Uri(
              queryParameters: queryParameters.map(
                (key, value) => MapEntry(key, value.toString()),
              ),
            ).query;
        url = '$url?$queryString';
      }

      debugPrint('發送GET請求: $url');
      debugPrint('請求標頭: $requestHeaders');

      // 創建URI對象
      final uri = Uri.parse(url);

      // 使用http庫發送請求，iOS 平台使用更長的超時時間
      final Duration requestTimeout =
          Platform.isIOS ? const Duration(seconds: 20) : defaultTimeout;

      final response = await handleRequest(
        request: () => http.get(uri, headers: requestHeaders),
        timeout: requestTimeout,
      );

      debugPrint('GET響應狀態碼: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 嘗試解析響應內容
        final responseBody = utf8.decode(response.bodyBytes);
        debugPrint('GET響應內容: $responseBody');

        if (responseBody.trim().isNotEmpty) {
          return jsonDecode(responseBody);
        }
        return null;
      } else {
        String errorMessage;
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          errorMessage = errorData['detail'] ?? '伺服器錯誤: ${response.statusCode}';
        } catch (_) {
          errorMessage = '伺服器錯誤: ${response.statusCode}';
        }

        throw ApiError(message: errorMessage, isServerError: true);
      }
    } catch (e) {
      debugPrint('GET請求失敗: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(message: '請求失敗: $e');
    }
  }
}
