import 'package:flutter/material.dart';
import '../../utils/index.dart'; // 導入自適應佈局工具

class InfoTipBox extends StatelessWidget {
  final String message;
  final Duration autoHideDuration;
  final bool show;
  final VoidCallback? onHide;

  const InfoTipBox({
    super.key,
    required this.message,
    this.autoHideDuration = const Duration(seconds: 5),
    required this.show,
    this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: show ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      onEnd: () {
        if (!show && onHide != null) {
          onHide!();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFF23456B), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 信息圖標，使用圖片並添加陰影
            SizedBox(
              width: 22.w, // 給定更大的容器尺寸來容納陰影
              height: 22.h,
              child: Stack(
                clipBehavior: Clip.none, // 防止陰影被裁切
                children: [
                  // 陰影層
                  Positioned(
                    left: 0, // 向右偏移
                    top: 1, // 向下偏移
                    child: Image.asset(
                      'assets/images/icon/info.png',
                      width: 20.w,
                      height: 20.h,
                      color: Colors.black.withOpacity(0.4), // 稍微增加不透明度
                    ),
                  ),
                  // 主圖層
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Image.asset(
                      'assets/images/icon/info.png',
                      width: 20.w,
                      height: 20.h,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 4.w),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF23456B),
                  fontFamily: 'OtsutomeFont',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
