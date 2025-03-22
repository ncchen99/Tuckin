import 'package:flutter/material.dart';

/// 用於監控路由變化的觀察器，記錄導航堆疊的變化
class TuckinRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    debugPrint(
      '路由推入: ${route.settings.name}, 前一頁: ${previousRoute?.settings.name}',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    debugPrint(
      '路由彈出: ${route.settings.name}, 返回頁: ${previousRoute?.settings.name}',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    debugPrint(
      '路由替換: 新路由=${newRoute?.settings.name}, 舊路由=${oldRoute?.settings.name}',
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    debugPrint(
      '路由移除: ${route.settings.name}, 前一頁: ${previousRoute?.settings.name}',
    );
  }
}
