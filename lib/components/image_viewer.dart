import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/models/chat_message.dart';
import 'package:tuckin/services/services.dart';
import 'package:tuckin/utils/index.dart';

/// 全螢幕圖片查看器
/// 支援手勢縮放和滑動關閉
class ImageViewer extends StatefulWidget {
  final List<ChatMessage> imageMessages; // 所有圖片訊息列表
  final int initialIndex; // 初始顯示的圖片索引

  const ImageViewer({
    super.key,
    required this.imageMessages,
    required this.initialIndex,
  });

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  final ChatService _chatService = ChatService();
  late PageController _pageController;
  late int _currentIndex;
  double _dragDistance = 0;
  bool _isDragging = false;

  // 緩存圖片 URL 和微光顏色
  final Map<String, String> _imageUrlCache = {};
  final Map<String, Color> _glowColorCache = {};
  final Map<String, Future<String?>> _imageUrlFutures = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _preloadImages();
    _loadGlowColor();
    // 預加載相鄰圖片的微光顏色
    _preloadAdjacentGlowColors(_currentIndex);
  }

  /// 預加載所有圖片的 URL
  Future<void> _preloadImages() async {
    for (final message in widget.imageMessages) {
      if (message.imagePath != null &&
          !_imageUrlCache.containsKey(message.imagePath)) {
        final future = _chatService.getImageUrl(message.imagePath!);
        _imageUrlFutures[message.imagePath!] = future;
        future.then((url) {
          if (url != null && mounted) {
            _imageUrlCache[message.imagePath!] = url;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 載入當前圖片的微光顏色
  Future<void> _loadGlowColor() async {
    if (_currentIndex >= 0 && _currentIndex < widget.imageMessages.length) {
      final message = widget.imageMessages[_currentIndex];
      if (message.imagePath != null) {
        final imagePath = message.imagePath!;

        // 檢查緩存，如果已經有緩存則不需要重新計算
        if (_glowColorCache.containsKey(imagePath)) {
          return;
        }

        // 獲取圖片 URL（使用緩存或 future）
        String? imageUrl;
        if (_imageUrlCache.containsKey(imagePath)) {
          imageUrl = _imageUrlCache[imagePath];
        } else if (_imageUrlFutures.containsKey(imagePath)) {
          imageUrl = await _imageUrlFutures[imagePath];
        } else {
          imageUrl = await _chatService.getImageUrl(imagePath);
        }

        if (imageUrl != null) {
          await _calculateGlowColor(imageUrl, imagePath);
        }
      }
    }
  }

  /// 計算圖片的微光顏色（從圖片邊緣50像素提取平均顏色）
  Future<void> _calculateGlowColor(String imageUrl, String imagePath) async {
    // 檢查緩存
    if (_glowColorCache.containsKey(imagePath)) {
      // 如果已經有緩存，不需要重新計算
      return;
    }
    try {
      final imageProvider = NetworkImage(imageUrl);
      final completer = Completer<ImageInfo>();
      final stream = imageProvider.resolve(const ImageConfiguration());

      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) {
            completer.complete(info);
            stream.removeListener(listener);
          }
        },
        onError: (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error);
            stream.removeListener(listener);
          }
        },
      );

      stream.addListener(listener);
      final imageInfo = await completer.future;
      final image = imageInfo.image;

      // 從圖片邊緣50像素提取顏色
      final edgePixels = 50;
      final width = image.width;
      final height = image.height;

      // 讀取像素數據
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        throw Exception('無法讀取圖片像素數據');
      }

      int totalR = 0, totalG = 0, totalB = 0;
      int pixelCount = 0;

      // 採樣上邊緣和下邊緣的像素
      for (int y = 0; y < edgePixels && y < height; y++) {
        for (int x = 0; x < width; x++) {
          final index = (y * width + x) * 4;
          if (index + 3 < byteData.lengthInBytes) {
            totalR += byteData.getUint8(index).toInt();
            totalG += byteData.getUint8(index + 1).toInt();
            totalB += byteData.getUint8(index + 2).toInt();
            pixelCount++;
          }
        }
      }

      // 下邊緣
      for (int y = height - edgePixels; y < height; y++) {
        if (y >= 0) {
          for (int x = 0; x < width; x++) {
            final index = (y * width + x) * 4;
            if (index + 3 < byteData.lengthInBytes) {
              totalR += byteData.getUint8(index);
              totalG += byteData.getUint8(index + 1);
              totalB += byteData.getUint8(index + 2);
              pixelCount++;
            }
          }
        }
      }

      if (pixelCount > 0) {
        final avgR = totalR ~/ pixelCount;
        final avgG = totalG ~/ pixelCount;
        final avgB = totalB ~/ pixelCount;

        // 創建柔和的微光顏色（降低飽和度，與背景融合）
        final baseColor = Color.fromRGBO(avgR, avgG, avgB, 1.0);
        final glowColor = baseColor.withValues(alpha: 0.15);

        // 緩存微光顏色
        _glowColorCache[imagePath] = glowColor;

        // 如果是當前顯示的圖片，觸發 UI 更新
        if (mounted &&
            _currentIndex < widget.imageMessages.length &&
            widget.imageMessages[_currentIndex].imagePath == imagePath) {
          setState(() {});
        }
      } else {
        throw Exception('無法提取邊緣像素');
      }
    } catch (e) {
      // 如果計算失敗，使用默認的柔和顏色並緩存
      final defaultColor = Colors.white.withValues(alpha: 0.1);
      _glowColorCache[imagePath] = defaultColor;

      // 如果是當前顯示的圖片，觸發 UI 更新
      if (mounted &&
          _currentIndex < widget.imageMessages.length &&
          widget.imageMessages[_currentIndex].imagePath == imagePath) {
        setState(() {});
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _dragDistance = 0;
      _isDragging = false;
    });
    _loadGlowColor();
    // 預加載相鄰圖片的微光顏色
    _preloadAdjacentGlowColors(index);
  }

  /// 預加載相鄰圖片的微光顏色
  Future<void> _preloadAdjacentGlowColors(int currentIndex) async {
    // 預加載前一張和後一張圖片的微光顏色
    final indices = [currentIndex - 1, currentIndex + 1];
    for (final idx in indices) {
      if (idx >= 0 && idx < widget.imageMessages.length) {
        final message = widget.imageMessages[idx];
        if (message.imagePath != null &&
            !_glowColorCache.containsKey(message.imagePath)) {
          // 異步計算，不阻塞 UI
          _loadGlowColorForIndex(idx);
        }
      }
    }
  }

  /// 為指定索引的圖片載入微光顏色
  Future<void> _loadGlowColorForIndex(int index) async {
    if (index < 0 || index >= widget.imageMessages.length) return;

    final message = widget.imageMessages[index];
    if (message.imagePath == null) return;

    final imagePath = message.imagePath!;
    if (_glowColorCache.containsKey(imagePath)) return;

    String? imageUrl;
    if (_imageUrlCache.containsKey(imagePath)) {
      imageUrl = _imageUrlCache[imagePath];
    } else if (_imageUrlFutures.containsKey(imagePath)) {
      imageUrl = await _imageUrlFutures[imagePath];
    } else {
      imageUrl = await _chatService.getImageUrl(imagePath);
    }

    if (imageUrl != null) {
      await _calculateGlowColor(imageUrl, imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 計算背景透明度（拖動時逐漸變透明）
    final backgroundOpacity =
        _isDragging ? (1 - (_dragDistance.abs() / 400)).clamp(0.0, 1.0) : 0.7;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 半透明模糊背景 - 需要填滿整個畫面
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withValues(alpha: backgroundOpacity),
              ),
            ),
          ),

          // 圖片區域 - 使用 PageView 支援左右滑動
          GestureDetector(
            onTap: () {
              // 點擊空白處關閉
              Navigator.of(context).pop();
            },
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
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: widget.imageMessages.length,
                itemBuilder: (context, index) {
                  final message = widget.imageMessages[index];
                  return GestureDetector(
                    onTap: () {
                      // 阻止點擊事件冒泡，避免關閉查看器
                    },
                    child: _buildImagePage(message),
                  );
                },
              ),
            ),
          ),

          // Header - 固定在頂部，類似 chat_page 的樣式
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                child: Row(
                  children: [
                    // 左側返回按鈕
                    BackIconButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      width: 35.w,
                      height: 35.h,
                    ),

                    // 中央顯示發送者名稱 (上方增加一些 padding 讓文字垂直置中)
                    Expanded(
                      child: Center(
                        child:
                            _currentIndex < widget.imageMessages.length &&
                                    widget
                                            .imageMessages[_currentIndex]
                                            .senderNickname !=
                                        null
                                ? Padding(
                                  padding: EdgeInsets.only(
                                    top: 6.h,
                                  ), // 加上一點上方 padding
                                  child: Text(
                                    widget
                                        .imageMessages[_currentIndex]
                                        .senderNickname!,
                                    style: TextStyle(
                                      fontSize: 20.sp,
                                      fontFamily: 'OtsutomeFont',
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withAlpha(
                                            (0.5 * 255).toInt(),
                                          ),
                                          blurRadius: 4,
                                          offset: Offset(0, 2.h),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                    ),

                    // 右側佔位（保持對稱）
                    SizedBox(width: 35.w),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 建構單個圖片頁面
  Widget _buildImagePage(ChatMessage message) {
    if (message.imagePath == null) {
      return const Center(
        child: Icon(Icons.error, color: Colors.white, size: 50),
      );
    }

    final imagePath = message.imagePath!;

    // 獲取該圖片的微光顏色（如果有的話）
    final glowColor = _glowColorCache[imagePath];

    // 如果已經有緩存的 URL，直接使用
    if (_imageUrlCache.containsKey(imagePath)) {
      return _buildImageContent(_imageUrlCache[imagePath]!, glowColor);
    }

    // 如果有正在進行的 future，使用它
    if (_imageUrlFutures.containsKey(imagePath)) {
      return FutureBuilder<String?>(
        future: _imageUrlFutures[imagePath],
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 不顯示 loading，直接顯示空白或使用緩存的圖片
            return const SizedBox.shrink();
          }

          if (snapshot.hasData && snapshot.data != null) {
            final imageUrl = snapshot.data!;
            _imageUrlCache[imagePath] = imageUrl;
            return _buildImageContent(imageUrl, glowColor);
          }

          return const Center(
            child: Icon(Icons.error, color: Colors.white, size: 50),
          );
        },
      );
    }

    // 如果都沒有，創建新的 future
    final future = _chatService.getImageUrl(imagePath);
    _imageUrlFutures[imagePath] = future;

    return FutureBuilder<String?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasData && snapshot.data != null) {
          final imageUrl = snapshot.data!;
          _imageUrlCache[imagePath] = imageUrl;
          return _buildImageContent(imageUrl, glowColor);
        }

        return const Center(
          child: Icon(Icons.error, color: Colors.white, size: 50),
        );
      },
    );
  }

  /// 建構圖片內容
  Widget _buildImageContent(String imageUrl, Color? glowColor) {
    // 左右留白
    final horizontalPadding = 24.w;
    // 上下留白（上方考慮 header bar 的空間）
    final topPadding = 100.h; // 為 header bar 留出空間
    final bottomPadding = 40.h;
    // 圓角半徑
    final borderRadius = 16.r;

    // 使用計算的微光顏色，如果沒有則使用默認的柔和白色
    final effectiveGlowColor = glowColor ?? Colors.white.withValues(alpha: 0.2);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          top: topPadding,
          bottom: bottomPadding,
        ),
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                // 四周整體微光（主要效果）
                BoxShadow(
                  color: effectiveGlowColor.withValues(alpha: 0.7),
                  blurRadius: 60,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: InteractiveViewer(
                minScale: 1.0, // 禁用縮放
                maxScale: 1.0, // 禁用縮放
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  // 使用緩存，避免重新加載
                  cacheWidth: null,
                  cacheHeight: null,
                  loadingBuilder: (context, child, loadingProgress) {
                    // 如果圖片已經在緩存中，直接顯示
                    if (loadingProgress == null) return child;
                    // 不顯示 loading 動畫，避免閃爍
                    return child;
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
      ),
    );
  }
}
