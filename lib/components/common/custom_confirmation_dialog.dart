import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/utils/index.dart';

class CustomConfirmationDialog extends StatefulWidget {
  final String iconPath;
  final String title;
  final String content;
  final String cancelButtonText;
  final String confirmButtonText;
  final VoidCallback? onCancel;
  final Future<void> Function()? onConfirm;
  final Color loadingColor;
  final bool barrierDismissible;

  const CustomConfirmationDialog({
    super.key,
    required this.iconPath,
    required this.title,
    required this.content,
    this.cancelButtonText = '取消',
    this.confirmButtonText = '確定',
    this.onCancel,
    this.onConfirm,
    this.loadingColor = const Color(0xFFB33D1C),
    this.barrierDismissible = true,
  });

  @override
  State<CustomConfirmationDialog> createState() =>
      _CustomConfirmationDialogState();
}

class _CustomConfirmationDialogState extends State<CustomConfirmationDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isProcessing,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            width: 320.w,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: Offset(0, 8.h),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 30.h),
                // 圖標
                SizedBox(
                  width: 55.w,
                  height: 55.h,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 底部陰影
                      Positioned(
                        left: 0,
                        top: 3.h,
                        child: Image.asset(
                          widget.iconPath,
                          width: 55.w,
                          height: 55.h,
                          color: Colors.black.withOpacity(0.4),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                      // 主圖像
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Image.asset(
                          widget.iconPath,
                          width: 55.w,
                          height: 55.h,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 15.h),
                // 標題（如果有）
                if (widget.title.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 5.h),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontFamily: 'OtsutomeFont',
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF23456B),
                      ),
                    ),
                  ),
                // 內容
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 20.w),
                  padding: EdgeInsets.symmetric(
                    vertical: 10.h,
                    horizontal: 10.w,
                  ),
                  child: Text(
                    widget.content,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontFamily: 'OtsutomeFont',
                      color: const Color(0xFF23456B),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                // 按鈕
                _isProcessing
                    ? Center(
                      child: LoadingImage(
                        width: 60.w,
                        height: 60.h,
                        color: widget.loadingColor,
                      ),
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ImageButton(
                          text: widget.cancelButtonText,
                          imagePath: 'assets/images/ui/button/blue_m.webp',
                          width: 110.w,
                          height: 55.h,
                          onPressed: () {
                            if (widget.onCancel != null) {
                              widget.onCancel!();
                            } else {
                              Navigator.of(context).pop();
                            }
                          },
                          textStyle: TextStyle(
                            color: const Color(0xFFD1D1D1),
                            fontFamily: 'OtsutomeFont',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 20.w),
                        ImageButton(
                          text: widget.confirmButtonText,
                          imagePath: 'assets/images/ui/button/red_m.webp',
                          width: 110.w,
                          height: 55.h,
                          onPressed: () async {
                            if (widget.onConfirm != null) {
                              setState(() {
                                _isProcessing = true;
                              });

                              try {
                                await widget.onConfirm!();
                              } catch (e) {
                                debugPrint('確認操作錯誤: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '操作失敗: ${e.toString()}',
                                        style: const TextStyle(
                                          fontFamily: 'OtsutomeFont',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isProcessing = false;
                                  });
                                }
                              }
                            } else {
                              Navigator.of(context).pop(true);
                            }
                          },
                          textStyle: TextStyle(
                            color: const Color(0xFFD1D1D1),
                            fontFamily: 'OtsutomeFont',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                SizedBox(height: 25.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 輔助函數來顯示對話框
Future<bool?> showCustomConfirmationDialog({
  required BuildContext context,
  required String iconPath,
  required String content,
  String title = '',
  String cancelButtonText = '取消',
  String confirmButtonText = '確定',
  VoidCallback? onCancel,
  Future<void> Function()? onConfirm,
  Color loadingColor = const Color(0xFFB33D1C),
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext context) {
      return CustomConfirmationDialog(
        iconPath: iconPath,
        title: title,
        content: content,
        cancelButtonText: cancelButtonText,
        confirmButtonText: confirmButtonText,
        onCancel: onCancel,
        onConfirm: onConfirm,
        loadingColor: loadingColor,
        barrierDismissible: barrierDismissible,
      );
    },
  );
}
