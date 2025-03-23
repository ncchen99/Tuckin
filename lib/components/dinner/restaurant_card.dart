import 'package:flutter/material.dart';
import 'package:tuckin/utils/index.dart';
import 'package:tuckin/models/restaurant.dart';

/// 餐廳推薦卡片組件
/// 用於顯示推薦的餐廳信息及選擇按鈕
class RestaurantCard extends StatelessWidget {
  /// 餐廳信息
  final Restaurant restaurant;

  /// 是否已選擇
  final bool isSelected;

  /// 點擊選擇回調
  final VoidCallback onSelect;

  /// 點擊查看詳情回調
  final VoidCallback onViewDetails;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.isSelected = false,
    required this.onSelect,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 15.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: isSelected ? const Color(0xFFF3843E) : Colors.grey.shade300,
          width: isSelected ? 3 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 餐廳照片區域
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15.r),
              topRight: Radius.circular(15.r),
            ),
            child: Stack(
              children: [
                // 餐廳照片
                Image.network(
                  restaurant.photoUrl ??
                      'https://via.placeholder.com/400x200?text=No+Image',
                  height: 150.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150.h,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Icon(
                          Icons.restaurant,
                          size: 50.r,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    );
                  },
                ),

                // 選中標記
                if (isSelected)
                  Positioned(
                    top: 10.h,
                    right: 10.w,
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3843E),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, color: Colors.white, size: 20.r),
                    ),
                  ),
              ],
            ),
          ),

          // 餐廳信息區域
          Padding(
            padding: EdgeInsets.all(15.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 餐廳名稱與評分
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        restaurant.name,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontFamily: 'OtsutomeFont',
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF23456B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (restaurant.rating != null)
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: const Color(0xFFF3843E),
                            size: 18.r,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            restaurant.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontFamily: 'OtsutomeFont',
                              color: const Color(0xFF23456B),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                SizedBox(height: 5.h),

                // 餐廳類型
                Text(
                  _getRestaurantTypeText(restaurant.type),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontFamily: 'OtsutomeFont',
                    color: Colors.grey.shade600,
                  ),
                ),

                SizedBox(height: 5.h),

                // 價格級別
                if (restaurant.priceLevel != null)
                  Text(
                    _getPriceLevelText(restaurant.priceLevel!),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontFamily: 'OtsutomeFont',
                      color: Colors.grey.shade600,
                    ),
                  ),

                SizedBox(height: 15.h),

                // 按鈕區域
                Row(
                  children: [
                    // 查看詳情按鈕
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onViewDetails,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF23456B),
                          side: const BorderSide(color: Color(0xFF23456B)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                        ),
                        child: Text(
                          '查看詳情',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontFamily: 'OtsutomeFont',
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 10.w),

                    // 選擇按鈕
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onSelect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isSelected
                                  ? const Color(0xFFF3843E)
                                  : const Color(0xFF23456B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                        ),
                        child: Text(
                          isSelected ? '已選擇' : '選擇',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontFamily: 'OtsutomeFont',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 獲取餐廳類型的中文顯示文字
  String _getRestaurantTypeText(RestaurantType type) {
    switch (type) {
      case RestaurantType.chinese:
        return '中式料理';
      case RestaurantType.japanese:
        return '日式料理';
      case RestaurantType.korean:
        return '韓式料理';
      case RestaurantType.thai:
        return '泰式料理';
      case RestaurantType.western:
        return '西式料理';
      case RestaurantType.italian:
        return '義式料理';
      case RestaurantType.american:
        return '美式料理';
      case RestaurantType.mexican:
        return '墨西哥料理';
      case RestaurantType.indian:
        return '印度料理';
      case RestaurantType.vietnamese:
        return '越式料理';
      case RestaurantType.seafood:
        return '海鮮料理';
      case RestaurantType.bbq:
        return '燒烤';
      case RestaurantType.hotpot:
        return '火鍋';
      case RestaurantType.vegetarian:
        return '素食料理';
      case RestaurantType.fastFood:
        return '速食';
      case RestaurantType.cafe:
        return '咖啡廳';
      case RestaurantType.dessert:
        return '甜點';
      case RestaurantType.other:
        return '其他料理';
      default:
        return '未分類';
    }
  }

  /// 獲取價格級別的顯示文字
  String _getPriceLevelText(int priceLevel) {
    switch (priceLevel) {
      case 0:
        return '¥ (便宜)';
      case 1:
        return '¥¥';
      case 2:
        return '¥¥¥';
      case 3:
        return '¥¥¥¥';
      case 4:
        return '¥¥¥¥¥ (高價)';
      default:
        return '價格未知';
    }
  }
}
