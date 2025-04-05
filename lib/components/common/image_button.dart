import 'package:flutter/material.dart';
import 'package:stroke_text/stroke_text.dart';
import '../../utils/index.dart'; // 導入自適應佈局工具

// 圖片按鈕元件
class ImageButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final String imagePath;
  final double width;
  final double height;
  final TextStyle textStyle;
  final Color? buttonColor; // 新增: 按鈕顏色
  final double buttonOpacity; // 新增: 按鈕透明度
  final bool isEnabled; // 新增: 按鈕是否啟用

  const ImageButton({
    super.key,
    required this.onPressed,
    required this.text,
    required this.imagePath,
    this.width = 150,
    this.height = 75,
    this.textStyle = const TextStyle(
      fontSize: 20,
      color: Color(0xFFD1D1D1),
      fontFamily: 'OtsutomeFont',
      fontWeight: FontWeight.bold,
    ),
    this.buttonColor, // 默認為null，使用原始顏色
    this.buttonOpacity = 1.0, // 默認完全不透明
    this.isEnabled = true, // 默認啟用
  });

  @override
  _ImageButtonState createState() => _ImageButtonState();
}

class _ImageButtonState extends State<ImageButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // 根據按鈕尺寸計算適當的陰影偏移量和比例
    final bool isSmallButton = widget.imagePath.contains('_m');
    final bool isRedButton = widget.imagePath.contains('red');

    // 將尺寸適配為自適應尺寸
    final adaptiveShadowOffset = (isSmallButton ? 3.h : 4.h); // 減小小號按鈕的陰影偏移
    final adaptiveTextTopOffset =
        (isSmallButton ? 5.h : 9.h); // 同步調整小號按鈕的文字頂部偏移
    final adaptiveTextNormalOffset = (isSmallButton ? 1.5.h : 3.h); // 調整常規文字偏移
    final adaptiveBottomSpace = (isSmallButton ? 5.h : 10.h); // 調整底部空間

    // 如果按鈕被禁用，直接返回靜態效果，沒有任何手勢識別
    if (!widget.isEnabled) {
      return SizedBox(
        width: widget.width,
        height: widget.height + adaptiveBottomSpace,
        child: Stack(
          children: [
            // 禁用狀態下的按鈕 - 使用 ColorFiltered 實現真正的灰階效果
            Positioned(
              top: 0,
              child: ColorFiltered(
                // 使用灰階矩陣轉換
                colorFilter: const ColorFilter.matrix([
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: Opacity(
                  opacity: 0.8, // 降低透明度增強禁用效果
                  child: Image.asset(
                    widget.imagePath,
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // 按鈕文字 - 灰階效果
            Positioned(
              top: adaptiveTextNormalOffset,
              left: 0,
              right: 0,
              bottom: adaptiveBottomSpace,
              child: Center(
                child: Opacity(
                  opacity: 0.6,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
                    child: StrokeText(
                      text: widget.text,
                      textStyle: widget.textStyle.copyWith(
                        letterSpacing: 1.0.w,
                        height: 1.2,
                        fontSize:
                            isSmallButton
                                ? (widget.textStyle.fontSize ?? 18).sp
                                : (widget.textStyle.fontSize ?? 20).sp,
                      ),
                      strokeColor: const Color(0xFF23456B),
                      strokeWidth: (isSmallButton ? 3.r : 4.r),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 啟用狀態下的按鈕 - 有手勢識別
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: SizedBox(
        width: widget.width,
        height: widget.height + adaptiveBottomSpace, // 使用自適應底部空間
        child: Stack(
          children: [
            // 底部陰影圖片 - 使用相同的圖片但僅向下偏移
            if (!_isPressed &&
                widget.buttonOpacity >= 0.9) // 只有按鈕透明度高且未按下時才顯示陰影
              Positioned(
                left: 0,
                top: adaptiveShadowOffset,
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Image.asset(
                    widget.imagePath,
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.contain,
                    color: Colors.black.withValues(alpha: 0.4),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),

            // 按鈕主圖層
            Positioned(
              top: _isPressed ? adaptiveShadowOffset + 1.h : 0,
              child: Opacity(
                opacity: widget.buttonOpacity,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Image.asset(
                    widget.imagePath,
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.contain,
                    color: widget.buttonColor, // 使用傳入的顏色，為null時保持原色
                  ),
                ),
              ),
            ),

            // 按鈕文字 - 使用 StrokeText 組件
            Positioned(
              top:
                  _isPressed ? adaptiveTextTopOffset : adaptiveTextNormalOffset,
              left: 0,
              right: 0,
              bottom: adaptiveBottomSpace, // 使用自適應底部空間
              child: Center(
                child: Opacity(
                  opacity: widget.buttonOpacity,
                  child: StrokeText(
                    text: widget.text,
                    textStyle: widget.textStyle.copyWith(
                      letterSpacing: 1.0.w, // 自適應字母間距
                      height: 1.2, // 減小行高以改善垂直對齊
                      fontSize:
                          isSmallButton
                              ? (widget.textStyle.fontSize ?? 18).sp
                              : (widget.textStyle.fontSize ?? 20)
                                  .sp, // 使用自適應字體大小
                    ),
                    strokeColor:
                        isRedButton
                            ? const Color(0xFF23456B)
                            : const Color.fromARGB(255, 77, 74, 71), // 深藍色邊框
                    strokeWidth: (isSmallButton ? 3.r : 4.r), // 自適應邊框寬度
                    textAlign: TextAlign.center,
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
