import 'package:flutter/material.dart';
import 'package:tuckin/services/api_service.dart';
import 'package:tuckin/services/places_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:tuckin/services/supabase_service.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 餐廳服務 - 處理餐廳相關的API請求和數據操作
class RestaurantService {
  static final RestaurantService _instance = RestaurantService._internal();
  factory RestaurantService() => _instance;
  RestaurantService._internal();

  final ApiService _apiService = ApiService();
  final PlacesService _placesService = PlacesService();
  final DatabaseService _databaseService = DatabaseService();
  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService = AuthService();

  // 餐廳當前ID計數器（僅用於前端測試）
  int _restaurantIdCounter = 3; // 從3開始，避免與範例數據衝突

  /// 處理Google地圖連結
  Future<Map<String, dynamic>> processMapLink(String mapLink) async {
    try {
      // 使用Places服務處理地圖連結
      final restaurantData = await _placesService.processMapLink(mapLink);

      // 轉換為前端所需格式
      return _convertToFrontendRestaurantFormat(restaurantData, mapLink);
    } catch (e) {
      debugPrint('處理Google地圖連結出錯: $e');
      rethrow;
    }
  }

  /// 提交選定的餐廳
  Future<Map<String, dynamic>> submitSelectedRestaurant(
    dynamic restaurantId,
  ) async {
    try {
      final String apiEndpoint = '${_apiService.baseUrl}/restaurant/vote';

      // 獲取當前用戶
      final currentUser = await _authService.getCurrentUser();

      if (currentUser == null) {
        throw ApiError(message: '未登入，無法進行餐廳投票');
      }

      // 獲取 session
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw ApiError(message: '無法獲取用戶登入資訊，請重新登入');
      }

      // 準備請求資料
      final requestData = {
        'restaurant_id': restaurantId.toString(), // 確保 restaurant_id 是字串類型
        'is_system_recommendation': false, // 從 APP 發出的請求一律設為 false
      };

      // 發送請求
      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode(requestData),
      );

