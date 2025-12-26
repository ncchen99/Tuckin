import 'package:flutter/widgets.dart';
import '../services/services.dart';

/// 應用生命週期處理器
///
/// 負責監聽應用程式的生命週期變化，處理：
/// - 應用恢復前台時清除已顯示的通知
/// - 可擴展其他生命週期相關邏輯
class LifecycleHandler extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 應用恢復前台時只清除已顯示的通知，保留排程通知
      NotificationService().clearDisplayedNotifications();
      // 應用恢復前台時嘗試刷新 NTP（非阻塞）
      // TimeService().refresh();
    }
  }
}
