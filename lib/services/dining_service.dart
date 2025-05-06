import 'package:flutter/material.dart';
import 'package:tuckin/services/api_service.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/supabase_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 聚餐服務 - 處理聚餐事件相關的API請求
class DiningService {
  // 單例模式
  static final DiningService _instance = DiningService._internal();
  factory DiningService() => _instance;
  DiningService._internal();

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService();

  /// 開始確認餐廳預訂
  ///
  /// 設置聚餐事件狀態為confirming，表示用戶開始聯繫餐廳進行預訂
  /// 自動在9.9分鐘後檢查並重置未完成的確認狀態
  Future<Map<String, dynamic>> startConfirming(String eventId) async {
    try {
      debugPrint('開始確認餐廳預訂，聚餐事件ID: $eventId');

      // 獲取當前用戶認證
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('用戶未登入');
      }

      // 獲取 session
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw Exception('無法獲取用戶登入資訊，請重新登入');
      }

      // 構建API請求
      final endpoint = '/dining/start-confirming/$eventId';
      final apiUrl = '${_apiService.baseUrl}$endpoint';

      // 發送POST請求
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({}), // 空的請求體，因為所有信息都在URL中
      );

      // 檢查回應狀態
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 成功發送請求
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('餐廳確認請求成功: $responseData');
        return responseData;
      } else {
        // 請求失敗
        String errorMessage;
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          errorMessage = errorData['detail'] ?? '操作失敗 (${response.statusCode})';
        } catch (_) {
          errorMessage = '操作失敗 (${response.statusCode})';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('餐廳確認請求錯誤: $e');
      rethrow;
    }
  }

  /// 更換餐廳
  ///
  /// 當當前餐廳不可預訂時，從候選餐廳列表中選擇下一個餐廳
  Future<Map<String, dynamic>> changeRestaurant(String eventId) async {
    try {
      debugPrint('更換餐廳，聚餐事件ID: $eventId');

      // 獲取當前用戶認證
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('用戶未登入');
      }

      // 獲取 session
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw Exception('無法獲取用戶登入資訊，請重新登入');
      }

      // 構建API請求
      final endpoint = '/dining/change-restaurant/$eventId';
      final apiUrl = '${_apiService.baseUrl}$endpoint';

      // 發送POST請求
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({}), // 空的請求體，因為所有信息都在URL中
      );

      // 檢查回應狀態
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 成功發送請求
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('更換餐廳請求成功: $responseData');
        return responseData;
      } else {
        // 請求失敗
        String errorMessage;
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          errorMessage = errorData['detail'] ?? '操作失敗 (${response.statusCode})';
        } catch (_) {
          errorMessage = '操作失敗 (${response.statusCode})';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('更換餐廳請求錯誤: $e');
      rethrow;
    }
  }

  /// 確認餐廳預訂成功
  ///
  /// 將聚餐事件狀態更新為confirmed，完成餐廳預訂流程
  Future<Map<String, dynamic>> confirmRestaurant(
    String eventId, {
    String? reservationName,
    String? reservationPhone,
  }) async {
    try {
      debugPrint('確認餐廳預訂成功，聚餐事件ID: $eventId');

      // 獲取當前用戶認證
      final currentUser = await _authService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('用戶未登入');
      }

      // 獲取 session
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw Exception('無法獲取用戶登入資訊，請重新登入');
      }

      // 構建請求體
      final Map<String, dynamic> requestBody = {
        // 確保總是傳遞這些參數，即使為空值
        'reservation_name': reservationName ?? '',
        'reservation_phone': reservationPhone ?? '',
      };

      // 構建API請求
      final endpoint = '/dining/confirm-restaurant/$eventId';
      final apiUrl = '${_apiService.baseUrl}$endpoint';

      // 發送POST請求
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode(requestBody),
      );

      // 檢查回應狀態
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 成功發送請求
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('確認餐廳預訂請求成功: $responseData');
        return responseData;
      } else {
        // 請求失敗
        String errorMessage;
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          errorMessage = errorData['detail'] ?? '操作失敗 (${response.statusCode})';
        } catch (_) {
          errorMessage = '操作失敗 (${response.statusCode})';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('確認餐廳預訂請求錯誤: $e');
      rethrow;
    }
  }

  /// 獲取聚餐事件詳情
  Future<Map<String, dynamic>> getDiningEventDetails(String eventId) async {
    try {
      debugPrint('獲取聚餐事件詳情，事件ID: $eventId');

      // 構建API請求
      final endpoint = '/dining/events/$eventId';

      // 發送GET請求
      final response = await _apiService.get(endpoint);

      debugPrint('獲取聚餐事件詳情成功: $response');
      return response;
    } catch (e) {
      debugPrint('獲取聚餐事件詳情錯誤: $e');
      rethrow;
    }
  }
}
