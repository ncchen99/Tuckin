import 'package:flutter/material.dart';
import '../../utils/index.dart'; // 導入自適應佈局工具

// 自定義輸入框元件（帶陰影圖標）
class IconTextInput extends StatelessWidget {
  final String hintText;
  final String iconPath;
  final TextEditingController controller;
  final bool obscureText;
  final FocusNode? focusNode;

  const IconTextInput({
    super.key,
    required this.hintText,
    required this.iconPath,
    required this.controller,
    this.obscureText = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.h),
      padding: EdgeInsets.only(left: 15.w, right: 10.w),
      height: 60.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r), // 使用自適應圓角
        border: Border.all(color: const Color(0xFF23456B), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // 確保子元素垂直居中
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              focusNode: focusNode,
              style: TextStyle(
                fontFamily: 'OtsutomeFont',
                fontSize: 18.sp, // 增加文字大小
                height: 1.2, // 調整行高，幫助文字垂直居中
              ),
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontFamily: 'OtsutomeFont',
                  fontSize: 16.sp, // 增加提示文字大小
                  height: 1.2, // 與輸入文字保持一致
                ),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 15.h, // 增加垂直內邊距，調整文字位置
                ),
                isDense: true, // 使輸入框更緊湊
                isCollapsed: false, // 確保文字居中顯示
                alignLabelWithHint: true, // 讓提示文字與輸入文字對齊
              ),
              textAlignVertical: TextAlignVertical.center, // 設置文字垂直對齊為居中
            ),
          ),
          SizedBox(width: 5.w), // 增加圖標與文字的間距
          // 帶陰影的圖標
          SizedBox(
            width: 32.w, // 給定更大的容器尺寸來容納陰影
            height: 32.h,
            child: Stack(
              clipBehavior: Clip.none, // 防止陰影被裁切
              alignment: Alignment.center, // 確保圖標居中對齊
              children: [
                // 底部陰影圖片
                Positioned(
                  left: 0, // 向右偏移
                  top: 2, // 向下偏移
                  child: Image.asset(
                    iconPath,
                    width: 30.w,
                    height: 30.h,
                    fit: BoxFit.contain,
                    color: Colors.black.withValues(alpha: .4),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
                // 圖片主圖層
                Positioned(
                  left: 0,
                  top: 0,
                  child: Image.asset(
                    iconPath,
                    width: 30.w,
                    height: 30.h,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
