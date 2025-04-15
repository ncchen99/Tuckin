import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // 默認超時時間為10秒
  static const Duration defaultTimeout = Duration(seconds: 10);

  // 後端API基礎URL
  final String baseUrl = 'https://tuckin-backend.example.com/api';

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
}
