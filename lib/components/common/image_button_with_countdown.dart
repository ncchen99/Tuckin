import 'package:flutter/material.dart';
import 'package:stroke_text/stroke_text.dart';
import '../../utils/index.dart';

// 帶有倒數計時的圖片按鈕元件
class ImageButtonWithCountdown extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final String countdownText;
  final String imagePath;
  final double width;
  final double height;
  final TextStyle textStyle;
  final TextStyle countdownTextStyle;
  final Color? buttonColor;
  final double buttonOpacity;
  final bool isEnabled;

  const ImageButtonWithCountdown({
    super.key,
    required this.onPressed,
    required this.text,
    required this.countdownText,
    required this.imagePath,
    this.width = 150,
    this.height = 75,
    this.textStyle = const TextStyle(
      fontSize: 20,
      color: Color(0xFFD1D1D1),
      fontFamily: 'OtsutomeFont',
      fontWeight: FontWeight.bold,
    ),
    this.countdownTextStyle = const TextStyle(
      fontSize: 15,
      color: Color(0xFFD1D1D1),
      fontFamily: 'OtsutomeFont',
      fontWeight: FontWeight.bold,
    ),
    this.buttonColor,
    this.buttonOpacity = 1.0,
    this.isEnabled = true,
  });

  @override
  ImageButtonWithCountdownState createState() =>
      ImageButtonWithCountdownState();
}

class ImageButtonWithCountdownState extends State<ImageButtonWithCountdown> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // 根據按鈕尺寸計算適當的陰影偏移量和比例
    final bool isSmallButton = widget.imagePath.contains('_m');
    final bool isRedButton = widget.imagePath.contains('red');

    // 將尺寸適配為自適應尺寸
    final adaptiveShadowOffset = (isSmallButton ? 3.h : 4.h);
    final adaptiveBottomSpace = (isSmallButton ? 5.h : 10.h);

    // 計算文字垂直居中位置
    final buttonHeight = widget.height;
    final totalHeight = buttonHeight + adaptiveBottomSpace;
    final textSpacing = 5.h; // 兩行文字之間的間距
    final mainTextHeight = 25.h; // 估計主要文字高度
    final countdownTextHeight = 18.h; // 估計倒數文字高度
    final totalTextHeight = mainTextHeight + textSpacing + countdownTextHeight;

    // 計算頂部空間使文字整體垂直居中
    final topPadding = (buttonHeight - totalTextHeight) / 2;
    final mainTextTop = topPadding;
    final countdownTextTop = topPadding + mainTextHeight + textSpacing;

    // 按下時的偏移
    final pressedOffset = adaptiveShadowOffset + 1.h;

    // 如果按鈕被禁用，直接返回靜態效果
    if (!widget.isEnabled) {
      return SizedBox(
        width: widget.width,
        height: totalHeight,
        child: Stack(
          children: [
            // 禁用狀態下的按鈕
            Positioned(
              top: 0,
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
                child: Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    widget.imagePath,
                    width: widget.width,
                    height: buttonHeight,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // 主要文字
            Positioned(
              top: mainTextTop,
              left: 0,
              right: 0,
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
                                ? widget.textStyle.fontSize ?? 18
                                : widget.textStyle.fontSize ?? 20,
                      ),
                      strokeColor: const Color.fromARGB(255, 154, 67, 24),
                      strokeWidth: (isSmallButton ? 3.r : 4.r),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),

            // 倒數文字
            Positioned(
              top: countdownTextTop,
              left: 0,
              right: 0,
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
                      text: widget.countdownText,
                      textStyle: widget.countdownTextStyle.copyWith(
                        letterSpacing: 0.5.w,
                        height: 1.2,
                        fontSize:
                            isSmallButton
                                ? widget.countdownTextStyle.fontSize ?? 14
                                : widget.countdownTextStyle.fontSize ?? 15,
                      ),
                      strokeColor: const Color.fromARGB(255, 154, 67, 24),
                      strokeWidth: (isSmallButton ? 2.r : 3.r),
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

    // 啟用狀態下的按鈕
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: SizedBox(
        width: widget.width,
        height: totalHeight,
        child: Stack(
          children: [
            // 底部陰影
            if (!_isPressed && widget.buttonOpacity >= 0.9)
              Positioned(
                left: 0,
                top: adaptiveShadowOffset,
                child: Container(
                  width: widget.width,
                  height: buttonHeight,
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Image.asset(
                    widget.imagePath,
                    width: widget.width,
                    height: buttonHeight,
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
                    height: buttonHeight,
                    fit: BoxFit.contain,
                    color: widget.buttonColor,
                  ),
                ),
              ),
            ),

            // 主要文字
            Positioned(
              top: _isPressed ? mainTextTop + pressedOffset : mainTextTop,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: widget.buttonOpacity,
                  child: StrokeText(
                    text: widget.text,
                    textStyle: widget.textStyle.copyWith(
                      letterSpacing: 1.0.w,
                      height: 1.2,
                      fontSize:
                          isSmallButton
                              ? widget.textStyle.fontSize ?? 18
                              : widget.textStyle.fontSize ?? 20,
                    ),
                    strokeColor:
                        isRedButton
                            ? const Color.fromARGB(255, 86, 0, 0)
                            : const Color.fromARGB(255, 77, 74, 71),
                    strokeWidth: (isSmallButton ? 3.r : 4.r),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            // 倒數文字
            Positioned(
              top:
                  _isPressed
                      ? countdownTextTop + pressedOffset
                      : countdownTextTop,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: widget.buttonOpacity,
                  child: StrokeText(
                    text: widget.countdownText,
                    textStyle: widget.countdownTextStyle.copyWith(
                      letterSpacing: 0.5.w,
                      height: 1.2,
                      fontSize:
                          isSmallButton
                              ? widget.countdownTextStyle.fontSize ?? 14
                              : widget.countdownTextStyle.fontSize ?? 15,
                    ),
                    strokeColor:
                        isRedButton
                            ? const Color.fromARGB(255, 86, 0, 0)
                            : const Color.fromARGB(255, 77, 74, 71),
                    strokeWidth: (isSmallButton ? 2.r : 3.r),
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
