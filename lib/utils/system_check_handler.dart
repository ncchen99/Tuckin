import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/services.dart';
import '../components/components.dart';
import '../screens/status/service_unavailable_page.dart';

/// SharedPreferences 鍵值：記錄已確認的版本公告
const String _lastAcknowledgedAnnouncementVersionKey =
    'last_acknowledged_announcement_version';

/// 系統檢查處理器
///
/// 負責處理系統檢查結果的 UI 顯示，包括：
/// - 服務暫停頁面
/// - 強制更新頁面
/// - 可選更新對話框
/// - 版本公告對話框
class SystemCheckHandler {
  // 單例模式
  static final SystemCheckHandler _instance = SystemCheckHandler._internal();
  factory SystemCheckHandler() => _instance;
  SystemCheckHandler._internal();

  // 緩存系統檢查結果
  SystemCheckResult? _systemCheckResult;

  /// 獲取最新的系統檢查結果
  SystemCheckResult? get lastCheckResult => _systemCheckResult;

  /// 在背景執行系統檢查
  Future<void> performSystemCheckInBackground({
    required GlobalKey<NavigatorState> navigatorKey,
    required String initialRoute,
  }) async {
    try {
      debugPrint('開始背景系統檢查...');
      final result = await SystemConfigService().performSystemCheck();
      _systemCheckResult = result;

      debugPrint(
        '系統檢查完成 - 服務可用: ${result.isServiceAvailable}, '
        '需要強制更新: ${result.needsForceUpdate}, '
        '有可選更新: ${result.hasOptionalUpdate}',
      );

      // 如果需要顯示系統狀態頁面，進行導航
      if (!result.canUseApp && navigatorKey.currentState != null) {
        _showSystemStatusPage(result, navigatorKey, initialRoute);
      } else if (result.hasOptionalUpdate && navigatorKey.currentState != null) {
        // 有可選更新，顯示更新提示對話框
        _showOptionalUpdateDialog(result, navigatorKey);
      } else if (result.versionAnnouncement != null &&
          navigatorKey.currentState != null) {
        // 有版本公告，檢查是否需要顯示
        await _showVersionAnnouncementIfNeeded(result, navigatorKey);
      }
    } catch (e) {
      debugPrint('背景系統檢查失敗: $e');
    }
  }

