import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 圖片緩存類型
enum CacheType {
  avatar, // 用戶頭像
  restaurant, // 餐廳圖片
  chat, // 聊天圖片
}

/// 圖片緩存服務
/// 提供統一的圖片緩存管理，自動清理過期緩存
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  /// 用戶頭像緩存管理器
  /// - 7天過期
  /// - 最多100個文件
  static CacheManager? _avatarCacheManager;
  CacheManager get avatarCacheManager {
    _avatarCacheManager ??= CacheManager(
      Config(
        'avatar_cache',
        stalePeriod: const Duration(days: 7), // 7天後過期
        maxNrOfCacheObjects: 100, // 最多100個文件
        repo: JsonCacheInfoRepository(databaseName: 'avatar_cache'),
        fileService: HttpFileService(),
      ),
    );
    return _avatarCacheManager!;
  }

  /// 餐廳圖片緩存管理器
  /// - 7天過期
  /// - 最多200個文件
  static CacheManager? _restaurantCacheManager;
  CacheManager get restaurantCacheManager {
    _restaurantCacheManager ??= CacheManager(
      Config(
        'restaurant_cache',
        stalePeriod: const Duration(days: 7), // 7天後過期
        maxNrOfCacheObjects: 200, // 最多200個文件
        repo: JsonCacheInfoRepository(databaseName: 'restaurant_cache'),
        fileService: HttpFileService(),
      ),
    );
    return _restaurantCacheManager!;
  }

  /// 聊天圖片緩存管理器
  /// - 30天過期（聊天圖片需要更長的保存時間）
  /// - 最多500個文件
  static CacheManager? _chatCacheManager;
  CacheManager get chatCacheManager {
    _chatCacheManager ??= CacheManager(
      Config(
        'chat_cache',
        stalePeriod: const Duration(days: 30), // 30天後過期
        maxNrOfCacheObjects: 500, // 最多500個文件
        repo: JsonCacheInfoRepository(databaseName: 'chat_cache'),
        fileService: HttpFileService(),
      ),
    );
    return _chatCacheManager!;
  }

  /// 根據類型獲取對應的緩存管理器
  CacheManager getCacheManager(CacheType type) {
    switch (type) {
      case CacheType.avatar:
        return avatarCacheManager;
      case CacheType.restaurant:
        return restaurantCacheManager;
      case CacheType.chat:
        return chatCacheManager;
    }
  }

  /// 獲取緩存的圖片文件
  ///
  /// [url] 圖片的網路 URL
  /// [type] 緩存類型
  ///
  /// 返回緩存的文件，如果緩存不存在或已過期，會自動下載
  Future<File?> getCachedImage(String url, CacheType type) async {
    try {
      final cacheManager = getCacheManager(type);
      final file = await cacheManager.getSingleFile(url);
      return file;
    } catch (e) {
      debugPrint('獲取緩存圖片失敗: $e');
      return null;
    }
  }

  /// 預緩存圖片（用於提前下載）
  ///
  /// [url] 圖片的網路 URL
  /// [type] 緩存類型
  Future<void> precacheImage(String url, CacheType type) async {
    try {
      final cacheManager = getCacheManager(type);
      await cacheManager.downloadFile(url);
      debugPrint('預緩存圖片成功: $url');
    } catch (e) {
      debugPrint('預緩存圖片失敗: $e');
    }
  }

  /// 清除特定類型的所有緩存
  ///
  /// [type] 要清除的緩存類型
  Future<void> clearCache(CacheType type) async {
    try {
      final cacheManager = getCacheManager(type);
      await cacheManager.emptyCache();
      debugPrint('已清除 ${type.name} 緩存');
    } catch (e) {
      debugPrint('清除緩存失敗: $e');
    }
  }

  /// 清除所有類型的緩存
  Future<void> clearAllCache() async {
    await Future.wait([
      clearCache(CacheType.avatar),
      clearCache(CacheType.restaurant),
      clearCache(CacheType.chat),
    ]);
    debugPrint('已清除所有圖片緩存');
  }

  /// 使用自定義 key 預緩存圖片
  ///
  /// [url] 圖片的網路 URL
  /// [key] 自定義的緩存 key（例如使用 avatar_path）
  /// [type] 緩存類型
  Future<void> precacheImageWithKey(
    String url,
    String key,
    CacheType type,
  ) async {
    try {
      final cacheManager = getCacheManager(type);
      await cacheManager.downloadFile(url, key: key);
      debugPrint('預緩存圖片成功 (key: $key): $url');
    } catch (e) {
      debugPrint('預緩存圖片失敗: $e');
    }
  }

  /// 使用自定義 key 獲取緩存的圖片文件
  ///
  /// [key] 自定義的緩存 key
  /// [type] 緩存類型
  Future<File?> getCachedImageByKey(String key, CacheType type) async {
    try {
      final cacheManager = getCacheManager(type);
      final fileInfo = await cacheManager.getFileFromCache(key);
      return fileInfo?.file;
    } catch (e) {
      debugPrint('獲取緩存圖片失敗: $e');
      return null;
    }
  }

  /// 清除特定 key 的緩存
  Future<void> clearCacheByKey(String key, CacheType type) async {
    try {
      final cacheManager = getCacheManager(type);
      await cacheManager.removeFile(key);
      debugPrint('已清除快取 (key: $key)');
    } catch (e) {
      debugPrint('清除快取失敗: $e');
    }
  }

  // 注意：flutter_cache_manager 會自動管理緩存大小和過期時間
  // 根據配置，頭像和餐廳圖片都會在 7 天後自動刪除
  // 當文件數量超過上限時，會使用 LRU 策略自動清理最舊的文件
}
