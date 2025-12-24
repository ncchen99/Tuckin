import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tuckin/components/components.dart';
import 'package:tuckin/utils/index.dart';
import 'package:tuckin/services/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 服務不可用頁面類型
enum ServiceUnavailableType {
  /// 服務暫停維護
  maintenance,

  /// 需要強制更新
  forceUpdate,
}

class ServiceUnavailablePage extends StatefulWidget {
  final ServiceUnavailableType type;
  final String? reason;
  final DateTime? estimatedRestoreTime;
  final String? updateUrl;
  final String? latestVersion;
  final String? currentVersion;
  final VoidCallback? onRetry;

  const ServiceUnavailablePage({
    super.key,
    required this.type,
    this.reason,
    this.estimatedRestoreTime,
    this.updateUrl,
    this.latestVersion,
    this.currentVersion,
    this.onRetry,
  });

  @override
  State<ServiceUnavailablePage> createState() => _ServiceUnavailablePageState();
}

class _ServiceUnavailablePageState extends State<ServiceUnavailablePage> {
  Timer? _timer;
  String _remainingTimeText = '';

  @override
  void initState() {
    super.initState();
    if (widget.type == ServiceUnavailableType.maintenance &&
        widget.estimatedRestoreTime != null) {
      _updateRemainingTime();
      // 每秒更新一次剩餘時間
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          _updateRemainingTime();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemainingTime() {
    if (widget.estimatedRestoreTime == null) {
      setState(() {
        _remainingTimeText = '';
      });
      return;
    }

    // 使用 TimeService 獲取當前時間
    final now = TimeService().now();
    final remaining = widget.estimatedRestoreTime!.difference(now);

    if (remaining.isNegative) {
      setState(() {
        _remainingTimeText = '已超過預計恢復時間';
      });
      return;
    }

    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    String timeText = '';
    if (days > 0) {
      timeText = '${days}天${hours}小時${minutes}分鐘';
    } else if (hours > 0) {
      timeText = '${hours}小時${minutes}分鐘';
    } else if (minutes > 0) {
      timeText = '${minutes}分鐘${seconds}秒';
    } else {
      timeText = '${seconds}秒';
    }

    setState(() {
      _remainingTimeText = '剩餘時間：$timeText';
    });
  }

  @override
  Widget build(BuildContext context) {
    // 計算適當的陰影偏移量
    final adaptiveShadowOffset = 4.h;

    return WillPopScope(
      onWillPop: () async {
        return false; // 禁用返回按鈕
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background/bg2.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 頂部導航欄
                HeaderBar(title: ''),

                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 100.h),

                        // 標題
                        Center(
                          child: Text(
                            _getTitle(),
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontFamily: 'OtsutomeFont',
                              color: const Color(0xFF23456B),
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        SizedBox(height: 25.h),

                        // 圖示
                        Center(
                          child: SizedBox(
                            width: 150.w,
                            height: 150.h,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // 底部陰影
                                Positioned(
                                  left: 0,
                                  top: adaptiveShadowOffset,
                                  child: Image.asset(
                                    widget.type ==
                                            ServiceUnavailableType.forceUpdate
                                        ? 'assets/images/icon/need_update.webp'
                                        : 'assets/images/icon/failed.webp',
                                    width: 150.w,
                                    height: 150.h,
                                    color: Colors.black.withOpacity(0.4),
                                    colorBlendMode: BlendMode.srcIn,
                                  ),
                                ),
                                // 主圖像
                                Image.asset(
                                  widget.type ==
                                          ServiceUnavailableType.forceUpdate
                                      ? 'assets/images/icon/need_update.webp'
                                      : 'assets/images/icon/failed.webp',
                                  width: 150.w,
                                  height: 150.h,
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 35.h),

                        // 描述文字
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: Text(
                              _getDescription(),
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontFamily: 'OtsutomeFont',
                                color: const Color(0xFF23456B),
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                        // 額外資訊（剩餘時間或版本資訊）
                        if (_getExtraInfo() != null) ...[
                          SizedBox(height: 20.h),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: Text(
                                _getExtraInfo()!,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontFamily: 'OtsutomeFont',
                                  color:
                                      widget.type ==
                                              ServiceUnavailableType.maintenance
                                          ? const Color(0xFF666666) // 淺灰色
                                          : const Color(
                                            0xFF23456B,
                                          ).withOpacity(0.8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 80.h),

                        // 按鈕
                        Center(child: _buildActionButton(context)),

                        const Spacer(),

                        SizedBox(height: 30.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    switch (widget.type) {
      case ServiceUnavailableType.maintenance:
        return '服務暫停中';
      case ServiceUnavailableType.forceUpdate:
        return '需要更新';
    }
  }

  String _getDescription() {
    switch (widget.type) {
      case ServiceUnavailableType.maintenance:
        if (widget.reason != null && widget.reason!.isNotEmpty) {
          return widget.reason!;
        }
        return '系統正在維護中，請稍後再試';
      case ServiceUnavailableType.forceUpdate:
        return 'APP 太舊了！ 更新後才能使用';
    }
  }

  String? _getExtraInfo() {
    switch (widget.type) {
      case ServiceUnavailableType.maintenance:
        if (_remainingTimeText.isNotEmpty) {
          return _remainingTimeText;
        }
        return null;
      case ServiceUnavailableType.forceUpdate:
        // 強制更新頁面不顯示版本號
        return null;
    }
  }

  Widget _buildActionButton(BuildContext context) {
    switch (widget.type) {
      case ServiceUnavailableType.maintenance:
        return ImageButton(
          text: '重新檢查',
          imagePath: 'assets/images/ui/button/blue_l.webp',
          width: 160.w,
          height: 70.h,
          onPressed: () {
            if (widget.onRetry != null) {
              widget.onRetry!();
            }
          },
        );
      case ServiceUnavailableType.forceUpdate:
        return ImageButton(
          text: '前往更新',
          imagePath: 'assets/images/ui/button/blue_l.webp',
          width: 160.w,
          height: 70.h,
          onPressed: () async {
            if (widget.updateUrl != null && widget.updateUrl!.isNotEmpty) {
              try {
                final uri = Uri.parse(widget.updateUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  debugPrint('無法開啟更新連結: ${widget.updateUrl}');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '無法開啟更新頁面',
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'OtsutomeFont',
                          ),
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('開啟更新連結失敗: $e');
              }
            }
          },
        );
    }
  }
}
