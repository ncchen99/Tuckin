import 'package:flutter/material.dart';
import 'supabase_service.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 資料庫服務，處理與資料庫相關的 CRUD 操作
class DatabaseService {
  // 單例模式
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  // 取得 Supabase 服務的實例
  final SupabaseService _supabaseService = SupabaseService();
  final ApiService _apiService = ApiService();

  // 表名常量
  static const String _userProfilesTable = 'user_profiles';
  static const String _personalityResultsTable = 'user_personality_results';
  static const String _userFoodPreferencesTable = 'user_food_preferences';
  static const String _userStatusTable = 'user_status';
  static const String _userMatchingPreferencesTable =
      'user_matching_preferences';

  /// 更新用戶基本資料
  ///
  /// [userData] 必須包含 user_id、nickname、gender 和 personal_desc
  Future<void> updateUserProfile(Map<String, dynamic> userData) async {
    if (!userData.containsKey('user_id')) {
      throw ApiError(message: '用戶資料必須包含 user_id');
    }

    final userId = userData['user_id'];

    return _apiService.handleRequest(
      request: () async {
        // 檢查用戶是否已存在
        final existingUser =
            await _supabaseService.client
                .from(_userProfilesTable)
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        if (existingUser != null) {
          // 更新現有用戶
          await _supabaseService.client
              .from(_userProfilesTable)
              .update(userData)
              .eq('user_id', userId);
          debugPrint('用戶資料更新成功: $userId');
        } else {
          // 創建新用戶
          await _supabaseService.client
              .from(_userProfilesTable)
              .insert(userData);

          // 新增用戶狀態記錄
          await _supabaseService.client.from(_userStatusTable).insert({
            'user_id': userId,
            'status': 'initial', // 初始狀態
          });

          debugPrint('用戶資料創建成功: $userId');
        }
      },
    );
  }

  /// 更新用戶食物偏好
  ///
  /// [userId] 用戶 ID
  /// [foodPreferences] 食物偏好 ID 列表
  Future<void> updateUserFoodPreferences(
    String userId,
    List<int> foodPreferences,
  ) async {
    return _apiService.handleRequest(
      request: () async {
        // 刪除現有的食物偏好
        await _supabaseService.client
            .from(_userFoodPreferencesTable)
            .delete()
            .eq('user_id', userId);

        // 插入新的食物偏好
        final foodPreferenceData =
            foodPreferences
                .map((prefId) => {'user_id': userId, 'preference_id': prefId})
                .toList();

        if (foodPreferenceData.isNotEmpty) {
          await _supabaseService.client
              .from(_userFoodPreferencesTable)
              .insert(foodPreferenceData);
        }

        debugPrint('用戶食物偏好更新成功: $userId, 偏好: $foodPreferences');
      },
    );
  }

  /// 更新用戶性格類型
  ///
  /// [userId] 用戶 ID
  /// [personalityType] 性格類型名稱 (分析型、功能型、直覺型、個人型)
  Future<void> updateUserPersonalityType(
    String userId,
    String personalityType,
  ) async {
    return _apiService.handleRequest(
      request: () async {
        // 檢查是否已有性格資料
        final existingPersonality =
            await _supabaseService.client
                .from(_personalityResultsTable)
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        if (existingPersonality != null) {
          // 更新現有性格類型
          await _supabaseService.client
              .from(_personalityResultsTable)
              .update({'personality_type': personalityType})
              .eq('user_id', userId);
        } else {
          // 新增性格類型
          await _supabaseService.client.from(_personalityResultsTable).insert({
            'user_id': userId,
            'personality_type': personalityType,
          });
        }

        debugPrint('用戶性格類型更新成功: $userId, 類型: $personalityType');
      },
    );
  }

