import 'package:flutter/material.dart';
import '../core/api_service.dart';

/// 餐廳相關服務 (通過後端API實現)
class PlacesService {
  static final PlacesService _instance = PlacesService._internal();
  factory PlacesService() => _instance;
  PlacesService._internal();

  final ApiService _apiService = ApiService();

  /// 處理Google地圖連結並提取餐廳信息 (通過後端API)
  Future<Map<String, dynamic>> processMapLink(String mapLink) async {
    try {
      debugPrint('正在處理Google地圖連結: $mapLink');

      // 使用API進行地圖連結處理
      final response = await _apiService.get(
        '/restaurant/search',
        queryParameters: {'query': mapLink},
      );

      // 檢查API返回數據
      if (response != null && response is List && response.isNotEmpty) {
        // 使用第一個結果
        final restaurantData = response[0];

        // 提取餐廳ID
        final id = restaurantData['id'];

        // 將API返回的數據轉換為前端所需格式
        return {
          'id': id,
          'name': restaurantData['name'] ?? '未知餐廳',
          'address': restaurantData['address'] ?? '地址不詳',
          'category': restaurantData['category'] ?? '用戶推薦',
          'mapUrl': mapLink,
          'rating': 0.0, // API未提供評分，使用默認值
          'openingHours': restaurantData['business_hours'] ?? '資訊待補充',
          'photos': _getImageUrlList(restaurantData['image_path']),
          'imageUrl': _getImageUrl(restaurantData['image_path']),
          'website': restaurantData['website'] ?? '',
          'phone': restaurantData['phone'] ?? '',
        };
      } else {
        throw ApiError(message: '無法識別該地圖連結的餐廳資訊');
      }
    } catch (e) {
      debugPrint('處理地圖連結出錯: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(message: '處理地圖連結時發生錯誤: $e');
    }
  }

  /// 生成模擬餐廳數據（用於測試）
  Map<String, dynamic> generateSampleRestaurantData(int id, [String? mapLink]) {
    return {
      'id': id,
      'name': '測試餐廳 $id',
      'imageUrl':
          'https://images.unsplash.com/photo-1552566626-52f8b828add9?q=80&w=500',
      'category': '日式料理',
      'address': '台北市大安區信義路四段$id號',
      'mapUrl': mapLink ?? 'https://maps.app.goo.gl/example',
      'rating': 4.5,
      'openingHours': '09:00 - 21:00',
      'photos': [
        'https://images.unsplash.com/photo-1552566626-52f8b828add9?q=80&w=500',
        'https://images.unsplash.com/photo-1514933651103-005eec06c04b?q=80&w=500',
        'https://images.unsplash.com/photo-1552566626-52f8b828add9?q=80&w=500',
      ],
    };
  }

  // 處理圖片URL，確保返回有效的URL或預設圖片路徑
  String _getImageUrl(String? imageUrl) {
    // 如果URL為空，返回預設圖片
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return 'assets/images/placeholder/restaurant.jpg';
    }

    // 檢查是否已經是完整URL
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }

    // 檢查是否是本地資源路徑
    if (imageUrl.startsWith('assets/')) {
      return imageUrl;
    }

    // 默認返回預設圖片
    return 'assets/images/placeholder/restaurant.jpg';
  }

  // 處理圖片URL列表
  List<String> _getImageUrlList(String? imageUrl) {
    final url = _getImageUrl(imageUrl);
    return [url];
  }
}
