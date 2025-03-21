import 'package:flutter/material.dart';
import 'size_config.dart';

/// Context 擴展方法，使用更方便
extension ContextExtension on BuildContext {
  /// 獲取屏幕尺寸
  Size get screenSize => MediaQuery.of(this).size;

  /// 獲取屏幕寬度
  double get screenWidth => MediaQuery.of(this).size.width;

  /// 獲取屏幕高度
  double get screenHeight => MediaQuery.of(this).size.height;

  /// 獲取自適應寬度
  double widthPx(double px) => sizeConfig.getProportionateScreenWidth(px);

  /// 獲取自適應高度
  double heightPx(double px) => sizeConfig.getProportionateScreenHeight(px);

  /// 獲取自適應字體大小
  double fontSizePx(double px) => sizeConfig.getAdaptiveFontSize(px);

  /// 獲取寬度百分比
  double widthPercent(double percent) => screenWidth * percent;

  /// 獲取高度百分比
  double heightPercent(double percent) => screenHeight * percent;

  /// 是否為平板
  bool get isTablet => screenWidth > 600;

  /// 是否為桌面設備
  bool get isDesktop => screenWidth > 1200;

  /// 是否為手機
  bool get isMobile => !isTablet && !isDesktop;

  /// 當前設備類型
  DeviceType get deviceType {
    if (isDesktop) return DeviceType.desktop;
    if (isTablet) return DeviceType.tablet;
    return DeviceType.mobile;
  }

  /// 獲取安全區域
  EdgeInsets get safePadding => MediaQuery.of(this).padding;

  /// 屏幕方向
  Orientation get orientation => MediaQuery.of(this).orientation;
}

/// 自適應元素擴展
extension AdaptiveExtensions on num {
  /// 自適應寬度
  double get w => sizeConfig.getProportionateScreenWidth(toDouble());

  /// 自適應高度
  double get h => sizeConfig.getProportionateScreenHeight(toDouble());

  /// 自適應字體大小
  double get sp => sizeConfig.getAdaptiveFontSize(toDouble());

  /// 自適應圓角
  double get r => sizeConfig.getAdaptiveRadius(toDouble());
}

/// 設備類型枚舉
enum DeviceType { mobile, tablet, desktop }
