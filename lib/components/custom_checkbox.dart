import 'package:flutter/material.dart';
import '../utils/index.dart'; // 導入自適應佈局工具

// 自定義勾選框元件
class CustomCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const CustomCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 確保正方形比例，使用相同的尺寸
    final double checkboxSize = 22.r; // 使用 r 方法確保寬高相等

    return GestureDetector(
      onTap: () {
        onChanged(!value);
      },
      child: Container(
        width: checkboxSize,
        height: checkboxSize,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7.r), // 使用自適應圓角
          border: Border.all(color: const Color(0xFF23456B), width: 2),
        ),
        // 當選中時，內部顯示一個有邊距的橘色小方塊
        child:
            value
                ? Padding(
                  padding: EdgeInsets.all(2.r), // 使用自適應邊距
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFB33D1C),
                      borderRadius: BorderRadius.circular(3.r), // 使用自適應圓角
                    ),
                  ),
                )
                : null,
      ),
    );
  }
}