  /// 更新用戶配對偏好
  ///
  /// [userId] 用戶 ID
  /// [preferSchoolOnly] 是否只想與校內同學聚餐
  Future<void> updateUserMatchingPreference(
    String userId,
    bool preferSchoolOnly,
  ) async {
    return _apiService.handleRequest(
      request: () async {
        // 檢查用戶配對偏好是否已存在
        final existingPreference =
            await _supabaseService.client
                .from(_userMatchingPreferencesTable)
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        if (existingPreference != null) {
          // 更新現有偏好
          await _supabaseService.client
              .from(_userMatchingPreferencesTable)
              .update({'prefer_school_only': preferSchoolOnly})
              .eq('user_id', userId);
        } else {
          // 創建新偏好記錄
          await _supabaseService.client
              .from(_userMatchingPreferencesTable)
              .insert({
                'user_id': userId,
                'prefer_school_only': preferSchoolOnly,
              });
        }

        debugPrint('用戶配對偏好更新成功: $userId, 偏好校內: $preferSchoolOnly');
      },
    );
  }

  /// 獲取用戶的完整資料，包括基本資料、食物偏好和性格類型
  Future<Map<String, dynamic>> getUserCompleteProfile(String userId) async {
    return _apiService.handleRequest(
      request: () async {
        // 獲取基本資料
        final userProfile =
            await _supabaseService.client
                .from(_userProfilesTable)
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        // 獲取性格類型
        final personalityResult =
            await _supabaseService.client
                .from(_personalityResultsTable)
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        // 獲取食物偏好
        final foodPreferences = await _supabaseService.client
            .from(_userFoodPreferencesTable)
            .select('preference_id')
            .eq('user_id', userId);

        // 獲取用戶狀態
        final userStatus =
            await _supabaseService.client
                .from(_userStatusTable)
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        // 從關聯表中提取食物偏好ID列表
        List<int> foodIds = [];
        if (foodPreferences.isNotEmpty) {
          foodIds =
              foodPreferences
                  .map<int>((item) => item['preference_id'] as int)
                  .toList();
        }

        // 組合所有資料
        return {
          'profile': userProfile ?? {},
          'food_preferences': foodIds,
          'personality_type': personalityResult?['personality_type'],
          'user_status': userStatus?['status'] ?? 'initial',
        };
      },
    );
  }

  /// 檢查用戶是否已完成設定
  Future<bool> hasCompletedSetup(String userId) async {
    return _apiService.handleRequest(
      request: () async {
        // 檢查用戶是否有基本資料
        final userProfile =
            await _supabaseService.client
                .from(_userProfilesTable)
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        if (userProfile == null) {
          return false;
        }

        // 檢查用戶是否有性格類型
        final personalityResult =
            await _supabaseService.client
                .from(_personalityResultsTable)
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        if (personalityResult == null) {
          return false;
        }

        // 檢查用戶是否有食物偏好
        final foodPreferences = await _supabaseService.client
            .from(_userFoodPreferencesTable)
            .select()
            .eq('user_id', userId);

        if (foodPreferences.isEmpty) {
          return false;
        }

        // 所有檢查都通過，用戶已完成設定
        return true;
      },
    );
  }

  /// 更新用戶狀態
  ///
  /// [userId] 用戶 ID
  /// [status] 狀態值
  Future<void> updateUserStatus(String userId, String status) async {
    return _apiService.handleRequest(
      request: () async {
        // 檢查用戶狀態是否已存在
        final existingStatus =
            await _supabaseService.client
                .from(_userStatusTable)
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        if (existingStatus != null) {
          // 更新現有狀態
          await _supabaseService.client
              .from(_userStatusTable)
              .update({'status': status})
              .eq('user_id', userId);
        } else {
          // 創建新狀態記錄
          await _supabaseService.client.from(_userStatusTable).insert({
            'user_id': userId,
            'status': status,
          });
        }

        debugPrint('用戶狀態更新成功: $userId, 狀態: $status');
      },
    );
  }

