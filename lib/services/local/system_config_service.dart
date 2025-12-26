import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/supabase_service.dart';
import '../core/api_service.dart';

/// 版本更新公告模型
class VersionAnnouncement {
  final String appVersion;
  final String? title;
  final String content;
  final String? iconPath;
  final String? actionRoute;
  final String actionLabel;
  final String cancelLabel;

  VersionAnnouncement({
    required this.appVersion,
    this.title,
    required this.content,
    this.iconPath,
    this.actionRoute,
    this.actionLabel = '前往設定',
    this.cancelLabel = '稍後',
  });

  factory VersionAnnouncement.fromMap(Map<String, dynamic> map) {
    return VersionAnnouncement(
      appVersion: map['app_version'] as String,
      title: map['title'] as String?,
      content: map['content'] as String,
      iconPath: map['icon_path'] as String?,
      actionRoute: map['action_route'] as String?,
      actionLabel: (map['action_label'] as String?) ?? '前往設定',
      cancelLabel: (map['cancel_label'] as String?) ?? '稍後',
    );
  }
}

/// 系統配置資訊模型
class SystemConfig {
  final String latestAppVersion;
  final String minRequiredVersion;
  final bool isServiceEnabled;
  final String serviceDisabledReason;
  final DateTime? estimatedRestoreTime;
  final String updateUrlAndroid;
  final String updateUrlIos;

  SystemConfig({
    required this.latestAppVersion,
    required this.minRequiredVersion,
    required this.isServiceEnabled,
    required this.serviceDisabledReason,
    this.estimatedRestoreTime,
    required this.updateUrlAndroid,
    required this.updateUrlIos,
  });

  /// 檢查是否需要強制更新
  bool needsForceUpdate(String currentVersion) {
    return _compareVersions(currentVersion, minRequiredVersion) < 0;
  }

  /// 檢查是否有可用更新
  bool hasUpdate(String currentVersion) {
    return _compareVersions(currentVersion, latestAppVersion) < 0;
  }

  /// 比較版本號
  /// 返回: -1 (v1 < v2), 0 (v1 == v2), 1 (v1 > v2)
  static int _compareVersions(String v1, String v2) {
    final v1Parts = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final v2Parts = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // 確保兩個列表長度相同
    while (v1Parts.length < v2Parts.length) {
      v1Parts.add(0);
    }
    while (v2Parts.length < v1Parts.length) {
      v2Parts.add(0);
    }

    for (int i = 0; i < v1Parts.length; i++) {
      if (v1Parts[i] < v2Parts[i]) return -1;
      if (v1Parts[i] > v2Parts[i]) return 1;
    }

    return 0;
  }
}

/// 系統檢查結果
class SystemCheckResult {
  final bool isServiceAvailable;
  final bool needsForceUpdate;
  final bool hasOptionalUpdate;
  final String? serviceDisabledReason;
  final DateTime? estimatedRestoreTime;
  final String? updateUrl;
  final String? latestVersion;
  final String currentVersion;
  final VersionAnnouncement? versionAnnouncement;

  SystemCheckResult({
    required this.isServiceAvailable,
    required this.needsForceUpdate,
    required this.hasOptionalUpdate,
    this.serviceDisabledReason,
    this.estimatedRestoreTime,
    this.updateUrl,
    this.latestVersion,
    required this.currentVersion,
    this.versionAnnouncement,
  });

  /// 是否可以正常使用 APP
  bool get canUseApp => isServiceAvailable && !needsForceUpdate;
}

/// 系統配置服務
///
/// 負責檢查 APP 版本和服務狀態
class SystemConfigService {
  // 單例模式
  static final SystemConfigService _instance = SystemConfigService._internal();
  factory SystemConfigService() => _instance;
  SystemConfigService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final ApiService _apiService = ApiService();

  // 緩存配置
  SystemConfig? _cachedConfig;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // 當前 APP 版本
  String? _currentAppVersion;

  /// 獲取當前 APP 版本
  Future<String> getCurrentAppVersion() async {
    if (_currentAppVersion != null) {
      return _currentAppVersion!;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentAppVersion = packageInfo.version;
      debugPrint('SystemConfigService: 當前 APP 版本: $_currentAppVersion');
      return _currentAppVersion!;
    } catch (e) {
      debugPrint('SystemConfigService: 獲取 APP 版本失敗: $e');
      return '0.0.0';
    }
  }

