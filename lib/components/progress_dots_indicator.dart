import 'package:flutter/material.dart';

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index < currentStep;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFB33D1C) : const Color(0xFF23456B),
            borderRadius: BorderRadius.circular(3), // 改為有圓角的正方形
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
