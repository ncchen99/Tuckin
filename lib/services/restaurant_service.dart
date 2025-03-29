import 'package:flutter/material.dart';
import 'package:tuckin/services/api_service.dart';
import 'package:tuckin/services/places_service.dart';

/// 餐廳服務 - 處理餐廳相關的API請求和數據操作
class RestaurantService {
  static final RestaurantService _instance = RestaurantService._internal();
  factory RestaurantService() => _instance;
  RestaurantService._internal();

  final ApiService _apiService = ApiService();
  final PlacesService _placesService = PlacesService();

  // 餐廳當前ID計數器（僅用於前端測試）
  int _restaurantIdCounter = 3; // 從3開始，避免與範例數據衝突

  /// 獲取推薦餐廳列表
  Future<List<Map<String, dynamic>>> getRecommendedRestaurants() async {
    try {
      // TODO: 實際項目中應當從後端API獲取推薦餐廳列表
      // 這裡使用模擬數據
      await Future.delayed(const Duration(milliseconds: 500)); // 模擬網路延遲

      return [
        {
          'id': 1,
          'name': '小山丘咖啡廳',
          'imageUrl':
              'https://images.unsplash.com/photo-1542181961-9590d0c79dab?q=80&w=500',
          'category': '咖啡 / 輕食',
          'address': '台北市信義區松壽路2號',
          'mapUrl': 'https://maps.app.goo.gl/5JiNYEdFnJ2y6Ny79',
        },
        {
          'id': 2,
          'name': '水岸義式餐廳',
          'imageUrl':
              'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=500',
          'category': '義式料理',
          'address': '台北市中正區羅斯福路三段28號',
          'mapUrl': 'https://maps.app.goo.gl/YHnNvgPeYhRJPqcT6',
        },
      ];
    } catch (e) {
      debugPrint('獲取推薦餐廳出錯: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(message: '獲取推薦餐廳時發生錯誤: $e');
    }
  }

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
  Future<bool> submitSelectedRestaurant(int restaurantId) async {
    try {
      // TODO: 實際項目中應當向後端API提交選定的餐廳
      // 這裡使用模擬延遲
      await Future.delayed(const Duration(seconds: 1));

      // 模擬成功
      return true;
    } catch (e) {
      debugPrint('提交餐廳選擇出錯: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(message: '提交餐廳選擇時發生錯誤: $e');
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
    String imageUrl =
        'https://images.unsplash.com/photo-1552566626-52f8b828add9?q=80&w=500'; // 預設圖片
    if (placeData['photos'] != null &&
        (placeData['photos'] as List).isNotEmpty) {
      imageUrl = placeData['photos'][0];
    }

    return {
      'id': id,
      'name': placeData['name'],
      'imageUrl': imageUrl,
      'category': placeData['category'],
      'address': placeData['address'],
      'mapUrl': providedMapLink ?? placeData['mapUrl'],
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
