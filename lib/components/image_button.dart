import 'package:flutter/material.dart';
import 'package:stroke_text/stroke_text.dart';
import '../utils/index.dart'; // 導入自適應佈局工具

// 圖片按鈕元件
class ImageButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final String imagePath;
  final double width;
  final double height;
  final TextStyle textStyle;

  const ImageButton({
    super.key,
    required this.onPressed,
    required this.text,
    required this.imagePath,
    this.width = 200,
    this.height = 100,
    this.textStyle = const TextStyle(
      fontSize: 24,
      color: Color(0xFFD1D1D1),
      fontFamily: 'OtsutomeFont',
      fontWeight: FontWeight.bold,
    ),
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

    // 將尺寸適配為自適應尺寸
    final adaptiveShadowOffset = (isSmallButton ? 3.h : 4.h); // 減小小號按鈕的陰影偏移
    final adaptiveTextTopOffset =
        (isSmallButton ? 5.h : 9.h); // 同步調整小號按鈕的文字頂部偏移
    final adaptiveTextNormalOffset = (isSmallButton ? 1.5.h : 3.h); // 調整常規文字偏移
    final adaptiveBottomSpace = (isSmallButton ? 5.h : 10.h); // 調整底部空間

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
            if (!_isPressed)
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
              child: Container(
                decoration: const BoxDecoration(color: Colors.transparent),
                child: Image.asset(
                  widget.imagePath,
                  width: widget.width,
                  height: widget.height,
                  fit: BoxFit.contain,
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
                child: StrokeText(
                  text: widget.text,
                  textStyle: widget.textStyle.copyWith(
                    letterSpacing: 1.0.w, // 自適應字母間距
                    height: 1.2, // 減小行高以改善垂直對齊
                    fontSize:
                        isSmallButton
                            ? widget.textStyle.fontSize ?? 18
                            : widget.textStyle.fontSize ?? 20, // 根據按鈕大小調整字體
                  ),
                  strokeColor: const Color(0xFF23456B), // 深藍色邊框
                  strokeWidth: (isSmallButton ? 3.r : 4.r), // 自適應邊框寬度
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
