import 'package:flutter/material.dart';

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
    return GestureDetector(
      onTap: () {
        onChanged(!value);
      },
      child: Container(
        width: 22, // 縮小尺寸
        height: 22, // 縮小尺寸
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7), // 調整為比例合適的圓角
          border: Border.all(color: const Color(0xFF23456B), width: 2),
        ),
        // 當選中時，內部顯示一個有邊距的橘色小方塊
        child:
            value
                ? Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFB33D1C),
                      borderRadius: BorderRadius.circular(3), // 調整內部勾選標記的圓角
                    ),
                  ),
                )
                : null,
      ),
    );
  }
}
