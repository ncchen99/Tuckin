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
    // 計算適當的陰影偏移量 - 從3.h減小到1.5.h
    final adaptiveShadowOffset = 1.5.h;

    // 計算圖片的實際顯示尺寸，確保完整顯示
    final imageSize = height; // 使用高度的80%作為圖片尺寸，確保完全顯示

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center, // 居中對齊
        children: [
          // 底部陰影圖片
          Positioned(
            child: Image.asset(
              'assets/images/icon/loading.png',
              width: imageSize,
              height: imageSize,
              fit: BoxFit.contain,
              color: Colors.black.withOpacity(0.3), // 降低陰影不透明度從0.4到0.3
              colorBlendMode: BlendMode.srcIn,
            ),
          ),

          // 主圖層 - 略微偏上
          Positioned(
            bottom: adaptiveShadowOffset + 1.h, // 從2.h減小到1.h，縮短主圖層和陰影的距離
            child: Image.asset(
              'assets/images/icon/loading.png',
              width: imageSize,
              height: imageSize,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
