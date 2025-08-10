import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ntp/ntp.dart';

/// 提供「校正後現在時間」的服務。
/// - Release：啟動時抓取一次 NTP，之後以偏移量校正裝置時間
/// - Debug/Profile：直接使用裝置時間，方便測試
class TimeService {
  TimeService._internal();
  static final TimeService _instance = TimeService._internal();
  factory TimeService() => _instance;

  /// 與裝置時間的偏移量（ntpNow - deviceNow）。
  Duration _offset = Duration.zero;

  /// 是否已嘗試過同步 NTP（成功或失敗都算）
  bool _initialized = false;

  /// 是否成功獲得 NTP 校時
  bool _synced = false;

  /// NTP 是否同步成功（Release 模式）
  bool get isSynced => _synced;

  /// 當前校時偏移量（ntpNow - deviceNow）
  Duration get offset => _offset;

  /// 初始化時的裝置時間（毫秒 epoch）
  int _deviceEpochAtInit = 0;

  /// 啟動後的單調計時器（不受系統時間調整影響）
  final Stopwatch _monotonic = Stopwatch();

  /// 容忍的裝置時間偏移閾值（超過表示使用者修改了系統時間）
  final Duration _skewThreshold = const Duration(seconds: 2);

  /// 是否正在進行 NTP 重新整理，避免重複
  bool _refreshing = false;

  /// 初始化校時流程。Release 模式會抓 NTP；Debug/Profile 則跳過。
  Future<void> initialize({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_initialized) return;
    _initialized = true;

    // 設定基準：記錄當下裝置時間並啟動單調計時器
    _deviceEpochAtInit = DateTime.now().millisecondsSinceEpoch;
    _monotonic
      ..reset()
      ..start();

    if (!kReleaseMode) {
      // Debug/Profile：直接使用裝置時間
      _offset = Duration.zero;
      _synced = false;
      return;
    }

    try {
      // 以超時限制抓取 NTP 時間
      final ntpNow = await NTP.now().timeout(timeout);
      final deviceNow = DateTime.now();
      _offset = ntpNow.difference(deviceNow);
      _synced = true;
    } catch (_) {
      // 失敗則改用裝置時間（偏移量為 0）
      _offset = Duration.zero;
      _synced = false;
    }
  }

  /// 取得「校正後現在時間」。
  /// - 若已同步成功：回傳 deviceNow + offset
  /// - 若未同步或在 Debug/Profile：回傳 deviceNow
  DateTime now() {
    // 目前裝置時間
    final int currentEpoch = DateTime.now().millisecondsSinceEpoch;

    // 預期裝置時間（以初始化時的裝置時間 + 單調時間累積）
    final int expectedEpoch =
        _deviceEpochAtInit + _monotonic.elapsedMilliseconds;
    final int skewMs = currentEpoch - expectedEpoch;

    // 若偵測到裝置時間被調整，立即補償並嘗試在背景刷新 NTP
    if (skewMs.abs() > _skewThreshold.inMilliseconds) {
      // 以補償方式抵銷突發的系統時間變動：newOffset = oldOffset - skew
      _offset -= Duration(milliseconds: skewMs);

      // 重設基準
      _deviceEpochAtInit = currentEpoch;
      _monotonic
        ..reset()
        ..start();

      // 在背景嘗試刷新 NTP（不阻塞 now()）
      if (!_refreshing && kReleaseMode) {
        _refreshing = true;
        // 忽略錯誤，完成後解除鎖
        refresh().whenComplete(() => _refreshing = false);
      }
    }

    // 回傳校正後的現在時間
    return DateTime.fromMillisecondsSinceEpoch(currentEpoch).add(_offset);
  }

  /// 取得「校正後現在時間」的毫秒 epoch。
  int epochMilliseconds() => now().millisecondsSinceEpoch;

  /// 重新嘗試同步（可在應用恢復前台時呼叫）。
  Future<void> refresh({Duration timeout = const Duration(seconds: 3)}) async {
    _initialized = false;
    await initialize(timeout: timeout);
  }
}