      // 檢查回應狀態
      if (response.statusCode == 200) {
        // 成功投票
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('餐廳投票成功: $responseData');
        return responseData;
      } else {
        // 投票失敗
        String errorMessage;
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          errorMessage = errorData['detail'] ?? '投票失敗 (${response.statusCode})';
        } catch (_) {
          errorMessage = '投票失敗 (${response.statusCode})';
        }
        throw ApiError(message: errorMessage);
      }
    } catch (e) {
      debugPrint('提交餐廳選擇出錯: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(message: '提交餐廳選擇時發生錯誤: $e');
    }
  }

  /// 獲取票數最高的兩家餐廳
  ///
  /// [groupId] 配對群組ID
  Future<List<Map<String, dynamic>>> getTopVotedRestaurants(
    String groupId,
  ) async {
    try {
      // 使用 get_group_votes 函數獲取餐廳投票數據
      final result =
          await _supabaseService.client
              .rpc('get_group_votes', params: {'group_uuid': groupId})
              .select();

      if (result == null || result.isEmpty) {
        debugPrint('沒有找到群組 $groupId 的餐廳投票數據');
        return [];
      }

      // 輸出原始投票數據用於調試
      debugPrint('原始投票數據: $result');

      // 計算每家餐廳的投票數
      Map<String, int> voteCountMap = {};

      // 檢查 SQL 函數返回的數據格式
      for (var item in result) {
        debugPrint('投票項目: $item');
        // 分析每條投票的內容
        final Map<String, dynamic> vote = item;
        final String restaurantId = vote['restaurant_id'] as String;
        // 檢查是否有 user_id 字段，及其值是否為 null
        final hasUserIdField = vote.containsKey('user_id');
        final userId = vote['user_id'];
        final bool isSystemRecommendation =
            vote['is_system_recommendation'] as bool? ?? false;

        debugPrint(
          '餐廳 ID: $restaurantId, 有 user_id 字段: $hasUserIdField, user_id: $userId, 系統推薦: $isSystemRecommendation',
        );

        // 初始化餐廳投票計數
        voteCountMap[restaurantId] ??= 0;

        // 修改計數邏輯：如果不是系統推薦，則增加計數
        if (!isSystemRecommendation) {
          voteCountMap[restaurantId] = voteCountMap[restaurantId]! + 1;
          debugPrint('增加計數：餐廳 $restaurantId 的票數：${voteCountMap[restaurantId]}');
        }
      }

      // 輸出最終計算的投票數
      debugPrint('最終計算的投票數: $voteCountMap');

      // 按票數從高到低排序
      List<MapEntry<String, int>> sortedVotes =
          voteCountMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      // 提取所有餐廳 ID
      List<String> restaurantIds =
          sortedVotes.map((entry) => entry.key).toList();

      if (restaurantIds.isEmpty) {
        return [];
      }

      // 獲取這些餐廳的詳細資訊
      final restaurantsInfo = await _databaseService.getRestaurantsInfo(
        restaurantIds,
      );

      // 將餐廳信息轉換為前端所需格式，按票數排序
      List<Map<String, dynamic>> resultList = [];

      for (var restaurantId in restaurantIds) {
        final restaurant = restaurantsInfo.firstWhere(
          (r) => r['id'] == restaurantId,
          orElse: () => <String, dynamic>{},
        );

        if (restaurant.isNotEmpty) {
          // 預設圖片路徑
          final defaultImagePath = 'assets/images/placeholder/restaurant.jpg';
          String imageUrl;

          // 檢查 image_path
          if (restaurant['image_path'] == null ||
              restaurant['image_path'].toString().trim().isEmpty) {
            imageUrl = defaultImagePath;
            debugPrint('使用預設圖片路徑: $imageUrl');
          } else {
            imageUrl = restaurant['image_path'];
            debugPrint('使用資料庫圖片路徑: $imageUrl');
          }

          // 投票數
          final votes = voteCountMap[restaurantId] ?? 0;
          debugPrint('餐廳 ${restaurant['name']} 的最終票數: $votes');

          // 建立完整的餐廳名稱和地址查詢參數，用於 Google Maps URL
          final String restaurantName = Uri.encodeComponent(
            restaurant['name'] ?? '',
          );
          final String restaurantAddress = Uri.encodeComponent(
            restaurant['address'] ?? '',
          );
          final String mapUrlQuery = '$restaurantName+$restaurantAddress';

          resultList.add({
            'id': restaurant['id'],
            'name': restaurant['name'],
            'imageUrl': imageUrl,
            'category': restaurant['category'] ?? '',
            'address': restaurant['address'] ?? '',
            'mapUrl': 'https://www.google.com/maps/place/?q=$mapUrlQuery',
            'phone': restaurant['phone'],
            'website': restaurant['website'],
            'business_hours': restaurant['business_hours'],
            'votes': votes,
          });
        }
      }

      return resultList;
    } catch (e) {
      debugPrint('獲取票數最高餐廳出錯: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(message: '獲取票數最高餐廳時發生錯誤: $e');
    }
  }

  /// 將Places API數據轉換為前端所需的餐廳格式
  Map<String, dynamic> _convertToFrontendRestaurantFormat(
    Map<String, dynamic> placeData, [
    String? providedMapLink,
  ]) {
    // 生成唯一ID（實際應用中，這應該由後端提供）
    int id = _restaurantIdCounter++;

    // 使用第一張照片作為主圖
    String imageUrl = 'assets/images/placeholder/restaurant.jpg'; // 預設圖片
    if (placeData['photos'] != null &&
        (placeData['photos'] as List).isNotEmpty) {
      final photo = placeData['photos'][0];
      // 確保照片URL有效，否則使用預設圖片
      imageUrl =
          (photo != null && photo.toString().isNotEmpty) ? photo : imageUrl;
    }

    // 建立餐廳名稱和地址的 Google Maps URL
    final String name = placeData['name'] ?? '';
    final String address = placeData['address'] ?? '';
    final String encodedName = Uri.encodeComponent(name);
    final String encodedAddress = Uri.encodeComponent(address);
    final String mapUrlQuery = '$encodedName+$encodedAddress';
    final String mapUrl =
        providedMapLink ?? 'https://www.google.com/maps/place/?q=$mapUrlQuery';

    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'category': placeData['category'],
      'address': address,
      'mapUrl': mapUrl,
      'rating': placeData['rating'],
      'openingHours': placeData['openingHours'],
      'photos': placeData['photos'] ?? [],
      'website': placeData['website'] ?? '',
    };
  }

  /// 獲取測試餐廳數據（僅用於前端測試）
  Map<String, dynamic> getSampleRestaurantData() {
    return _placesService.generateSampleRestaurantData(_restaurantIdCounter++);
  }
}
