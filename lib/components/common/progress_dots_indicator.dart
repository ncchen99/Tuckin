import 'package:flutter/material.dart';
import '../../utils/index.dart'; // 導入自適應佈局工具

// 進度指示器元件 - 使用藍色和橘色的圓角正方形
class ProgressDotsIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;

  const ProgressDotsIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    final double dotSize = 12.h; // 使用統一縮放，確保寬高一致為正方形
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 5.w), // 使用自適應寬度
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFB33D1C) : const Color(0xFF23456B),
            borderRadius: BorderRadius.circular(dotSize * 0.3), // 依尺寸等比例圓角
            border:
                isActive
                    ? Border.all(color: const Color(0xFF23456B), width: 1.5)
                    : null, // 為活動點添加藍色邊框
          ),
        );
      }),
    );
  }
}
