import 'package:flutter/material.dart';

/// 用於創建向右滑動的頁面轉場效果
PageRouteBuilder rightSlideTransition({
  required Widget page,
  Duration duration = const Duration(milliseconds: 300),
}) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0); // 從右側進入
      const end = Offset.zero;
      const curve = Curves.easeInOut;
      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);
      return SlideTransition(position: offsetAnimation, child: child);
    },
    transitionDuration: duration,
  );
}

/// 用於創建向左滑動的頁面轉場效果（用於返回上一頁）
Route leftSlideTransition({
  required Widget page,
  Duration duration = const Duration(milliseconds: 300),
}) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(-1.0, 0.0); // 從左側進入
      const end = Offset.zero;
      const curve = Curves.easeInOut;
      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);
      return SlideTransition(position: offsetAnimation, child: child);
    },
    transitionDuration: duration,
  );
}

/// 用於設置自定義的返回轉場動畫
Route customPopTransition(BuildContext context) {
  // 獲取當前路由
  final route = ModalRoute.of(context);
  if (route == null) {
    // 如果沒有找到路由，返回默認的MaterialPageRoute
    return MaterialPageRoute(builder: (_) => const Scaffold());
  }

  // 獲取前一頁面
  final previousPage = route.settings.arguments as Widget?;
  if (previousPage == null) {
    // 如果沒有前一頁面，返回默認的MaterialPageRoute
    return MaterialPageRoute(builder: (_) => const Scaffold());
  }

  // 創建向左滑動的轉場效果
  return leftSlideTransition(page: previousPage);
}
