import 'package:flutter/material.dart';
import '../../utils/index.dart'; // 導入自適應佈局工具

// 返回按鈕元件
class BackIconButton extends StatefulWidget {
  final VoidCallback onPressed;
  final double width;
  final double height;
  final Color? buttonColor; // 按鈕顏色
  final double buttonOpacity; // 按鈕透明度

  const BackIconButton({
    super.key,
    required this.onPressed,
    this.width = 40,
    this.height = 40,
    this.buttonColor, // 默認為null，使用原始顏色
    this.buttonOpacity = 1.0, // 默認完全不透明
  });

  @override
  _BackIconButtonState createState() => _BackIconButtonState();
}

class _BackIconButtonState extends State<BackIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // 根據按鈕尺寸計算適當的陰影偏移量
    final adaptiveShadowOffset = 3.h;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
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
                    'assets/images/icon/arrow_left.png',
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
              top: _isPressed ? adaptiveShadowOffset : 0,
              child: Opacity(
                opacity: widget.buttonOpacity,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Image.asset(
                    'assets/images/icon/arrow_left.png',
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.contain,
                    color: widget.buttonColor, // 使用傳入的顏色，為null時保持原色
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
