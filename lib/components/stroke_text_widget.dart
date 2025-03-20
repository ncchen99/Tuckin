import 'package:flutter/material.dart';
import 'package:stroke_text/stroke_text.dart';

// 自定義文字元件（帶邊框）
class StrokeTextWidget extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color textColor;
  final Color strokeColor;
  final TextAlign textAlign;
  final EdgeInsets padding;
  final TextOverflow overflow;
  final int? maxLines;

  const StrokeTextWidget({
    super.key,
    required this.text,
    this.fontSize = 16.0,
    this.textColor = const Color(0xFFD1D1D1),
    this.strokeColor = const Color(0xFF23456B),
    this.textAlign = TextAlign.left,
    this.padding = EdgeInsets.zero,
    this.overflow = TextOverflow.visible,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: StrokeText(
        text: text,
        textStyle: TextStyle(
          fontSize: fontSize,
          color: textColor,
          fontFamily: 'OtsutomeFont',
          fontWeight: FontWeight.bold,
          height: 1.4, // 進一步增加行高，使文字下移
          overflow: overflow,
        ),
        strokeColor: strokeColor,
        strokeWidth: 3,
        textAlign: textAlign,
        maxLines: maxLines,
      ),
    );
  }
}
