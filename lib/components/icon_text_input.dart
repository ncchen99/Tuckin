import 'package:flutter/material.dart';

// 自定義輸入框元件（帶陰影圖標）
class IconTextInput extends StatelessWidget {
  final String hintText;
  final String iconPath;
  final TextEditingController controller;
  final bool obscureText;

  const IconTextInput({
    super.key,
    required this.hintText,
    required this.iconPath,
    required this.controller,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      width: MediaQuery.of(context).size.width * 0.8,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // 減少圓角，但保留長方形結構
        border: Border.all(color: const Color(0xFF23456B), width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              style: const TextStyle(
                fontFamily: 'OtsutomeFont',
                fontSize: 16,
                height: 1.4, // 進一步增加行高
              ),
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  color: Colors.grey,
                  fontFamily: 'OtsutomeFont',
                  height: 1.4, // 增加行高
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                ), // 調整為上下對稱填充，使文字垂直居中
                isCollapsed: false, // 確保文字居中顯示
                alignLabelWithHint: true, // 讓提示文字與輸入文字對齊
              ),
              textAlignVertical: TextAlignVertical.center, // 設置文字垂直對齊為居中
            ),
          ),
          // 帶陰影的圖標
          Stack(
            children: [
              // 底部陰影圖片
              Positioned(
                left: 0,
                top: 2,
                child: Image.asset(
                  iconPath,
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                  color: Colors.black.withValues(alpha: 0.4),
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
              // 圖片主圖層
              Image.asset(iconPath, width: 30, height: 30, fit: BoxFit.contain),
            ],
          ),
        ],
      ),
    );
  }
}