  /// 獲取用戶當前狀態
  ///
  /// [userId] 用戶 ID
  Future<String> getUserStatus(String userId) async {
    return _apiService.handleRequest(
      request: () async {
        final statusData =
            await _supabaseService.client
                .from(_userStatusTable)
                .select()
                .eq('user_id', userId)
                .maybeSingle();

        return statusData?['status'] ?? 'initial';
      },
    );
  }

  /// 檢查用戶是否可以刪除帳號
  ///
  /// 如果用戶處於聚餐預約流程中（等待確認、等待其他用戶、等待出席），則不允許刪除帳號
  /// 返回 true 表示可以刪除，false 表示不能刪除
  Future<bool> canDeleteAccount(String userId) async {
    return _apiService.handleRequest(
      request: () async {
        final status = await getUserStatus(userId);

        // 這些狀態表示用戶正在聚餐預約流程中
        List<String> restrictedStatuses = [
          'waiting_restaurant',
          'waiting_other_users',
          'waiting_attendance',
        ];

        // 如果用戶狀態在限制列表中，則不能刪除帳號
        return !restrictedStatuses.contains(status);
      },
    );
  }

  /// 獲取用戶配對偏好
  ///
  /// [userId] 用戶 ID
  Future<bool?> getUserMatchingPreference(String userId) async {
    return _apiService.handleRequest(
      request: () async {
        final preferenceData =
            await _supabaseService.client
                .from(_userMatchingPreferencesTable)
                .select('prefer_school_only')
                .eq('user_id', userId)
                .maybeSingle();

        // 如果沒有找到數據，返回null表示尚未設定
        if (preferenceData == null) {
          return null;
        }

        return preferenceData['prefer_school_only'] ?? false;
      },
    );
  }

  // 獲取用戶個人資料
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    return _apiService.handleRequest(
      request: () async {
        final response =
            await _supabaseService.client
                .from('user_profiles')
                .select()
                .eq('user_id', userId)
                .single();
        return response;
      },
    );
  }

  /// 刪除用戶及相關資料
  ///
  /// [userId] 要刪除的用戶 ID
  /// 此操作將從所有相關表中移除用戶資料，不可恢復
  Future<void> deleteUser(String userId) async {
    return _apiService.handleRequest(
      request: () async {
        // 刪除用戶裝置令牌
        await _supabaseService.client
            .from('user_device_tokens')
            .delete()
            .eq('user_id', userId);
        debugPrint('已刪除用戶裝置令牌: $userId');

        // 刪除用戶食物偏好
        await _supabaseService.client
            .from(_userFoodPreferencesTable)
            .delete()
            .eq('user_id', userId);
        debugPrint('已刪除用戶食物偏好: $userId');

        // 刪除用戶配對偏好
        await _supabaseService.client
            .from(_userMatchingPreferencesTable)
            .delete()
            .eq('user_id', userId);
        debugPrint('已刪除用戶配對偏好: $userId');

        // 刪除用戶通知
        await _supabaseService.client
            .from('user_notifications')
            .delete()
            .eq('user_id', userId);
        debugPrint('已刪除用戶通知: $userId');

        // 刪除用戶性格結果
        await _supabaseService.client
            .from(_personalityResultsTable)
            .delete()
            .eq('user_id', userId);
        debugPrint('已刪除用戶性格結果: $userId');

        // 刪除用戶狀態
        await _supabaseService.client
            .from(_userStatusTable)
            .delete()
            .eq('user_id', userId);
        debugPrint('已刪除用戶狀態: $userId');

        // 最後刪除用戶基本資料
        await _supabaseService.client
            .from(_userProfilesTable)
            .delete()
            .eq('user_id', userId);
        debugPrint('已刪除用戶基本資料: $userId');

        // 確保清理本地存儲的登入狀態
        await _supabaseService.client.auth.signOut();

        // 可能需要清理本地存儲
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // 清理所有相關存儲

        debugPrint('用戶刪除完成: $userId');
      },
    );
  }
}
