import 'package:flutter/material.dart';
import 'supabase_service.dart';

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

  // 表名常量
  static const String _userProfilesTable = 'user_profiles';
  static const String _foodPreferencesTable = 'food_preferences';
  static const String _personalityTypesTable = 'personality_types';

  /// 更新用戶基本資料
  ///
  /// [userData] 必須包含 user_id、nickname、gender 和 personal_desc
  Future<void> updateUserProfile(Map<String, dynamic> userData) async {
    try {
      if (!userData.containsKey('user_id')) {
        throw Exception('用戶資料必須包含 user_id');
      }

      final userId = userData['user_id'];

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
        await _supabaseService.client.from(_userProfilesTable).insert(userData);
        debugPrint('用戶資料創建成功: $userId');
      }
    } catch (error) {
      debugPrint('更新用戶資料時出錯: $error');
      rethrow;
    }
  }

  /// 更新用戶食物偏好
  ///
  /// [userId] 用戶 ID
  /// [foodPreferences] 食物偏好 ID 列表
  Future<void> updateUserFoodPreferences(
    String userId,
    List<int> foodPreferences,
  ) async {
    try {
      // 將食物偏好列表轉換為 JSONB 格式並直接更新 user_profiles 表
      await _supabaseService.client
          .from(_userProfilesTable)
          .update({'food_preferences_json': foodPreferences})
          .eq('user_id', userId);

      debugPrint('用戶食物偏好更新成功: $userId, 偏好: $foodPreferences');
    } catch (error) {
      debugPrint('更新用戶食物偏好時出錯: $error');
      rethrow;
    }
  }

  /// 更新用戶性格類型
  ///
  /// [userId] 用戶 ID
  /// [personalityType] 性格類型名稱 (分析型、功能型、直覺型、個人型)
  Future<void> updateUserPersonalityType(
    String userId,
    String personalityType,
  ) async {
    try {
      // 直接在 user_profiles 表中更新性格類型
      await _supabaseService.client
          .from(_userProfilesTable)
          .update({'personality_type': personalityType})
          .eq('user_id', userId);

      debugPrint('用戶性格類型更新成功: $userId, 類型: $personalityType');
    } catch (error) {
      debugPrint('更新用戶性格類型時出錯: $error');
      rethrow;
    }
  }

  /// 獲取用戶的完整資料，包括基本資料、食物偏好和性格類型
  Future<Map<String, dynamic>> getUserCompleteProfile(String userId) async {
    try {
      // 獲取基本資料，包括食物偏好的 JSON 欄位和性格類型
      final userProfile =
          await _supabaseService.client
              .from(_userProfilesTable)
              .select()
              .eq('user_id', userId)
              .maybeSingle();

      // 從 userProfile 中提取食物偏好
      List<int> foodIds = [];
      if (!(userProfile == null || userProfile.isEmpty) &&
          userProfile['food_preferences_json'] != null) {
        // 將 JSON 轉換為 List<int>
        foodIds = List<int>.from(userProfile['food_preferences_json']);
      }
      // 組合所有資料
      return {
        'profile': userProfile ?? {},
        'food_preferences': foodIds,
        'personality_type': userProfile?['personality_type'],
      };
    } catch (error) {
      debugPrint('獲取用戶完整資料時出錯: $error');
      rethrow;
    }
  }

  /// 檢查用戶是否已完成設定
  Future<bool> hasCompletedSetup(String userId) async {
    try {
      // 檢查用戶是否有基本資料、性格類型和食物偏好
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
      if (userProfile['personality_type'] == null) {
        return false;
      }

      // 檢查用戶是否有食物偏好
      final foodPreferences = userProfile['food_preferences_json'];
      if (foodPreferences == null ||
          (foodPreferences is List && foodPreferences.isEmpty)) {
        return false;
      }

      // 所有檢查都通過，用戶已完成設定
      return true;
    } catch (error) {
      debugPrint('檢查用戶設定狀態時出錯: $error');
      return false;
    }
  }
}
