import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/utils/index.dart';

/// 全螢幕圖片查看器
/// 支援手勢縮放和滑動關閉
class ImageViewer extends StatefulWidget {
  final String imageUrl;

  const ImageViewer({super.key, required this.imageUrl});

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  double _dragDistance = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(
        _isDragging ? (1 - (_dragDistance.abs() / 400)).clamp(0.0, 1.0) : 1.0,
      ),
      body: Stack(
        children: [
          // 圖片區域 - 支援手勢關閉
          GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                _isDragging = true;
                _dragDistance += details.delta.dy;
              });
            },
            onVerticalDragEnd: (details) {
              if (_dragDistance.abs() > 100) {
                // 拖動距離超過 100 則關閉
                Navigator.of(context).pop();
              } else {
                // 否則回彈
                setState(() {
                  _isDragging = false;
                  _dragDistance = 0;
                });
              }
            },
            child: AnimatedContainer(
              duration:
                  _isDragging
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, _dragDistance, 0),
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: LoadingImage(
                          width: 50.w,
                          height: 50.h,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.error, color: Colors.white, size: 50),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // 返回按鈕
          Positioned(
            top: MediaQuery.of(context).padding.top + 10.h,
            left: 20.w,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: BackIconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                width: 40.w,
                height: 40.h,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
