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

  const RestaurantCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.address,
    required this.isSelected,
    required this.onTap,
    this.mapUrl,
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
                      child: Image.network(
                        imageUrl,
                        width: 100.w,
                        height: 100.h,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 100.w,
                            height: 100.h,
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.restaurant,
                              color: Colors.grey[600],
                              size: 40.sp,
                            ),
                          );
                        },
                      ),
                    ),

                    SizedBox(width: 15.w),

                    // 餐廳資訊
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min, // 使用最小空間
                        children: [
                          // 餐廳名稱
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontFamily: 'OtsutomeFont',
                              color: const Color(0xFF23456B),
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
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