  /// 從資料庫獲取系統配置
  Future<SystemConfig?> fetchSystemConfig({bool forceRefresh = false}) async {
    // 檢查緩存
    if (!forceRefresh &&
        _cachedConfig != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      debugPrint('SystemConfigService: 使用緩存的系統配置');
      return _cachedConfig;
    }

    try {
      return await _apiService.handleRequest(
        request: () async {
          final response = await _supabaseService.client
              .from('system_config')
              .select('config_key, config_value');

          if (response.isEmpty) {
            debugPrint('SystemConfigService: 未找到系統配置');
            return null;
          }

          // 將結果轉換為 Map
          final configMap = <String, String>{};
          for (final row in response) {
            configMap[row['config_key'] as String] =
                (row['config_value'] as String?) ?? '';
          }

          // 解析預計恢復時間
          DateTime? estimatedRestoreTime;
          final restoreTimeStr = configMap['estimated_restore_time'] ?? '';
          if (restoreTimeStr.isNotEmpty) {
            try {
              estimatedRestoreTime = DateTime.parse(restoreTimeStr);
            } catch (e) {
              debugPrint('SystemConfigService: 解析預計恢復時間失敗: $e');
            }
          }

          final config = SystemConfig(
            latestAppVersion: configMap['latest_app_version'] ?? '1.0.0',
            minRequiredVersion: configMap['min_required_version'] ?? '1.0.0',
            isServiceEnabled:
                (configMap['is_service_enabled'] ?? 'true').toLowerCase() ==
                'true',
            serviceDisabledReason: configMap['service_disabled_reason'] ?? '',
            estimatedRestoreTime: estimatedRestoreTime,
            updateUrlAndroid: configMap['update_url_android'] ?? '',
            updateUrlIos: configMap['update_url_ios'] ?? '',
          );

          // 更新緩存
          _cachedConfig = config;
          _lastFetchTime = DateTime.now();

          debugPrint(
            'SystemConfigService: 成功獲取系統配置 - 最新版本: ${config.latestAppVersion}, 最低版本: ${config.minRequiredVersion}, 服務啟用: ${config.isServiceEnabled}',
          );

          return config;
        },
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('SystemConfigService: 獲取系統配置失敗: $e');
      // 如果獲取失敗，返回緩存的配置（如果有的話）
      return _cachedConfig;
    }
  }

  /// 執行系統檢查
  ///
  /// 返回系統檢查結果，包括服務狀態和版本更新資訊
  Future<SystemCheckResult> performSystemCheck() async {
    final currentVersion = await getCurrentAppVersion();

    try {
      final config = await fetchSystemConfig();

      if (config == null) {
        // 無法獲取配置時，假設服務正常（避免阻止用戶使用）
        debugPrint('SystemConfigService: 無法獲取系統配置，假設服務正常');
        return SystemCheckResult(
          isServiceAvailable: true,
          needsForceUpdate: false,
          hasOptionalUpdate: false,
          currentVersion: currentVersion,
        );
      }

      // 檢查服務是否啟用
      final isServiceAvailable = config.isServiceEnabled;

      // 檢查是否需要強制更新
      final needsForceUpdate = config.needsForceUpdate(currentVersion);

      // 檢查是否有可選更新
      final hasOptionalUpdate =
          !needsForceUpdate && config.hasUpdate(currentVersion);

      // 根據平台選擇更新連結
      final updateUrl = _getUpdateUrl(config);

      // 獲取當前版本的公告
      final versionAnnouncement = await fetchVersionAnnouncement(currentVersion);

      debugPrint(
        'SystemConfigService: 系統檢查完成 - 服務可用: $isServiceAvailable, 強制更新: $needsForceUpdate, 可選更新: $hasOptionalUpdate, 有版本公告: ${versionAnnouncement != null}',
      );

      return SystemCheckResult(
        isServiceAvailable: isServiceAvailable,
        needsForceUpdate: needsForceUpdate,
        hasOptionalUpdate: hasOptionalUpdate,
        serviceDisabledReason:
            isServiceAvailable ? null : config.serviceDisabledReason,
        estimatedRestoreTime:
            isServiceAvailable ? null : config.estimatedRestoreTime,
        updateUrl: updateUrl,
        latestVersion: config.latestAppVersion,
        currentVersion: currentVersion,
        versionAnnouncement: versionAnnouncement,
      );
    } catch (e) {
      debugPrint('SystemConfigService: 系統檢查失敗: $e');
      // 發生錯誤時，假設服務正常
      return SystemCheckResult(
        isServiceAvailable: true,
        needsForceUpdate: false,
        hasOptionalUpdate: false,
        currentVersion: currentVersion,
      );
    }
  }

  /// 獲取指定版本的公告
  Future<VersionAnnouncement?> fetchVersionAnnouncement(String appVersion) async {
    try {
      return await _apiService.handleRequest(
        request: () async {
          final response = await _supabaseService.client
              .from('version_announcements')
              .select()
              .eq('app_version', appVersion)
              .eq('is_enabled', true)
              .maybeSingle();

          if (response == null) {
            debugPrint('SystemConfigService: 未找到版本 $appVersion 的公告');
            return null;
          }

          final announcement = VersionAnnouncement.fromMap(response);
          debugPrint('SystemConfigService: 找到版本 $appVersion 的公告: ${announcement.content}');
          return announcement;
        },
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('SystemConfigService: 獲取版本公告失敗: $e');
      return null;
    }
  }

  /// 根據平台獲取更新連結
  String _getUpdateUrl(SystemConfig config) {
    if (Platform.isIOS) {
      return config.updateUrlIos;
    }
    return config.updateUrlAndroid;
  }

  /// 清除緩存
  void clearCache() {
    _cachedConfig = null;
    _lastFetchTime = null;
    debugPrint('SystemConfigService: 緩存已清除');
  }
}