  /// 顯示系統狀態頁面
  void _showSystemStatusPage(
    SystemCheckResult result,
    GlobalKey<NavigatorState> navigatorKey,
    String initialRoute,
  ) {
    if (navigatorKey.currentState == null) {
      debugPrint('Navigator 尚未準備好，稍後重試顯示系統狀態頁面');
      Future.delayed(const Duration(milliseconds: 500), () {
        _showSystemStatusPage(result, navigatorKey, initialRoute);
      });
      return;
    }

    if (!result.isServiceAvailable) {
      // 服務暫停
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ServiceUnavailablePage(
            type: ServiceUnavailableType.maintenance,
            reason: result.serviceDisabledReason,
            estimatedRestoreTime: result.estimatedRestoreTime,
            onRetry: () async {
              // 重新檢查系統狀態
              final newResult =
                  await SystemConfigService().performSystemCheck();
              _systemCheckResult = newResult;

              if (newResult.canUseApp && navigatorKey.currentState != null) {
                // 服務恢復，回到主應用
                navigatorKey.currentState!.pushNamedAndRemoveUntil(
                  initialRoute,
                  (route) => false,
                );
              } else if (!newResult.isServiceAvailable) {
                // 仍然不可用，更新頁面
                _showSystemStatusPage(newResult, navigatorKey, initialRoute);
              } else if (newResult.needsForceUpdate) {
                // 需要強制更新
                _showSystemStatusPage(newResult, navigatorKey, initialRoute);
              }
            },
          ),
        ),
        (route) => false,
      );
    } else if (result.needsForceUpdate) {
      // 需要強制更新
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ServiceUnavailablePage(
            type: ServiceUnavailableType.forceUpdate,
            updateUrl: result.updateUrl,
            latestVersion: result.latestVersion,
            currentVersion: result.currentVersion,
          ),
        ),
        (route) => false,
      );
    }
  }

  /// 顯示可選更新對話框
  void _showOptionalUpdateDialog(
    SystemCheckResult result,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    if (navigatorKey.currentState == null) {
      debugPrint('Navigator 尚未準備好，稍後重試顯示更新對話框');
      Future.delayed(const Duration(milliseconds: 500), () {
        _showOptionalUpdateDialog(result, navigatorKey);
      });
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('無法獲取 context，無法顯示對話框');
      return;
    }

    // 延遲一下，確保頁面已經完全渲染
    Future.delayed(const Duration(milliseconds: 600), () {
      if (navigatorKey.currentContext == null) return;

      showCustomConfirmationDialog(
        context: navigatorKey.currentContext!,
        iconPath: 'assets/images/icon/update.webp',
        title: '',
        content: '發現新版本的 Tuckin\n要立即更新嗎？',
        cancelButtonText: '稍後',
        confirmButtonText: '好哇',
        loadingColor: const Color(0xFF23456B),
        barrierDismissible: true,
        onCancel: () {
          Navigator.of(navigatorKey.currentContext!).pop();
        },
        onConfirm: () async {
          if (result.updateUrl != null && result.updateUrl!.isNotEmpty) {
            try {
              final uri = Uri.parse(result.updateUrl!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                debugPrint('無法開啟更新連結: ${result.updateUrl}');
              }
            } catch (e) {
              debugPrint('開啟更新連結失敗: $e');
            }
          }
          if (navigatorKey.currentContext != null) {
            Navigator.of(navigatorKey.currentContext!).pop();
          }
        },
      );
    });
  }

  /// 檢查並顯示版本公告
  Future<void> _showVersionAnnouncementIfNeeded(
    SystemCheckResult result,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    if (result.versionAnnouncement == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAckedVersion =
          prefs.getString(_lastAcknowledgedAnnouncementVersionKey);

      debugPrint(
          '版本公告檢查 - 當前版本: ${result.currentVersion}, 上次確認版本: $lastAckedVersion');

      // 如果已經確認過這個版本的公告，就不再顯示
      if (lastAckedVersion == result.currentVersion) {
        debugPrint('已確認過版本 ${result.currentVersion} 的公告，不再顯示');
        return;
      }

      // 顯示版本公告對話框
      _showVersionAnnouncementDialog(
        result.versionAnnouncement!,
        result.currentVersion,
        navigatorKey,
      );
    } catch (e) {
      debugPrint('檢查版本公告失敗: $e');
    }
  }

  /// 顯示版本公告對話框
  void _showVersionAnnouncementDialog(
    VersionAnnouncement announcement,
    String currentVersion,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    if (navigatorKey.currentState == null) {
      debugPrint('Navigator 尚未準備好，稍後重試顯示版本公告');
      Future.delayed(const Duration(milliseconds: 500), () {
        _showVersionAnnouncementDialog(announcement, currentVersion, navigatorKey);
      });
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('無法獲取 context，無法顯示版本公告');
      return;
    }

    // 延遲一下，確保頁面已經完全渲染
    Future.delayed(const Duration(milliseconds: 800), () async {
      if (navigatorKey.currentContext == null) return;

      showCustomConfirmationDialog(
        context: navigatorKey.currentContext!,
        iconPath: announcement.iconPath ?? 'assets/images/icon/update.webp',
        title: announcement.title ?? '',
        content: announcement.content,
        cancelButtonText: announcement.cancelLabel,
        confirmButtonText: announcement.actionLabel,
        loadingColor: const Color(0xFF23456B),
        barrierDismissible: true,
        onCancel: () async {
          // 記錄已確認版本
          await _markAnnouncementAsAcknowledged(currentVersion);
          if (navigatorKey.currentContext != null) {
            Navigator.of(navigatorKey.currentContext!).pop();
          }
        },
        onConfirm: () async {
          // 記錄已確認版本
          await _markAnnouncementAsAcknowledged(currentVersion);
          if (navigatorKey.currentContext != null) {
            Navigator.of(navigatorKey.currentContext!).pop();
          }
          // 如果有指定導航路由，則導航到該頁面
          if (announcement.actionRoute != null &&
              announcement.actionRoute!.isNotEmpty &&
              navigatorKey.currentState != null) {
            // 對於 profile_setup 頁面，傳遞 isFromProfile: true 參數
            // 這樣頁面不會因為用戶已完成設定而自動返回
            if (announcement.actionRoute == '/profile_setup') {
              navigatorKey.currentState!.pushNamed(
                announcement.actionRoute!,
                arguments: {'isFromProfile': true},
              );
            } else {
              navigatorKey.currentState!.pushNamed(announcement.actionRoute!);
            }
          }
        },
      );
    });
  }

  /// 標記版本公告已確認
  Future<void> _markAnnouncementAsAcknowledged(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastAcknowledgedAnnouncementVersionKey, version);
      debugPrint('已記錄版本公告確認: $version');
    } catch (e) {
      debugPrint('記錄版本公告確認失敗: $e');
    }
  }
}

