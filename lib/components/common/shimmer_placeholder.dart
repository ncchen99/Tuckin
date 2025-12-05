import 'package:flutter/material.dart';
import 'package:tuckin/utils/index.dart';

/// Shimmer 效果的 placeholder 元件
/// 用於圖片或頭像載入時顯示深灰色背景配合眩光效果
class ShimmerPlaceholder extends StatefulWidget {
  /// 元件寬度
  final double? width;

  /// 元件高度
  final double? height;

  /// 是否為圓形（用於頭像）
  final bool isCircle;

  /// 圓角半徑（僅在 isCircle 為 false 時有效）
  final BorderRadius? borderRadius;

  /// 基底顏色（深灰色）
  final Color baseColor;

  /// 高亮顏色（眩光顏色）
  final Color highlightColor;

  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.isCircle = false,
    this.borderRadius,
    this.baseColor = const Color(0xFF424242), // 深灰色
    this.highlightColor = const Color(0xFF616161), // 較亮的灰色
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                widget.isCircle
                    ? null
                    : (widget.borderRadius ?? BorderRadius.circular(12.r)),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 用於圓形頭像的 shimmer placeholder
class AvatarShimmerPlaceholder extends StatelessWidget {
  /// 頭像尺寸
  final double size;

  /// 基底顏色
  final Color baseColor;

  /// 高亮顏色
  final Color highlightColor;

  const AvatarShimmerPlaceholder({
    super.key,
    required this.size,
    this.baseColor = const Color(0xFF424242),
    this.highlightColor = const Color(0xFF616161),
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerPlaceholder(
      width: size,
      height: size,
      isCircle: true,
      baseColor: baseColor,
      highlightColor: highlightColor,
    );
  }
}

/// 用於圖片的 shimmer placeholder
class ImageShimmerPlaceholder extends StatelessWidget {
  /// 圖片寬度
  final double width;

  /// 圖片高度
  final double height;

  /// 圓角半徑
  final BorderRadius? borderRadius;

  /// 基底顏色
  final Color baseColor;

  /// 高亮顏色
  final Color highlightColor;

  const ImageShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.baseColor = const Color(0xFF424242),
    this.highlightColor = const Color(0xFF616161),
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerPlaceholder(
      width: width,
      height: height,
      isCircle: false,
      borderRadius: borderRadius,
      baseColor: baseColor,
      highlightColor: highlightColor,
    );
  }
}

