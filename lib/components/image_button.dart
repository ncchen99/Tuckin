import 'package:flutter/material.dart';
import 'package:stroke_text/stroke_text.dart';

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
    // 根據按鈕尺寸計算適當的陰影偏移量
    final bool isSmallButton = widget.width <= 130; // 判斷是否為小號按鈕
    final double shadowOffset = isSmallButton ? 3 : 5; // 小按鈕用小陰影
    final double textTopOffset = isSmallButton ? 6 : 9; // 小按鈕文字偏移量較小
    final double textNormalOffset = isSmallButton ? 2 : 3; // 常規狀態下的文字偏移量

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: SizedBox(
        width: widget.width,
        height: widget.height + (isSmallButton ? 6 : 10), // 小按鈕下方空間較小
        child: Stack(
          children: [
            // 底部陰影圖片 - 使用相同的圖片但僅向下偏移
            if (!_isPressed)
              Positioned(
                left: 0,
                top: shadowOffset,
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(color: Colors.transparent),
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
              top: _isPressed ? shadowOffset + 1 : 0,
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
                  _isPressed ? textTopOffset : textNormalOffset, // 根據按鈕大小調整文字位置
              left: 0,
              right: 0,
              bottom: isSmallButton ? 6 : 10, // 調整文字位置，避免被底部切斷
              child: Center(
                child: StrokeText(
                  text: widget.text,
                  textStyle: widget.textStyle.copyWith(
                    letterSpacing: 1.0,
                    height: 1.4, // 進一步增加行高
                  ),
                  strokeColor: const Color(0xFF23456B), // 修改為深藍色
                  strokeWidth: isSmallButton ? 3 : 4, // 小按鈕文字邊框較細
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
