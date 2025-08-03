import 'package:flutter/material.dart';
import '../../utils/index.dart';

class LoadingImage extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;

  const LoadingImage({
    super.key,
    this.width = 50,
    this.height = 70,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 計算適當的陰影偏移量
    final adaptiveShadowOffset = 1.5.h;

    // 計算圖片的實際顯示尺寸，確保完整顯示
    final imageSize = height * 0.95; // 調整為高度的95%，確保圖片不會被裁切

    return SizedBox(
      width: width,
      height: height,
      child: Center(
        // 使用Center替代Stack中的alignment
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none, // 防止裁切超出邊界的部分
          children: [
            // 底部陰影圖片
            Positioned(
              bottom: 0, // 將陰影固定在底部
              child: Image.asset(
                'assets/images/icon/loading.webp',
                width: imageSize,
                height: imageSize,
                fit: BoxFit.contain,
                color: Colors.black.withOpacity(0.3),
                colorBlendMode: BlendMode.srcIn,
              ),
            ),

            // 主圖層
            Positioned(
              bottom: adaptiveShadowOffset, // 主圖層向上偏移
              child: Image.asset(
                'assets/images/icon/loading.webp',
                width: imageSize,
                height: imageSize,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
