import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tuckin/services/image_cache_service.dart';
import 'package:tuckin/components/common/loading_image.dart';

/// 緩存圖片組件 - 用於顯示網路圖片並自動緩存
///
/// 支援兩種模式：
/// - 圓形頭像模式：適用於用戶頭像顯示
/// - 矩形圖片模式：適用於餐廳圖片等矩形圖片顯示
class CachedImage extends StatelessWidget {
  /// 圖片 URL
  final String imageUrl;

  /// 緩存類型
  final CacheType cacheType;

  /// 圖片寬度
  final double? width;

  /// 圖片高度
  final double? height;

  /// 圖片適配模式
  final BoxFit fit;

  /// 是否為圓形（用於頭像）
  final bool isCircle;

  /// 圓形邊框寬度
  final double? borderWidth;

  /// 圓形邊框顏色
  final Color? borderColor;

  /// 佔位符（載入中顯示的 Widget）
  final Widget? placeholder;

  /// 錯誤時顯示的 Widget
  final Widget? errorWidget;

  /// 邊框圓角（僅在非圓形時有效）
  final double? borderRadius;

  const CachedImage({
    super.key,
    required this.imageUrl,
    required this.cacheType,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isCircle = false,
    this.borderWidth,
    this.borderColor,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  /// 圓形頭像構造函數
  factory CachedImage.avatar({
    required String imageUrl,
    required double size,
    double borderWidth = 2.5,
    Color borderColor = const Color(0xFF23456B),
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedImage(
      imageUrl: imageUrl,
      cacheType: CacheType.avatar,
      width: size,
      height: size,
      isCircle: true,
      borderWidth: borderWidth,
      borderColor: borderColor,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  /// 餐廳圖片構造函數
  factory CachedImage.restaurant({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    double borderRadius = 10,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedImage(
      imageUrl: imageUrl,
      cacheType: CacheType.restaurant,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 獲取對應的緩存管理器
    final cacheManager = ImageCacheService().getCacheManager(cacheType);

    // 構建緩存網路圖片
    Widget cachedImage = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: cacheManager,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) {
        return placeholder ??
            _buildDefaultPlaceholder(
              width: width,
              height: height,
              isCircle: isCircle,
            );
      },
      errorWidget: (context, url, error) {
        return errorWidget ??
            _buildDefaultErrorWidget(
              width: width,
              height: height,
              isCircle: isCircle,
              cacheType: cacheType,
            );
      },
    );

    // 如果是圓形模式，添加圓形容器和邊框
    if (isCircle) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border:
              borderWidth != null && borderColor != null
                  ? Border.all(color: borderColor!, width: borderWidth!)
                  : null,
        ),
        child: ClipOval(child: cachedImage),
      );
    }

    // 如果有圓角設定，使用 ClipRRect
    if (borderRadius != null && borderRadius! > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius!),
        child: cachedImage,
      );
    }

    return cachedImage;
  }

  /// 預設的 loading 佔位符
  Widget _buildDefaultPlaceholder({
    double? width,
    double? height,
    bool isCircle = false,
  }) {
    return Container(
      width: width,
      height: height,
      color: isCircle ? Colors.white : Colors.grey[200],
      child: Center(
        child: LoadingImage(
          width: (width ?? 40) * 0.4,
          height: (height ?? 40) * 0.4,
          color: const Color(0xFFB33D1C),
        ),
      ),
    );
  }

  /// 預設的錯誤 Widget
  Widget _buildDefaultErrorWidget({
    double? width,
    double? height,
    bool isCircle = false,
    required CacheType cacheType,
  }) {
    if (cacheType == CacheType.avatar) {
      // 頭像錯誤時顯示預設頭像
      return Container(
        width: width,
        height: height,
        color: Colors.white,
        child: Image.asset(
          'assets/images/avatar/no_bg/male_1.webp',
          fit: BoxFit.cover,
        ),
      );
    } else {
      // 餐廳圖片錯誤時顯示圖標
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: Icon(
          Icons.restaurant,
          color: Colors.grey[600],
          size:
              (width != null && height != null)
                  ? (width < height ? width : height) * 0.4
                  : 40,
        ),
      );
    }
  }
}
