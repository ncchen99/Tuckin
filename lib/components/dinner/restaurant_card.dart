import 'package:flutter/material.dart';
import 'package:tuckin/utils/index.dart';
import 'package:tuckin/services/services.dart';
import 'package:tuckin/components/components.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class RestaurantCard extends StatefulWidget {
  final String name;
  final String imageUrl;
  final String category;
  final String address;
  final bool isSelected;
  final VoidCallback onTap;
  final String? mapUrl;
  final int? voteCount;
  final bool isUserAdded; // 是否為用戶自己新增的餐廳
  final VoidCallback? onDelete; // 刪除按鈕的回調函數

  const RestaurantCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.address,
    required this.isSelected,
    required this.onTap,
    this.mapUrl,
    this.voteCount,
    this.isUserAdded = false,
    this.onDelete,
  });

  @override
  State<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<RestaurantCard>
    with SingleTickerProviderStateMixin {
  // 本地額外票數
  int _additionalVotes = 0;
  // 是否選擇過
  bool _wasSelected = false;
  // 動畫控制器
  late AnimationController _controller;
  // 動畫
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RestaurantCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 當卡片從未選中變為選中狀態時，增加票數並播放動畫
    if (!oldWidget.isSelected && widget.isSelected && !_wasSelected) {
      setState(() {
        _additionalVotes = 1;
        _wasSelected = true;
      });
      _controller.reset();
      _controller.forward();
    }
    // 當卡片從選中變為未選中狀態時，重置狀態
    else if (oldWidget.isSelected && !widget.isSelected) {
      setState(() {
        _additionalVotes = 0;
        _wasSelected = false;
      });
    }
  }

  // 獲取實際的票數（原始票數加上本地額外票數）
  int get _effectiveVoteCount {
    int baseCount = widget.voteCount ?? 0;
    return baseCount + _additionalVotes;
  }

  Future<void> _launchMapUrl() async {
    if (widget.mapUrl != null) {
      final Uri url = Uri.parse(widget.mapUrl!);
      if (!await launchUrl(url)) {
        throw Exception('無法開啟地圖: $url');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 添加調試信息，顯示投票數
    debugPrint(
      'RestaurantCard: ${widget.name}, voteCount: $_effectiveVoteCount',
    );

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 卡片主體
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(15.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: Offset(0, 2.h),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(12.h),
                child: Row(
                  children: [
                    // 餐廳縮圖
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.r),
                      child: _buildRestaurantImage(),
                    ),

                    SizedBox(width: 15.w),

                    // 餐廳資訊
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min, // 使用最小空間
                        children: [
                          // 餐廳名稱和投票數
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  // 當有投票標籤時，限制文字寬度
                                  width:
                                      (_effectiveVoteCount > 0)
                                          ? MediaQuery.of(context).size.width *
                                              0.5
                                          : null,
                                  child: Text(
                                    widget.name,
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: const Color(0xFF23456B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 2.h), // 減少間距
                          // 餐廳類別
                          Text(
                            widget.category,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontFamily: 'OtsutomeFont',
                              color: const Color(0xFF666666),
                            ),
                          ),

                          SizedBox(height: 20.h), // 減少間距
                          // 餐廳地址 - 可點擊
                          GestureDetector(
                            onTap: _launchMapUrl,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 2.h,
                              ), // 添加少量內邊距增加可點擊區域
                              color: Colors.transparent, // 保持透明背景
                              child: RichText(
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                text: TextSpan(
                                  text: widget.address,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFF23456B),
                                  ),
                                  // 移除這裡的手勢識別，因為已在外層GestureDetector設置
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 選中的邊框 - 調整為覆蓋整個卡片
            if (widget.isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(15.r),
                    border: Border.all(
                      color: const Color(0xFFB33D1C), // 橘色主題色
                      width: 3,
                    ),
                  ),
                ),
              ),

            // 票數顯示 - 帶動畫效果
            if (_effectiveVoteCount > 0)
              Positioned(
                top: -12.h,
                right: -6.w,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale:
                          _wasSelected && _additionalVotes > 0
                              ? _scaleAnimation.value
                              : 1.0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF23456B),
                          borderRadius: BorderRadius.circular(10.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 3,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder: (
                            Widget child,
                            Animation<double> animation,
                          ) {
                            return ScaleTransition(
                              scale: animation,
                              child: child,
                            );
                          },
                          child: Text(
                            '$_effectiveVoteCount 票',
                            key: ValueKey<int>(_effectiveVoteCount),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontFamily: 'OtsutomeFont',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 刪除按鈕 - 只在用戶新增的餐廳且未選中且無票數時顯示
            if (widget.isUserAdded &&
                !widget.isSelected &&
                _effectiveVoteCount == 0 &&
                widget.onDelete != null)
              Positioned(
                top: -18.h, // 調整位置補償 padding
                right: -18.w,
                child: _DeleteIconButton(
                  onTap: widget.onDelete!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 構建餐廳圖片小部件
  Widget _buildRestaurantImage() {
    // 檢查圖片 URL 是否無效
    if (widget.imageUrl.isEmpty) {
      return _buildFallbackImage();
    }

    // 如果是本地資源路徑
    if (widget.imageUrl.startsWith('assets/')) {
      return Image.asset(
        widget.imageUrl,
        width: 100.w,
        height: 100.h,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('本地圖片載入錯誤 (${widget.imageUrl}): $error');
          return _buildFallbackImage();
        },
      );
    }
    // 如果是網路圖片
    else {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
        cacheManager: ImageCacheService().restaurantCacheManager,
        width: 100.w,
        height: 100.h,
        fit: BoxFit.cover,
        placeholder: (context, url) {
          return ImageShimmerPlaceholder(
            width: 100.w,
            height: 100.h,
            borderRadius: BorderRadius.circular(10.r),
          );
        },
        errorWidget: (context, url, error) {
          debugPrint('網路圖片載入錯誤 (${widget.imageUrl}): $error');
          return _buildFallbackImage();
        },
      );
    }
  }

  // 備用圖片顯示
  Widget _buildFallbackImage() {
    return Container(
      width: 100.w,
      height: 100.h,
      color: Colors.grey[300],
      child: Icon(Icons.restaurant, color: Colors.grey[600], size: 40.sp),
    );
  }
}

// 自定義推薦餐廳卡片組件
class RecommendRestaurantCard extends StatelessWidget {
  final VoidCallback onTap;

  const RecommendRestaurantCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 12.h, horizontal: 20.w),
        height: 124.h, // 與餐廳卡片高度相符
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(15.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 25.h, horizontal: 25.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.only(bottom: 5.h),
                child: Stack(
                  children: [
                    // Shadow image
                    Positioned(
                      left: 0.w,
                      top: 3.h,
                      child: Image.asset(
                        'assets/images/icon/add.webp',
                        width: 40.w,
                        height: 40.h,
                        color: const Color.fromARGB(101, 0, 0, 0),
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                    // Main image
                    Image.asset(
                      'assets/images/icon/add.webp',
                      width: 40.w,
                      height: 40.h,
                    ),
                  ],
                ),
              ),

              SizedBox(width: 5.w),

              Text(
                '我想推薦餐廳',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontFamily: 'OtsutomeFont',
                  color: const Color.fromARGB(255, 169, 57, 26),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 刪除按鈕組件（帶陰影和按壓效果）
class _DeleteIconButton extends StatefulWidget {
  final VoidCallback onTap;

  const _DeleteIconButton({required this.onTap});

  @override
  State<_DeleteIconButton> createState() => _DeleteIconButtonState();
}

class _DeleteIconButtonState extends State<_DeleteIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // 陰影偏移量
    final shadowOffset = 4.h;
    final iconSize = 36.w; // 圖標尺寸
    final hitPadding = 10.w; // 擴大點擊範圍的 padding

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 確保整個區域都可點擊
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Padding(
        // 擴大點擊範圍但不改變視覺尺寸
        padding: EdgeInsets.all(hitPadding),
        child: SizedBox(
          width: iconSize,
          height: iconSize + shadowOffset,
          child: Stack(
            children: [
              // 底部陰影圖片
              if (!_isPressed)
                Positioned(
                  left: 0,
                  top: shadowOffset,
                  child: Image.asset(
                    'assets/images/icon/cross.webp',
                    width: iconSize,
                    height: iconSize,
                    fit: BoxFit.contain,
                    color: Colors.black.withOpacity(0.4),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),

              // 主圖標
              Positioned(
                top: _isPressed ? shadowOffset : 0,
                left: 0,
                child: Image.asset(
                  'assets/images/icon/cross.webp',
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
