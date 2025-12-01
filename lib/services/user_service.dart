import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'image_cache_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  /// 選擇圖片並轉換為 WebP 格式（512x512）
  Future<Uint8List?> pickAndConvertImageToWebP() async {
    try {
      // 步驟 1: 開啟圖片選擇器
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // 先保持高品質，後續裁剪後再壓縮
      );

      if (pickedFile == null) {
        debugPrint('用戶取消選擇圖片');
        return null;
      }

      debugPrint('原始圖片路徑: ${pickedFile.path}');

      // 步驟 2: 裁剪圖片為方形
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // 1:1 方形比例
        compressQuality: 100, // 裁剪時保持高品質
        maxWidth: 1024, // 裁剪後的最大寬度
        maxHeight: 1024, // 裁剪後的最大高度
        compressFormat: ImageCompressFormat.png, // 裁剪時使用 PNG 格式
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪頭像',
            toolbarColor: const Color(0xFF23456B),
            toolbarWidgetColor: Colors.white,
            backgroundColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFFB33D1C),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true, // 鎖定方形比例
            hideBottomControls: false,
            cropStyle: CropStyle.circle, // 使用圓形裁剪框
          ),
          IOSUiSettings(
            title: '裁剪頭像',
            aspectRatioLockEnabled: true, // 鎖定方形比例
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            rotateButtonsHidden: false,
            cropStyle: CropStyle.circle, // 使用圓形裁剪框
          ),
        ],
      );

      if (croppedFile == null) {
        debugPrint('用戶取消裁剪圖片');
        return null;
      }

      debugPrint('裁剪後圖片路徑: ${croppedFile.path}');

      // 步驟 3: 使用 flutter_image_compress 壓縮為 512x512 的 WebP
      final result = await FlutterImageCompress.compressWithFile(
        croppedFile.path,
        format: CompressFormat.webp,
        quality: 85,
        minWidth: 512,
        minHeight: 512,
      );

      if (result == null) {
        debugPrint('圖片壓縮失敗');
        return null;
      }

      debugPrint('圖片已轉換為 WebP 格式（512x512），大小: ${result.length} bytes');

      return result;
    } catch (e) {
      debugPrint('選擇或轉換圖片時發生錯誤: $e');
      return null;
    }
  }

  /// 獲取頭像上傳 URL
  Future<Map<String, dynamic>?> getAvatarUploadUrl() async {
    try {
      debugPrint('正在獲取頭像上傳 URL...');

      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        debugPrint('未找到用戶 token');
        return null;
      }

      final url = Uri.parse('${_apiService.baseUrl}/user/avatar/upload-url');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('獲取上傳 URL 響應狀態碼: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        debugPrint('成功獲取上傳 URL');
        return data;
      } else {
        debugPrint('獲取上傳 URL 失敗: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('獲取上傳 URL 時發生錯誤: $e');
      return null;
    }
  }

  /// 上傳圖片到 R2
  Future<bool> uploadImageToR2(String uploadUrl, Uint8List imageBytes) async {
    try {
      debugPrint('正在上傳圖片到 R2...');
      debugPrint('圖片大小: ${imageBytes.length} bytes');

      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': 'image/webp'},
        body: imageBytes,
      );

      debugPrint('上傳響應狀態碼: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('圖片上傳成功');
        return true;
      } else {
        debugPrint('圖片上傳失敗: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('上傳圖片時發生錯誤: $e');
      return false;
    }
  }

  /// 完整的頭像上傳流程（優化版：並行處理）
  /// 返回 Map，包含 avatar_path 和 imageBytes（成功時）或 null（失敗時）
  Future<Map<String, dynamic>?> uploadAvatar() async {
    try {
      // 並行處理：同時進行圖片壓縮和獲取上傳 URL
      final results = await Future.wait([
        pickAndConvertImageToWebP(),
        getAvatarUploadUrl(),
      ]);

      final imageBytes = results[0] as Uint8List?;
      final uploadData = results[1] as Map<String, dynamic>?;

      if (imageBytes == null) {
        debugPrint('未選擇圖片或轉換失敗');
        return null;
      }

      if (uploadData == null) {
        debugPrint('獲取上傳 URL 失敗');
        return null;
      }

      final uploadUrl = uploadData['upload_url'] as String;
      final avatarPath = uploadData['avatar_path'] as String;

      // 上傳圖片到 R2
      final uploadSuccess = await uploadImageToR2(uploadUrl, imageBytes);

      if (uploadSuccess) {
        debugPrint('頭像上傳成功，路徑: $avatarPath');
        return {'avatar_path': avatarPath, 'image_bytes': imageBytes};
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('上傳頭像流程發生錯誤: $e');
      return null;
    }
  }

  /// 獲取頭像顯示 URL（自己的）
  Future<String?> getAvatarUrl() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      debugPrint('正在獲取頭像 URL... 用戶 ID: $userId');

      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        debugPrint('未找到用戶 token');
        return null;
      }

      final url = Uri.parse('${_apiService.baseUrl}/user/avatar/url');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('獲取頭像 URL 響應狀態碼: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('獲取頭像 URL 失敗: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final avatarUrl = data['url'] as String?;
        debugPrint('成功獲取頭像 URL');
        return avatarUrl;
      } else if (response.statusCode == 404) {
        // 用戶尚未設置頭像
        debugPrint('用戶尚未設置頭像');
        return null;
      } else {
        debugPrint('獲取頭像 URL 失敗: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('獲取頭像 URL 時發生錯誤: $e');
      return null;
    }
  }

  /// 頭像 URL 緩存有效期（50 分鐘，確保在 presigned URL 過期前使用）
  static const int _avatarUrlCacheValidMs = 50 * 60 * 1000;

  /// 內存中的頭像 URL 緩存（避免每次都讀取 SharedPreferences）
  static final Map<String, String> _avatarUrlMemoryCache = {};
  static final Map<String, int> _avatarUrlMemoryCacheTime = {};

  /// 獲取其他用戶的頭像顯示 URL（帶緩存）
  ///
  /// [userId] 目標用戶的 ID
  ///
  /// 返回 presigned URL 或 null（如果失敗）
  ///
  /// 權限控制：只能查看同一配對組成員的頭像
  Future<String?> getOtherUserAvatarUrl(String userId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cacheKey = 'other_avatar_url_$userId';

      // 1. 先檢查內存緩存
      final memoryCacheTime = _avatarUrlMemoryCacheTime[cacheKey];
      if (memoryCacheTime != null &&
          (now - memoryCacheTime) < _avatarUrlCacheValidMs) {
        final memoryCacheUrl = _avatarUrlMemoryCache[cacheKey];
        if (memoryCacheUrl != null) {
          debugPrint('使用內存緩存的頭像 URL: $userId');
          return memoryCacheUrl;
        }
      }

      // 2. 檢查 SharedPreferences 緩存
      final prefs = await SharedPreferences.getInstance();
      final cachedUrl = prefs.getString(cacheKey);
      final cacheTimeKey = '${cacheKey}_time';
      final cacheTime = prefs.getInt(cacheTimeKey);

      if (cachedUrl != null && cacheTime != null) {
        final cacheAge = now - cacheTime;
        if (cacheAge < _avatarUrlCacheValidMs) {
          debugPrint('使用本地緩存的頭像 URL: $userId');
          // 更新內存緩存
          _avatarUrlMemoryCache[cacheKey] = cachedUrl;
          _avatarUrlMemoryCacheTime[cacheKey] = cacheTime;
          return cachedUrl;
        }
      }

      // 3. 緩存不存在或已過期，從後端獲取
      debugPrint('正在獲取其他用戶頭像 URL... 目標用戶 ID: $userId');

      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        debugPrint('未找到用戶 token');
        return null;
      }

      final url = Uri.parse('${_apiService.baseUrl}/user/$userId/avatar/url');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('獲取其他用戶頭像 URL 響應狀態碼: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final avatarUrl = data['url'] as String?;
        debugPrint('成功獲取其他用戶頭像 URL');

        // 緩存 URL
        if (avatarUrl != null) {
          await prefs.setString(cacheKey, avatarUrl);
          await prefs.setInt(cacheTimeKey, now);
          // 更新內存緩存
          _avatarUrlMemoryCache[cacheKey] = avatarUrl;
          _avatarUrlMemoryCacheTime[cacheKey] = now;
          debugPrint('已緩存頭像 URL: $userId');
        }

        return avatarUrl;
      } else if (response.statusCode == 404) {
        // 用戶尚未設置頭像或使用預設頭像
        debugPrint('目標用戶尚未設置頭像或使用預設頭像');
        return null;
      } else if (response.statusCode == 403) {
        // 沒有權限查看該用戶頭像
        debugPrint('沒有權限查看該用戶頭像');
        return null;
      } else {
        debugPrint('獲取其他用戶頭像 URL 失敗: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('獲取其他用戶頭像 URL 時發生錯誤: $e');
      return null;
    }
  }

  /// 清除特定用戶的頭像 URL 緩存
  Future<void> clearAvatarUrlCache(String userId) async {
    final cacheKey = 'other_avatar_url_$userId';
    _avatarUrlMemoryCache.remove(cacheKey);
    _avatarUrlMemoryCacheTime.remove(cacheKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cacheKey);
    await prefs.remove('${cacheKey}_time');
    debugPrint('已清除頭像 URL 緩存: $userId');
  }

  /// 清除所有頭像 URL 緩存
  Future<void> clearAllAvatarUrlCache() async {
    _avatarUrlMemoryCache.clear();
    _avatarUrlMemoryCacheTime.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('other_avatar_url_')) {
        await prefs.remove(key);
      }
    }
    debugPrint('已清除所有頭像 URL 緩存');
  }

  /// 批量預取多個用戶的頭像 URL
  ///
  /// [userIds] 需要預取的用戶 ID 列表
  ///
  /// 這個方法會並行獲取所有用戶的頭像 URL，並緩存起來
  /// 返回 Map<userId, url>，失敗的用戶會返回 null
  Future<Map<String, String?>> prefetchAvatarUrls(List<String> userIds) async {
    final results = <String, String?>{};
    final now = DateTime.now().millisecondsSinceEpoch;

    // 過濾出需要請求的用戶（排除已有有效緩存的）
    final usersToFetch = <String>[];
    for (final userId in userIds) {
      final cacheKey = 'other_avatar_url_$userId';
      final memoryCacheTime = _avatarUrlMemoryCacheTime[cacheKey];

      // 檢查內存緩存
      if (memoryCacheTime != null &&
          (now - memoryCacheTime) < _avatarUrlCacheValidMs) {
        final memoryCacheUrl = _avatarUrlMemoryCache[cacheKey];
        if (memoryCacheUrl != null) {
          results[userId] = memoryCacheUrl;
          continue;
        }
      }

      usersToFetch.add(userId);
    }

    if (usersToFetch.isEmpty) {
      debugPrint('所有頭像 URL 都在緩存中');
      return results;
    }

    debugPrint('批量預取 ${usersToFetch.length} 個用戶的頭像 URL');

    // 並行獲取所有需要的頭像 URL
    final futures = usersToFetch.map((userId) async {
      final url = await getOtherUserAvatarUrl(userId);
      return MapEntry(userId, url);
    });

    final entries = await Future.wait(futures);
    for (final entry in entries) {
      results[entry.key] = entry.value;
    }

    debugPrint('批量預取完成，成功獲取 ${results.values.where((v) => v != null).length} 個頭像 URL');
    return results;
  }

  /// 刪除頭像（前端統一處理）
  /// 返回 true（成功）或 false（失敗）
  Future<bool> deleteAvatar() async {
    try {
      debugPrint('正在刪除頭像...');

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('未找到用戶 ID');
        return false;
      }

      // 1. 查詢用戶當前的頭像路徑
      final result =
          await Supabase.instance.client
              .from('user_profiles')
              .select('avatar_path')
              .eq('user_id', userId)
              .maybeSingle();

      if (result == null) {
        debugPrint('找不到用戶資料');
        return false;
      }

      final avatarPath = result['avatar_path'] as String?;

      if (avatarPath == null || avatarPath.isEmpty) {
        debugPrint('用戶尚未設置頭像');
        return false;
      }

      // 2. 檢查頭像路徑類型並處理
      if (avatarPath.startsWith('assets/')) {
        // 預設頭像，不需要從 R2 刪除，只更新資料庫
        debugPrint('用戶使用預設頭像，只清空資料庫記錄');
      } else if (avatarPath.startsWith('avatars/')) {
        // R2 上的自訂頭像，需要從 R2 刪除
        final session = Supabase.instance.client.auth.currentSession;
        final token = session?.accessToken;

        if (token == null) {
          debugPrint('未找到用戶 token');
          return false;
        }

        // 調用後端 API 從 R2 刪除檔案（不需要傳入路徑）
        final url = Uri.parse('${_apiService.baseUrl}/user/avatar');
        final response = await http.delete(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        debugPrint('刪除 R2 檔案響應狀態碼: ${response.statusCode}');

        if (response.statusCode == 200) {
          debugPrint('從 R2 刪除檔案成功');
        } else if (response.statusCode == 400) {
          debugPrint('該頭像不在 R2 上，無需刪除');
        } else if (response.statusCode == 404) {
          debugPrint('用戶資料或頭像不存在');
        } else {
          debugPrint('從 R2 刪除檔案失敗: ${response.body}');
          // 即使 R2 刪除失敗，仍然繼續清空資料庫記錄
        }
      } else {
        debugPrint('未知的頭像路徑格式: $avatarPath');
      }

      // 3. 更新資料庫，將 avatar_path 設為 NULL
      await Supabase.instance.client
          .from('user_profiles')
          .update({'avatar_path': null})
          .eq('user_id', userId);

      debugPrint('頭像刪除成功');
      return true;
    } catch (e) {
      debugPrint('刪除頭像時發生錯誤: $e');
      return false;
    }
  }

  /// 直接更新資料庫中的 avatar_path
  /// 使用 upsert 以處理首次設定時記錄不存在的情況
  Future<bool> updateAvatarPathInDatabase(String avatarPath) async {
    try {
      debugPrint('正在更新資料庫中的 avatar_path: $avatarPath');

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('未找到用戶 ID');
        return false;
      }

      // 使用 upsert 來處理記錄不存在的情況
      // 如果記錄存在則更新，不存在則創建
      await Supabase.instance.client.from('user_profiles').upsert({
        'user_id': userId,
        'avatar_path': avatarPath,
      });

      debugPrint('avatar_path 已成功更新到資料庫');
      return true;
    } catch (e) {
      debugPrint('更新 avatar_path 到資料庫時發生錯誤: $e');
      return false;
    }
  }

  /// 上傳後立即快取新頭像（用於提升用戶體驗）
  ///
  /// [avatarPath] R2 上的頭像路徑（例如：avatars/xxx.webp）
  /// [imageBytes] 已壓縮的圖片數據
  ///
  /// 返回 true（成功）或 false（失敗）
  Future<bool> cacheUploadedAvatar(
    String avatarPath,
    Uint8List imageBytes,
  ) async {
    try {
      debugPrint('開始快取新上傳的頭像: $avatarPath');

      // 先清除舊的快取（如果存在）
      await ImageCacheService().clearCacheByKey(avatarPath, CacheType.avatar);

      // 將新圖片數據直接快取到本地（不需要網路請求）
      final cacheManager = ImageCacheService().getCacheManager(
        CacheType.avatar,
      );
      await cacheManager.putFile(
        avatarPath, // 使用 avatar_path 作為穩定的 key
        imageBytes,
        key: avatarPath,
      );

      debugPrint('新頭像快取成功: $avatarPath');
      return true;
    } catch (e) {
      debugPrint('快取新頭像失敗: $e');
      return false;
    }
  }

  /// 智能載入頭像（優先使用快取，失敗時重新下載）
  ///
  /// [avatarPath] R2 上的頭像路徑
  ///
  /// 返回 Map:
  /// - 'success': bool - 是否成功
  /// - 'isFromCache': bool - 是否來自快取
  /// - 'filePath': String? - 本地文件路徑（成功時）
  /// - 'url': String? - 網路 URL（從網路載入時）
  Future<Map<String, dynamic>> loadAvatarSmart(String avatarPath) async {
    try {
      debugPrint('智能載入頭像: $avatarPath');

      // 步驟 1: 檢查本地快取
      final cachedFile = await ImageCacheService().getCachedImageByKey(
        avatarPath,
        CacheType.avatar,
      );

      if (cachedFile != null && await cachedFile.exists()) {
        debugPrint('找到有效的本地快取: $avatarPath');
        return {
          'success': true,
          'isFromCache': true,
          'filePath': cachedFile.path,
          'url': null,
        };
      }

      // 步驟 2: 快取不存在或損壞，從網路重新載入
      debugPrint('本地快取不存在或損壞，從網路重新載入: $avatarPath');
      final avatarUrl = await getAvatarUrl();

      if (avatarUrl == null) {
        debugPrint('無法獲取頭像 URL: $avatarPath');
        return {
          'success': false,
          'isFromCache': false,
          'filePath': null,
          'url': null,
        };
      }

      // 步驟 3: 下載並快取
      await ImageCacheService().precacheImageWithKey(
        avatarUrl,
        avatarPath,
        CacheType.avatar,
      );

      debugPrint('頭像重新下載並快取成功: $avatarPath');
      return {
        'success': true,
        'isFromCache': false,
        'filePath': null,
        'url': avatarUrl,
      };
    } catch (e) {
      debugPrint('智能載入頭像失敗: $e');
      return {
        'success': false,
        'isFromCache': false,
        'filePath': null,
        'url': null,
      };
    }
  }
}
