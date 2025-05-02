import 'package:flutter/material.dart';

/// 自適應佈局工具類
/// 用於處理不同屏幕尺寸的計算
class SizeConfig {
  // 單例模式實現
  static final SizeConfig _instance = SizeConfig._internal();
  factory SizeConfig() => _instance;
  SizeConfig._internal();

  // 媒體查詢數據
  late MediaQueryData _mediaQueryData;

  // 屏幕尺寸
  late double screenWidth;
  late double screenHeight;
  late double blockSizeHorizontal;
  late double blockSizeVertical;

  // 安全區域
  late double safeAreaHorizontal;
  late double safeAreaVertical;
  late double safeBlockHorizontal;
  late double safeBlockVertical;

  // 設計稿尺寸 (可根據需要調整)
  final double designWidth = 375.0;
  final double designHeight = 812.0;

  // 屏幕方向
  late Orientation orientation;

  // 是否為平板
  late bool isTablet;

  /// 初始化尺寸配置
  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    orientation = _mediaQueryData.orientation;

    // 判斷設備類型 (平板或手機)
    isTablet = screenWidth > 600;

    // 計算基本尺寸塊
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;

    // 計算安全區域
    safeAreaHorizontal =
        _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    safeAreaVertical =
        _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
    safeBlockHorizontal = (screenWidth - safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - safeAreaVertical) / 100;
  }

  /// 根據設計稿尺寸計算寬度
  double getProportionateScreenWidth(double inputWidth) {
    return (inputWidth / designWidth) * screenWidth;
  }

  /// 根據設計稿尺寸計算高度
  double getProportionateScreenHeight(double inputHeight) {
    return (inputHeight / designHeight) * screenHeight;
  }

  /// 計算自適應字體大小
  double getAdaptiveFontSize(double fontSize) {
    // 基於屏幕寬度的字體大小計算
    double scaleFactor = screenWidth / designWidth;
    double adaptiveSize = fontSize * scaleFactor;

    // 設置最小和最大字體大小限制
    double minSize = 12.0;
    double maxSize = fontSize * 1.5;

    return adaptiveSize.clamp(minSize, maxSize);
  }

  /// 獲取適應不同設備的內邊距
  EdgeInsets getAdaptivePadding({
    double horizontal = 0,
    double vertical = 0,
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
  }) {
    // 基於設計稿比例計算
    double scale = screenWidth / designWidth;

    return EdgeInsets.fromLTRB(
      left > 0
          ? getProportionateScreenWidth(left)
          : getProportionateScreenWidth(horizontal),
      top > 0
          ? getProportionateScreenHeight(top)
          : getProportionateScreenHeight(vertical),
      right > 0
          ? getProportionateScreenWidth(right)
          : getProportionateScreenWidth(horizontal),
      bottom > 0
          ? getProportionateScreenHeight(bottom)
          : getProportionateScreenHeight(vertical),
    );
  }

  /// 根據設備類型返回不同的值
  T getDeviceSpecificValue<T>({required T mobile, T? tablet, T? desktop}) {
    if (isTablet && tablet != null) {
      return tablet;
    } else if (screenWidth > 1200 && desktop != null) {
      return desktop;
    }
    return mobile;
  }

  /// 獲取適合當前屏幕的圓角大小
  double getAdaptiveRadius(double radius) {
    return getProportionateScreenWidth(radius);
  }

  /// 根據屏幕方向返回不同的值
  T getOrientationSpecificValue<T>({
    required T portrait,
    required T landscape,
  }) {
    return orientation == Orientation.portrait ? portrait : landscape;
  }
}

/// 全局單例，方便訪問
final sizeConfig = SizeConfig();
