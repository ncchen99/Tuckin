import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tuckin/services/api_service.dart';

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

      // 在實際環境中，我們會將地圖連結發送到後端進行處理
      // 這裡使用模擬數據模擬API響應
      await Future.delayed(const Duration(seconds: 1));

      // 從地圖連結中提取餐廳名稱（這只是一個簡單的模擬邏輯）
      // 實際情況下，後端應使用專門的API解析連結
      String restaurantName = '用戶推薦的餐廳';

      // 檢查連結是否包含特定字符，如餐廳名稱
      if (mapLink.contains('maps.app.goo.gl') ||
          mapLink.contains('goo.gl/maps')) {
        restaurantName = '用戶推薦的Google地圖餐廳';
      } else if (mapLink.contains('maps.google.com')) {
        // 嘗試從連結中提取名稱或地址部分（這裡是簡化邏輯）
        if (mapLink.contains('search')) {
          // 嘗試解析搜索查詢
          final searchStart = mapLink.indexOf('search/') + 7;
          final searchEnd = mapLink.indexOf('/', searchStart);
          if (searchStart > 7 && searchEnd > searchStart) {
            final searchQuery = mapLink.substring(searchStart, searchEnd);
            restaurantName = Uri.decodeComponent(
              searchQuery.replaceAll('+', ' '),
            );
          }
        }
      }

      // 模擬從後端獲得的餐廳信息
      final int id = DateTime.now().millisecondsSinceEpoch;
      return {
        'id': id,
        'name': restaurantName,
        'address': '根據地圖連結解析的地址',
        'category': '用戶推薦',
        'mapUrl': mapLink,
        'rating': 0.0,
        'openingHours': '資訊待補充',
        'photos': [
          'https://images.unsplash.com/photo-1552566626-52f8b828add9?q=80&w=500',
        ],
        'imageUrl':
            'https://images.unsplash.com/photo-1552566626-52f8b828add9?q=80&w=500',
        'website': '',
      };
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
      'address': '台北市大安區信義路四段${id}號',
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
}
