import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:tuckin/utils/index.dart';
import 'package:url_launcher/url_launcher.dart';

class RestaurantCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final String category;
  final String address;
  final bool isSelected;
  final VoidCallback onTap;
  final String? mapUrl;
  final int? voteCount;

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
  });

  Future<void> _launchMapUrl() async {
    if (mapUrl != null) {
      final Uri url = Uri.parse(mapUrl!);
      if (!await launchUrl(url)) {
        throw Exception('無法開啟地圖: $url');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 20.w),
        child: Stack(
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
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontFamily: 'OtsutomeFont',
                                    color: const Color(0xFF23456B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (voteCount != null && voteCount! > 0)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB33D1C),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Text(
                                    '${voteCount}票',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          SizedBox(height: 2.h), // 減少間距
                          // 餐廳類別
                          Text(
                            category,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontFamily: 'OtsutomeFont',
                              color: const Color(0xFF666666),
                            ),
                          ),

                          SizedBox(height: 20.h), // 減少間距
                          // 餐廳地址 - 可點擊
                          RichText(
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            text: TextSpan(
                              text: address,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontFamily: 'OtsutomeFont',
                                color: const Color(0xFF23456B),
                              ),
                              recognizer:
                                  TapGestureRecognizer()
                                    ..onTap = () {
                                      _launchMapUrl();
                                    },
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
            if (isSelected)
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
          ],
        ),
      ),
    );
  }

  // 構建餐廳圖片小部件
  Widget _buildRestaurantImage() {
    // 檢查圖片 URL 是否無效
    if (imageUrl.isEmpty) {
      return _buildFallbackImage();
    }

    // 如果是本地資源路徑
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: 100.w,
        height: 100.h,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('本地圖片載入錯誤 ($imageUrl): $error');
          return _buildFallbackImage();
        },
      );
    }
    // 如果是網路圖片
    else {
      return Image.network(
        imageUrl,
        width: 100.w,
        height: 100.h,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 100.w,
            height: 100.h,
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                value:
                    loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                color: const Color(0xFF23456B),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('網路圖片載入錯誤 ($imageUrl): $error');
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
        margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 20.w),
        height: 124.h, // 與餐廳卡片高度相符
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 255, 255, 255), // 改為橘色背景
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
                        'assets/images/icon/add.png',
                        width: 40.w,
                        height: 40.h,
                        color: const Color.fromARGB(101, 0, 0, 0),
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                    // Main image
                    Image.asset(
                      'assets/images/icon/add.png',
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
