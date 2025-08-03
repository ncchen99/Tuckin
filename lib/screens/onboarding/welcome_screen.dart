import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../components/components.dart';
import '../../utils/index.dart'; // 導入自適應佈局工具
import 'package:video_player/video_player.dart';
import 'dart:math' as math;
import 'dart:math';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 3;

  // 添加導航服務
  final NavigationService _navigationService = NavigationService();

  // 添加影片控制器
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  // 添加動畫控制器
  late AnimationController _animationController;

  // 食物動畫相關變量
  final List<String> _dishPaths = [
    'assets/images/dish/chinese.webp',
    'assets/images/dish/japanese.webp',
    'assets/images/dish/korean.webp',
    'assets/images/dish/taiwanese.webp',
    'assets/images/dish/italian.webp',
    'assets/images/dish/thai.webp',
    'assets/images/dish/indian.webp',
    'assets/images/dish/burger.webp',
    'assets/images/dish/pizza.webp',
    'assets/images/dish/japanese_curry.webp',
    'assets/images/dish/mexican.webp',
    'assets/images/dish/vietnamese.webp',
    'assets/images/dish/vegetarian.webp',
    'assets/images/dish/hongkong.webp',
    'assets/images/dish/barbecue.webp',
    'assets/images/dish/hotpot.webp',
  ];
  final List<Offset> _dishPositions = [];
  final List<double> _dishScales = [];
  final List<double> _dishRotations = [];

  // 新的介紹文字
  final List<String> _introTexts = [
    '每一頓飯，都是一個故事的開端；\n每一次相聚，都是友誼的起點！',
    '智能配對，連結志同道合的夥伴\n擁抱與共鳴的瞬間！',
    '一起出發尋找美食\n創造難忘回憶！',
  ];

  // 黏土人物路徑
  final List<String> _figuresPaths = [
    'assets/images/avatar/no_bg/female_1.png',
    'assets/images/avatar/no_bg/male_1.png',
    'assets/images/avatar/no_bg/female_2.png',
    'assets/images/avatar/no_bg/male_2.png',
    'assets/images/avatar/no_bg/female_3.png',
    'assets/images/avatar/no_bg/male_3.png',
    'assets/images/avatar/no_bg/female_4.png',
    'assets/images/avatar/no_bg/male_4.png',
    'assets/images/avatar/no_bg/female_5.png',
    'assets/images/avatar/no_bg/male_5.png',
    'assets/images/avatar/no_bg/female_6.png',
    'assets/images/avatar/no_bg/male_6.png',
  ];

  // 黏土人物初始位置 (50個人物)
  final List<Offset> _figureInitialPositions = [];
  final List<Offset> _figureFinalPositions = [];
  final int _virtualFigureCount = 50; // 增加到50個虛擬人物

  // 添加人物佈局相關變數，使其能在不同方法間共享
  final List<int> _rowGrids = [15, 10, 7, 4, 4]; // 由上到下的格子數
  List<double> _rowStartY = [];
  List<double> _rowHeights = [];

  // 宣告動畫變數
  late Animation<double> _figureAnimation;
  late Animation<double> _logoAnimation;
  late Animation<double> _zoomAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化影片播放器
    _videoController = VideoPlayerController.asset(
        'assets/video/intro.mp4',
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      )
      ..initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController.play();
        _videoController.setLooping(false);
      });

    // 初始化動畫控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // 縮短動畫時間
    );

    // 使用 CurvedAnimation 優化動畫曲線
    _figureAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
      ),
    );

    _zoomAnimation = Tween<double>(begin: 1.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // 初始化食物動畫數據
    _initDishAnimationData();

    // 初始化人物動畫數據
    _initFigureAnimationData();
  }

  void _initDishAnimationData() {
    // 清空數組以確保不會有舊數據
    _dishPositions.clear();
    _dishScales.clear();
    _dishRotations.clear();

    // 為每個食物生成隨機的初始位置、縮放和旋轉
    final random = math.Random();
    for (int i = 0; i < _dishPaths.length; i++) {
      // 使用正規化座標 (-1.0 到 1.0 的範圍)
      double normalizedDx, normalizedDy;

      // 決定從哪個方向進入 (使用正規化座標)
      int direction = random.nextInt(4); // 0:上, 1:右, 2:下, 3:左
      switch (direction) {
        case 0: // 上方
          normalizedDx = random.nextDouble() * 2.0 - 1.0; // -1.0 到 1.0
          normalizedDy = -1.2; // 稍微超出邊界
          break;
        case 1: // 右方
          normalizedDx = 1.2; // 稍微超出邊界
          normalizedDy = random.nextDouble() * 2.0 - 1.0; // -1.0 到 1.0
          break;
        case 2: // 下方
          normalizedDx = random.nextDouble() * 2.0 - 1.0; // -1.0 到 1.0
          normalizedDy = 1.2; // 稍微超出邊界
          break;
        case 3: // 左方
        default:
          normalizedDx = -1.2; // 稍微超出邊界
          normalizedDy = random.nextDouble() * 2.0 - 1.0; // -1.0 到 1.0
          break;
      }

      _dishPositions.add(Offset(normalizedDx, normalizedDy));

      // 隨機縮放 - 增加變化 (使用相對尺寸係數)
      _dishScales.add(1 + random.nextDouble() * 0.4); // 放大並增加變化

      // 隨機旋轉 (0-360度)
      _dishRotations.add(random.nextDouble() * 2 * math.pi);
    }

    // 確保數據長度一致
    assert(_dishPositions.length == _dishPaths.length);
    assert(_dishScales.length == _dishPaths.length);
    assert(_dishRotations.length == _dishPaths.length);
  }

  void _initFigureAnimationData() {
    // 為50個人物生成合適的起始和結束位置
    final random = math.Random();

    // 清空數組以確保不會有舊數據
    _figureInitialPositions.clear();
    _figureFinalPositions.clear();
    _rowStartY.clear();
    _rowHeights.clear();

    // 使用正規化座標系統，範圍從-1到1，中心點是(0,0)
    final double canvasHalfNormalized = 1.0;

    // 定義5個橫排的格子數量 (已在類中定義)
    final int totalGrids = _rowGrids.reduce((a, b) => a + b); // 總格子數

    // 生成所有可能的格子位置
    List<Offset> gridPositions = [];

    // 使用漸進式行高：上方行較窄，下方行較寬
    // 計算行高權重，使得上方行高低，下方行高高
    List<double> rowHeightWeights = [];
    for (int i = 0; i < _rowGrids.length; i++) {
      // 指數增長的權重，使得上方行高低，下方行高高
      rowHeightWeights.add(pow(1.5, i).toDouble());
    }

    // 計算權重總和
    final double totalWeight = rowHeightWeights.reduce((a, b) => a + b);

    // 定義Y座標的有效顯示範圍 (正規化座標)
    final double yStart = 0.1; // 頂部位置（正規化）
    final double yEnd = 0.65; // 底部位置（正規化）
    final double yRange = yEnd - yStart; // 總可用Y軸範圍

    // 計算每一行的實際高度
    _rowHeights =
        rowHeightWeights
            .map((weight) => yRange * (weight / totalWeight))
            .toList();

    // 計算每行的起始Y位置 - 從yStart開始
    _rowStartY = [yStart];
    for (int i = 1; i < _rowGrids.length; i++) {
      _rowStartY.add(_rowStartY[i - 1] + _rowHeights[i - 1]);
    }

    // 將倒數第二行下移少許
    _rowStartY[3] += 0.1;

    // 從上到下生成每一行的格子位置
    for (int rowIndex = 0; rowIndex < _rowGrids.length; rowIndex++) {
      final int gridsInRow = _rowGrids[rowIndex];

      // 計算行的Y坐標（從上往下）
      final double rowY = _rowStartY[rowIndex] + _rowHeights[rowIndex] / 2;

      // 計算每個格子的寬度（正規化）
      final double gridWidth = 2.0 / gridsInRow; // 正規化寬度

      // 在這一行中生成每個格子的位置
      for (int colIndex = 0; colIndex < gridsInRow; colIndex++) {
        // 計算格子的X坐標（正規化）
        double gridX = -1.0 - 0.1 + (gridWidth + 0.05) * (colIndex + 0.5);
        if (rowIndex == 4) gridX -= 0.1;
        if (rowIndex == 3) gridX += 0.15;
        // 添加格子位置（正規化座標）
        gridPositions.add(Offset(gridX, rowY));
      }
    }

    // 打亂格子位置順序，以便隨機分配
    gridPositions.shuffle(random);

    // 確保我們不會生成超過格子數量的人物
    final actualFigureCount = math.min(_virtualFigureCount, totalGrids);

    for (int i = 0; i < actualFigureCount; i++) {
      // 起始位置在底部之外（正規化座標）
      double startX = random.nextDouble() * 2.0 - 1.0; // -1.0 到 1.0
      double startY = 1.2 + random.nextDouble() * 0.3; // 底部之外（正規化）
      _figureInitialPositions.add(Offset(startX, startY));

      // 將人物分配到一個格子位置，加上一些隨機偏移
      Offset gridPos = gridPositions[i];

      // 更小的隨機偏移，使排列更整齊（正規化）
      double offsetX = (random.nextDouble() * 0.003 - 0.0015); // 小幅度隨機偏移
      double offsetY = (random.nextDouble() * 0.003 - 0.0015);

      double finalX = gridPos.dx + offsetX;
      double finalY = gridPos.dy + offsetY;

      // 確保Y座標在有效範圍內（正規化）
      finalY = finalY.clamp(yStart, yEnd);

      _figureFinalPositions.add(Offset(finalX, finalY));
    }

    // 確保兩個數組長度一致
    assert(_figureInitialPositions.length == actualFigureCount);
    assert(_figureFinalPositions.length == actualFigureCount);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 轉到下一頁
  void _goToNextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      // 使用導航服務導航到登入頁面
      _navigationService.navigateToLoginPage(context);
    }
  }

  void _onPageChanged(int page) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentPage = page;
    });

    // 重置並開始動畫
    if (_animationController.status == AnimationStatus.completed) {
      _animationController.reset();
    }

    if (_currentPage > 0) {
      // 確保動畫控制器開始運行
      if (_animationController.status != AnimationStatus.forward) {
        _animationController.forward();
      }
    }

    // 如果是第一頁且視頻已經結束，重新播放一次
    if (_currentPage == 0 &&
        _isVideoInitialized &&
        !_videoController.value.isPlaying) {
      _videoController.seekTo(Duration.zero);
      _videoController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用擴展方法替代 MediaQuery
    final screenWidth = context.screenWidth;
    final screenHeight = context.screenHeight;

    // 計算方形容器的大小（使用較小的值以確保正方形）
    final squareSize = math.min(screenWidth, screenHeight * 0.6);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background/bg2.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          // 使用Stack佈局，底層是PageView，頂層是固定的頁面指示器
          child: Stack(
            children: [
              // 第一層：PageView 包含方形區域、說明文字和按鈕
              PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  // 第一頁完整內容
                  _buildPageContent(0, _buildVideoSquare(squareSize)),
                  // 第二頁完整內容
                  _buildPageContent(1, _buildFiguresAnimation(squareSize)),
                  // 第三頁完整內容
                  _buildPageContent(2, _buildFoodAnimation(squareSize)),
                ],
              ),

              // 第二層：固定位置的頁面指示器
              Positioned(
                left: 0,
                right: 0,
                bottom: 30.h,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30.w),
                  child: ProgressDotsIndicator(
                    totalSteps: _totalPages,
                    currentStep: _currentPage + 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 構建每個頁面的內容（方形區域、說明文字和按鈕）
  Widget _buildPageContent(int pageIndex, Widget topContent) {
    return Column(
      children: [
        // 主要內容區域 - 確保正方形
        AspectRatio(
          aspectRatio: 1.0, // 強制1:1的比例
          child: Padding(
            padding: EdgeInsets.all(25.r), // 使用自適應圓角
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 使用LayoutBuilder獲取實際可用空間
                final actualSize = math.max(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return SizedBox(
                  width: actualSize,
                  height: actualSize,
                  child: topContent,
                );
              },
            ),
          ),
        ),

        // 底部說明區域
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 30.w), // 使用自適應寬度
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 說明文字
                Expanded(
                  child: Center(
                    child: Text(
                      _introTexts[pageIndex],
                      style: TextStyle(
                        fontSize: 20.sp, // 使用自適應字體大小
                        color: const Color(0xFF23456B),
                        fontFamily: 'OtsutomeFont',
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // 下一步按鈕
                Padding(
                  padding: EdgeInsets.only(bottom: 85.h), // 調整底部間距為頁面指示器留出空間
                  child: ImageButton(
                    imagePath: 'assets/images/ui/button/red_m.webp',
                    text: pageIndex < _totalPages - 1 ? '下一步' : '開始使用',
                    width: 160.w, // 使用自適應寬度
                    height: 70.h, // 使用自適應高度
                    onPressed: _goToNextPage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 新建方形影片播放區域
  Widget _buildVideoSquare(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.r), // 使用自適應圓角
      ),
      clipBehavior: Clip.antiAlias, // 使用抗鋸齒裁剪方式
      child:
          _isVideoInitialized
              ? FittedBox(
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.5),
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              )
              : const Center(child: CircularProgressIndicator()),
    );
  }

  // 第二頁：人物動畫
  Widget _buildFiguresAnimation(double size) {
    // 使用預先構建方法，確保圓角從一開始就被應用
    return PhysicalModel(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(25.r),
      clipBehavior: Clip.antiAlias, // 使用抗鋸齒裁剪
      elevation: 0, // 無陰影
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          image: DecorationImage(
            image: AssetImage('assets/images/background/bg3.jpg'),
            fit: BoxFit.cover,
            opacity: 0.2, // 降低不透明度，使背景稍微淡化
          ),
        ),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // 放置所有人物 - 先將數組按照Y軸排序，讓"靠前"的人物在上面
                ..._generateCharacterWidgets(size),
              ],
            );
          },
        ),
      ),
    );
  }

  // 生成排序過的人物小部件列表
  List<Widget> _generateCharacterWidgets(double size) {
    // 創建一個臨時數組來保存人物數據
    List<Map<String, dynamic>> characterData = [];

    final figureCount = _figureFinalPositions.length;

    // 為每一行建立獨立的人物索引列表
    List<List<int>> rowFigureIndices = [];

    // 初始化每行的人物索引列表
    for (int rowIndex = 0; rowIndex < _rowGrids.length; rowIndex++) {
      // 為每一行創建所有可能人物的索引，並打亂順序
      List<int> availableFigures = List.generate(
        _figuresPaths.length,
        (index) => index,
      )..shuffle(Random(rowIndex)); // 使用行索引作為種子確保每次運行結果一致但不同行間不同

      rowFigureIndices.add(availableFigures);
    }

    // 跟踪每一行使用的人物索引
    List<int> rowCurrentIndex = List.generate(_rowGrids.length, (_) => 0);

    for (int i = 0; i < figureCount; i++) {
      // 獲取正規化的最終位置
      final Offset normalizedFinalPos = _figureFinalPositions[i];

      // 計算到中心的距離（仍使用正規化座標）
      final distanceFromCenter = math.sqrt(
        normalizedFinalPos.dx * normalizedFinalPos.dx +
            normalizedFinalPos.dy * normalizedFinalPos.dy,
      );

      // 調整深度計算，讓Y值更大的人物（底部）更大
      double depthFactor;
      // 將Y值從正規化座標(-1到1)進一步歸一化到0-1範圍
      double normalizedY = (normalizedFinalPos.dy + 1.0) / 2.0; // -1到1轉換為0-1

      // 使用更溫和的二次曲線，減小上下層差異
      double baseSize = 0.6 + (normalizedY * normalizedY * 1.1);

      // 適當增加距離中心的縮小效果（也基於正規化距離）
      double distanceFactor = (distanceFromCenter / 1.5).clamp(0.0, 0.02);

      depthFactor = baseSize - distanceFactor;

      // 確保最小值和最大值在合理範圍
      depthFactor = depthFactor.clamp(0.6, 2);

      // 計算動畫延遲 - 根據行數計算，讓越靠近底部的行越先出現
      double baseDelay = normalizedY * 0.4; // 使用正規化Y值計算延遲
      double randomOffset = (i % 5) * 0.02; // 增加一些隨機性
      double delayTime = (baseDelay + randomOffset).clamp(0.0, 0.5);

      // 確定人物所在行
      int personRow = -1;
      for (int rowIndex = 0; rowIndex < _rowGrids.length; rowIndex++) {
        if (rowIndex == 0 &&
            normalizedFinalPos.dy <= _rowStartY[0] + _rowHeights[0]) {
          personRow = 0;
          break;
        } else if (rowIndex > 0 &&
            normalizedFinalPos.dy >
                _rowStartY[rowIndex - 1] + _rowHeights[rowIndex - 1] &&
            normalizedFinalPos.dy <=
                _rowStartY[rowIndex] + _rowHeights[rowIndex]) {
          personRow = rowIndex;
          break;
        }
      }

      // 如果沒找到對應行，預設為最底行
      if (personRow == -1) {
        personRow = _rowGrids.length - 1;
      }

      // 獲取此行的下一個人物索引
      int rowIndex = rowCurrentIndex[personRow];
      int figureIndex =
          rowFigureIndices[personRow][rowIndex % _figuresPaths.length];

      // 更新此行的索引
      rowCurrentIndex[personRow]++;

      // 計算透明度 - 上方的人物半透明
      double baseOpacity = normalizedFinalPos.dy < -0.3 ? 0.7 : 1.0;

      characterData.add({
        'index': i,
        'path': _figuresPaths[figureIndex], // 確保索引不會超出範圍
        'initialPos': _figureInitialPositions[i],
        'finalPos': normalizedFinalPos,
        'depth': depthFactor,
        'delay': delayTime,
        'distance': distanceFromCenter,
        'yPos': normalizedFinalPos.dy, // 記錄Y座標，用於Z軸排序
        'baseOpacity': baseOpacity, // 基礎透明度
      });
    }

    // 根據Y座標排序，Y值越大的越靠前(先渲染)，形成前後層次感
    characterData.sort((a, b) => a['yPos'].compareTo(b['yPos']));

    // 現在按照排序後的順序生成Widget
    return characterData.map((data) {
      double t =
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              data['delay'],
              data['delay'] + 0.5,
              curve: Curves.elasticOut,
            ),
          ).value;

      // 獲取正規化位置
      Offset normalizedInitialPos = data['initialPos'];
      Offset normalizedFinalPos = data['finalPos'];

      // 計算當前正規化位置
      final normalizedCurrentPos =
          Offset.lerp(normalizedInitialPos, normalizedFinalPos, t)!;

      // 將正規化位置轉換為實際畫面上的位置
      final currentPos = Offset(
        normalizedCurrentPos.dx * size / 2,
        normalizedCurrentPos.dy * size / 2,
      );

      // 計算縮放比例，更大的對比
      final scale = Tween<double>(begin: 0.0, end: data['depth']).evaluate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            data['delay'],
            data['delay'] + 0.5,
            curve: Curves.easeOutBack,
          ),
        ),
      );

      // 透明度動畫，根據位置調整基礎透明度
      final opacity = Tween<double>(
        begin: 0.0,
        end: data['baseOpacity'],
      ).evaluate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            data['delay'],
            data['delay'] + 0.3,
            curve: Curves.easeOut,
          ),
        ),
      );

      // 計算尺寸 - 使用相對於容器的比例
      final baseSize = size * 0.21; // 相對於容器的百分比
      final imageSize = baseSize * data['depth'];

      // 定位人物 - 從正規化座標轉換為實際座標
      return Positioned(
        left: size / 2 + currentPos.dx - (imageSize / 2),
        top: size / 2 + currentPos.dy - (imageSize / 2),
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Image.asset(
              data['path'],
              width: imageSize,
              height: imageSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }).toList();
  }

  // 第三頁：食物動畫
  Widget _buildFoodAnimation(double size) {
    // 使用與人物動畫相同的方式處理圓角問題
    return PhysicalModel(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(25.r),
      clipBehavior: Clip.antiAlias, // 使用抗鋸齒裁剪
      elevation: 0, // 無陰影
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          image: DecorationImage(
            image: AssetImage('assets/images/background/bg4.jpg'),
            fit: BoxFit.cover,
            opacity: 0.6, // 降低不透明度以保持食物清晰可見
          ),
        ),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            // 相機縮放效果
            final zoomScale = Tween<double>(begin: 1.0, end: 1.2).evaluate(
              CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
              ),
            );

            return Transform.scale(
              scale: zoomScale,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF23456B,
                  ).withOpacity(0.15), // 降低背景色的不透明度
                ),
                child: Stack(
                  // 確保Stack以中心為原點
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                    // 從四面八方飛入的菜品 - 16宮格佈局
                    ..._buildFoodWidgets(size),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 將食物小部件生成邏輯拆分成獨立的方法，方便管理
  List<Widget> _buildFoodWidgets(double size) {
    // 創建一個臨時數組來保存食物數據
    List<Map<String, dynamic>> foodData = [];

    for (int index = 0; index < math.min(16, _dishPaths.length); index++) {
      String dishPath = _dishPaths[index];
      final random = math.Random(index + 100);

      // 計算網格位置 (使用正規化坐標)
      final gridSize = 4; // 4x4網格
      final normalizedCellSize = 2.0 / gridSize - 0.08; // 正規化格子大小
      final row = index ~/ gridSize; // 0, 1, 2, 3
      final col = index % gridSize; // 0, 1, 2, 3

      // 計算網格中心坐標，加入小幅隨機偏移 (使用正規化坐標)
      final normalizedOffsetX = (random.nextDouble() * 0.01 - 0.005);
      final normalizedOffsetY = (random.nextDouble() * 0.01 - 0.005);

      // 計算相對於中心的正規化坐標 (範圍為-1到1)
      final halfGrid = (gridSize - 1) / 2;
      final normalizedRelativeX =
          (col - halfGrid) * normalizedCellSize + normalizedOffsetX - 0.1;
      final normalizedRelativeY =
          (row - halfGrid) * (normalizedCellSize - 0.05) +
          normalizedOffsetY -
          0.15;

      // 起始位置設置在四個方向之外 (使用正規化坐標)
      double normalizedStartX, normalizedStartY;
      int direction = index % 4; // 0:上, 1:右, 2:下, 3:左
      switch (direction) {
        case 0: // 上方
          normalizedStartX = normalizedRelativeX * 0.5;
          normalizedStartY = -1.2; // 正規化座標，超出頂部
          break;
        case 1: // 右方
          normalizedStartX = 1.2; // 正規化座標，超出右側
          normalizedStartY = normalizedRelativeY * 0.5;
          break;
        case 2: // 下方
          normalizedStartX = normalizedRelativeX * 0.5;
          normalizedStartY = 1.2; // 正規化座標，超出底部
          break;
        case 3: // 左方
        default:
          normalizedStartX = -1.2; // 正規化座標，超出左側
          normalizedStartY = normalizedRelativeY * 0.5;
          break;
      }

      // 隨機分配Z軸位置 (用於決定渲染順序和大小)
      final zPosition = random.nextDouble();

      // 添加到數據集合 (使用正規化坐標)
      foodData.add({
        'index': index,
        'path': dishPath,
        'startPos': Offset(normalizedStartX, normalizedStartY), // 正規化起始位置
        'finalPos': Offset(normalizedRelativeX, normalizedRelativeY), // 正規化最終位置
        'zPosition': zPosition, // Z軸位置
        'direction': direction,
        'random': random, // 保存隨機數生成器以保持一致性
      });
    }

    // 生成小部件
    return foodData.map((data) {
        final random = data['random'] as math.Random;
        final index = data['index'] as int;
        final dishPath = data['path'] as String;
        final zPosition = data['zPosition'] as double;

        // 動畫時間 - 錯開起始時間
        final t =
            CurvedAnimation(
              parent: _animationController,
              curve: Interval(
                0.05 * (index % 8), // 順序錯開起始時間
                0.5 + 0.05 * (index % 8),
                curve: Curves.easeOutQuad,
              ),
            ).value;

        // 計算當前正規化位置
        final normalizedCurrentPos =
            Offset.lerp(
              data['startPos'] as Offset,
              data['finalPos'] as Offset,
              t,
            )!;

        // 將正規化位置轉換為實際像素位置
        final currentPos = Offset(
          normalizedCurrentPos.dx * size / 2,
          normalizedCurrentPos.dy * size / 2,
        );

        // 旋轉動畫 - 隨機旋轉角度
        final initialRotation = random.nextDouble() * 2 * math.pi;
        final endRotation =
            (random.nextDouble() - 0.5) * math.pi / 6; // 隨機小角度旋轉
        final currentRotation = Tween<double>(
          begin: initialRotation,
          end: endRotation,
        ).evaluate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
          ),
        );

        // 縮放動畫 - 依據Z軸位置調整大小
        // Z軸位置影響大小，越前面(z值越大)的食物越大
        final zSizeFactor = 0.9 + zPosition * 0.3; // 調小範圍，避免過大 (0.8-1.2)

        // 根據Z位置調整基礎大小，前方食物略小一些以避免被截斷
        final baseSizeMultiplier =
            zPosition > 0.7 ? 1.0 : (1.0 + (index % 4) * 0.005);
        final sizeMultiplier = baseSizeMultiplier * zSizeFactor - 0.1;

        final currentScale = Tween<double>(
          begin: 0.3,
          end: sizeMultiplier,
        ).evaluate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutQuad),
          ),
        );

        // 透明度動畫
        final opacity = Tween<double>(begin: 0.0, end: 1.0).evaluate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(0.05 * (index % 8), 0.4, curve: Curves.easeIn),
          ),
        );

        // 陰影效果
        final shadowOffset = size * 0.01; // 相對於容器大小的陰影偏移
        final shadowOpacity = 0.4 + (zPosition * 0.1); // 前面的食物陰影更明顯

        // 基於Z位置調整食物位置，避免前方食物被截斷
        final centeringOffset = zPosition > 0.7 ? size * 0.02 : 0.0;

        // 調整的基礎尺寸 - 使用相對於容器的比例
        final baseSize = size * 0.3; // 相對於容器的30%
        // 根據Z軸調整的最終尺寸
        final foodSize = baseSize * currentScale;

        return Positioned(
          left: size / 2 + currentPos.dx - (foodSize / 2) + centeringOffset,
          top: size / 2 + currentPos.dy - (foodSize / 2) + centeringOffset,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: currentRotation,
              child: Stack(
                clipBehavior: Clip.none, // 允許內容超出邊界
                children: [
                  // 陰影層
                  if (t > 0.2) // 只有當動畫進行到一定程度才顯示陰影
                    Positioned(
                      left: shadowOffset,
                      top: shadowOffset,
                      child: Image.asset(
                        dishPath,
                        width: foodSize,
                        height: foodSize,
                        fit: BoxFit.contain,
                        color: Colors.black.withOpacity(shadowOpacity),
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                  // 主圖層
                  Image.asset(
                    dishPath,
                    width: foodSize,
                    height: foodSize,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList()
      ..sort((a, b) {
        // 根據位置排序，讓Y值越大的食物越靠前顯示
        final aTop = (a).top ?? 0.0;
        final bTop = (b).top ?? 0.0;
        return aTop.compareTo(bTop);
      });
  }
}
