import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/index.dart';

/// LoadingScreen
/// 顯示動畫：隨機人物從碗中生出來，上下移動，並有狀態文字
class LoadingScreen extends StatefulWidget {
  /// 狀態文字
  final String status;

  /// 狀態文字樣式
  final TextStyle? statusTextStyle;

  /// 動畫持續時間（毫秒）
  final int animationDuration;

  /// 可選：自訂人物圖片清單
  final List<String>? avatarList;

  /// 狀態檢查延遲（毫秒）
  final int statusCheckDelay;

  /// 完成後的回調函數
  final VoidCallback? onLoadingComplete;

  /// 淡出動畫持續時間（毫秒）
  final int fadeOutDuration;

  /// 完成後延長顯示時間（毫秒）
  final int displayDuration;

  const LoadingScreen({
    super.key,
    required this.status,
    this.statusTextStyle,
    this.animationDuration = 1800,
    this.avatarList,
    this.statusCheckDelay = 300,
    this.onLoadingComplete,
    this.fadeOutDuration = 200,
    this.displayDuration = 1500,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  static const List<String> _defaultAvatars = [
    'assets/images/avatar/no_bg/female_1.png',
    'assets/images/avatar/no_bg/female_2.png',
    'assets/images/avatar/no_bg/female_3.png',
    'assets/images/avatar/no_bg/female_4.png',
    'assets/images/avatar/no_bg/female_5.png',
    'assets/images/avatar/no_bg/female_6.png',
    'assets/images/avatar/no_bg/male_1.png',
    'assets/images/avatar/no_bg/male_2.png',
    'assets/images/avatar/no_bg/male_3.png',
    'assets/images/avatar/no_bg/male_4.png',
    'assets/images/avatar/no_bg/male_5.png',
    'assets/images/avatar/no_bg/male_6.png',
  ];

  late final List<String> _avatars;
  late AnimationController _controller;
  late Animation<double> _moveAnimation;
  String _currentAvatar = '';
  final Random _random = Random();

  // 淡出動畫控制
  double _opacity = 1.0;
  bool _isLoadingComplete = false;

  @override
  void initState() {
    super.initState();
    _avatars = widget.avatarList ?? _defaultAvatars;
    _pickRandomAvatar();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.animationDuration),
    );

    // 調整動畫流程：從下往上，再從上往下
    _moveAnimation = TweenSequence([
      // 從下往上 (-50 → 5)
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -50,
          end: 5,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      // 從上往下 (5 → -50)
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 5,
          end: -50,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);

    _controller.addStatusListener(_onAnimationStatus);
    _controller.forward();

    // 處理加載完成後的回調
    if (widget.onLoadingComplete != null) {
      // 在加載完成後執行淡出動畫
      Future.delayed(Duration(milliseconds: widget.displayDuration), () {
        if (mounted) {
          setState(() {
            _isLoadingComplete = true;
          });

          if (widget.onLoadingComplete != null) {
            widget.onLoadingComplete!();
          }
        }
      });
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // 當動畫完成時，此時人物處於最底部 (-50)，更換頭像
      _pickRandomAvatar();
      _controller.reset();
      _controller.forward();
    }
  }

  void _pickRandomAvatar() {
    setState(() {
      String newAvatar;
      do {
        newAvatar = _avatars[_random.nextInt(_avatars.length)];
      } while (newAvatar == _currentAvatar && _avatars.length > 1);
      _currentAvatar = newAvatar;
    });
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 初始化屏幕配置
    sizeConfig.init(context);

    return Scaffold(
      body: AnimatedOpacity(
        opacity: _opacity,
        duration: Duration(milliseconds: widget.fadeOutDuration),
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background/bg1.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 180.w,
                  height: 240.h,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 碗後景陰影
                      Positioned(
                        bottom: 10.h,
                        child: Image.asset(
                          'assets/images/frame/bowl-back.png',
                          width: 160.w,
                          color: Colors.black.withOpacity(0.3),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                      // 碗後景
                      Positioned(
                        bottom: 13.h,
                        child: Image.asset(
                          'assets/images/frame/bowl-back.png',
                          width: 160.w,
                        ),
                      ),
                      // 人物動畫
                      AnimatedBuilder(
                        animation: _moveAnimation,
                        builder: (context, child) {
                          return Positioned(
                            bottom: _moveAnimation.value + 73.h,
                            child: child!,
                          );
                        },
                        child: Image.asset(_currentAvatar, width: 90.w),
                      ),
                      // 碗前景陰影
                      Positioned(
                        bottom: 10.h,
                        child: Image.asset(
                          'assets/images/frame/bowl-front.png',
                          width: 160.w,
                          color: Colors.black.withOpacity(0.3),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                      // 碗前景
                      Positioned(
                        bottom: 13.h,
                        child: Image.asset(
                          'assets/images/frame/bowl-front.png',
                          width: 160.w,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
                Text(
                  widget.status,
                  style:
                      widget.statusTextStyle ??
                      TextStyle(
                        fontSize: 16.sp,
                        color: const Color(0xFF23456B),
                        fontFamily: 'OtsutomeFont',
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
