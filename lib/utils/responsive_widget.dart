import 'package:flutter/material.dart';
import 'extensions.dart';

/// 響應式佈局組件
/// 根據不同設備類型顯示不同內容
class ResponsiveWidget extends StatelessWidget {
  /// 手機佈局
  final Widget mobile;

  /// 平板佈局（可選）
  final Widget? tablet;

  /// 桌面佈局（可選）
  final Widget? desktop;

  /// 構造函數
  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    // 使用建構器模式返回相應設備的佈局
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1200 && desktop != null) {
          return desktop!;
        } else if (constraints.maxWidth > 600 && tablet != null) {
          return tablet!;
        } else {
          return mobile;
        }
      },
    );
  }

  /// 靜態方法，方便使用
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;
}

/// 自適應網格佈局
/// 可以根據屏幕寬度自動調整列數
class ResponsiveGridView extends StatelessWidget {
  /// 子元素列表
  final List<Widget> children;

  /// 最小項目寬度
  final double minItemWidth;

  /// 間距
  final double spacing;

  /// 行間距
  final double? runSpacing;

  /// 內邊距
  final EdgeInsets? padding;

  /// 構造函數
  const ResponsiveGridView({
    super.key,
    required this.children,
    required this.minItemWidth,
    this.spacing = 8.0,
    this.runSpacing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 計算一行能放幾個項目
        final width = constraints.maxWidth;
        final itemsPerRow = (width / minItemWidth).floor();
        final itemWidth = (width - (itemsPerRow - 1) * spacing) / itemsPerRow;

        return Padding(
          padding: padding ?? EdgeInsets.zero,
          child: Wrap(
            spacing: spacing,
            runSpacing: runSpacing ?? spacing,
            alignment: WrapAlignment.start,
            children:
                children.map((child) {
                  return SizedBox(width: itemWidth, child: child);
                }).toList(),
          ),
        );
      },
    );
  }
}
