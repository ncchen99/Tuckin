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

  /// 初始化校時流程。Release 模式會抓 NTP；Debug/Profile 則跳過。
  Future<void> initialize({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_initialized) return;
    _initialized = true;

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
    final deviceNow = DateTime.now();
    if (_synced && kReleaseMode) {
      return deviceNow.add(_offset);
    }
    return deviceNow;
  }

  /// 取得「校正後現在時間」的毫秒 epoch。
  int epochMilliseconds() => now().millisecondsSinceEpoch;

  /// 重新嘗試同步（可在應用恢復前台時呼叫）。
  Future<void> refresh({Duration timeout = const Duration(seconds: 3)}) async {
    _initialized = false;
    await initialize(timeout: timeout);
  }
}
