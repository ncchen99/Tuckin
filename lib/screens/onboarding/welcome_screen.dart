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
    'assets/images/dish/chinese.png',
    'assets/images/dish/japanese.png',
    'assets/images/dish/korean.png',
    'assets/images/dish/taiwanese.png',
    'assets/images/dish/italian.png',
    'assets/images/dish/thai.png',
    'assets/images/dish/indian.png',
    'assets/images/dish/burger.png',
    'assets/images/dish/pizza.png',
    'assets/images/dish/japanese_curry.png',
    'assets/images/dish/mexican.png',
    'assets/images/dish/vietnamese.png',
    'assets/images/dish/vegetarian.png',
    'assets/images/dish/hongkong.png',
    'assets/images/dish/barbecue.png',
    'assets/images/dish/hotpot.png',
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
  final List<int> _rowGrids = [15, 10, 7, 5, 4]; // 由上到下的格子數
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
    _videoController = VideoPlayerController.asset('assets/video/intro.mp4')
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
      // 隨機位置 (從四面八方進入)
      double dx, dy;

      // 決定從哪個方向進入
      int direction = random.nextInt(4); // 0:上, 1:右, 2:下, 3:左
      switch (direction) {
        case 0: // 上方
          dx = random.nextDouble() * 400 - 200; // 擴大範圍
          dy = -200; // 擴大範圍
          break;
        case 1: // 右方
          dx = 200; // 擴大範圍
          dy = random.nextDouble() * 400 - 200; // 擴大範圍
          break;
        case 2: // 下方
          dx = random.nextDouble() * 400 - 200; // 擴大範圍
          dy = 200; // 擴大範圍
          break;
        case 3: // 左方
        default:
          dx = -200; // 擴大範圍
          dy = random.nextDouble() * 400 - 200; // 擴大範圍
          break;
      }

      _dishPositions.add(Offset(dx, dy));

      // 隨機縮放 - 增加變化
      _dishScales.add(0.6 + random.nextDouble() * 0.8); // 放大並增加變化

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

    // 定義正確的畫布邊界：為了確保出血效果正確
    final double canvasHalfSize = 150.0; // 假設畫布大小為300x300，中心點(0,0)

    // 定義5個橫排的格子數量
    // _rowGrids = [15, 10, 7, 5, 4]; // 由上到下的格子數 (已在類中定義)
    final int totalGrids = _rowGrids.reduce((a, b) => a + b); // 總格子數

    // 生成所有可能的格子位置
    List<Offset> gridPositions = [];

    // 計算每一行的高度
    final double totalHeight = canvasHalfSize * 2;

    // 使用漸進式行高：上方行較窄，下方行較寬
    // 計算行高權重，使得上方行高低，下方行高高
    List<double> rowHeightWeights = [];
    for (int i = 0; i < _rowGrids.length; i++) {
      // 指數增長的權重，使得上方行高低，下方行高高
      rowHeightWeights.add(pow(1.5, i).toDouble());
    }

    // 計算權重總和
    final double totalWeight = rowHeightWeights.reduce((a, b) => a + b);

    // 定義Y座標的有效顯示範圍
    final double yStart = canvasHalfSize / 3; // 起始位置提高
    final double yEnd = canvasHalfSize + 30; // 底部位置降低
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

    // 將倒數第二行下移5個像素
    _rowStartY[3] += 5;

    // 從上到下生成每一行的格子位置
    for (int rowIndex = 0; rowIndex < _rowGrids.length; rowIndex++) {
      final int gridsInRow = _rowGrids[rowIndex];

      // 計算行的Y坐標（從上往下）
      final double rowY = _rowStartY[rowIndex] + _rowHeights[rowIndex] / 2;

      // 計算每個格子的寬度
      final double gridWidth = (canvasHalfSize * 2) / gridsInRow;

      // 在這一行中生成每個格子的位置
      for (int colIndex = 0; colIndex < gridsInRow; colIndex++) {
        // 計算格子的X坐標
        final double gridX =
            -canvasHalfSize - 30 + (gridWidth + 10) * (colIndex + 0.5);

        // 添加格子位置
        gridPositions.add(Offset(gridX, rowY));
      }
    }

    // 打亂格子位置順序，以便隨機分配
    gridPositions.shuffle(random);

    // 確保我們不會生成超過格子數量的人物
    final actualFigureCount = math.min(_virtualFigureCount, totalGrids);

    for (int i = 0; i < actualFigureCount; i++) {
      // 起始位置在底部之外，以容器中心為基準設定一個較對稱的起始位置
      double startX = random.nextDouble() * 300 - 150; // -150 到 150
      double startY = canvasHalfSize + random.nextDouble() * 100; // 底部進入
      _figureInitialPositions.add(Offset(startX, startY));

      // 將人物分配到一個格子位置，加上一些隨機偏移
      Offset gridPos = gridPositions[i];

      // 更小的隨機偏移，使排列更整齊
      double offsetX = random.nextDouble() * 3 - 1.5; // 小幅度隨機偏移
      double offsetY = random.nextDouble() * 3 - 1.5;

      // 決定這個人物是否應該有出血效果（僅第一行和最後一行的邊緣格子）
      bool shouldBleed = false;
      double finalX = gridPos.dx + offsetX;
      double finalY = gridPos.dy + offsetY;

      // 確保Y座標在有效範圍內
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
            image: AssetImage('assets/images/background/bg2.png'),
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
                  padding: EdgeInsets.only(bottom: 70.h), // 調整底部間距為頁面指示器留出空間
                  child: ImageButton(
                    imagePath: 'assets/images/ui/button/red_m.png',
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
            image: AssetImage('assets/images/background/bg3.png'),
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
      // 根據finalY決定人物大小和層次 - Y值越大表示越"靠前"
      final finalPos = _figureFinalPositions[i];

      // 計算到中心的距離，用於決定大小和深度
      final distanceFromCenter = math.sqrt(
        finalPos.dx * finalPos.dx + finalPos.dy * finalPos.dy,
      );

      // 調整深度計算，讓Y值更大的人物（底部）更大
      double depthFactor;
      // 根據Y位置創建平滑漸變效果，範圍大約是 -150 到 150
      // 將Y值歸一化到0-1範圍，然後計算大小係數
      double normalizedY = (finalPos.dy + 150) / 300; // 將 -150 到 150 歸一化到 0-1

      // 使用更溫和的二次曲線，減小上下層差異
      // 基礎大小範圍：頂部0.7，底部1.4 (降低最大值防止過大)
      double baseSize = 0.7 + (normalizedY * normalizedY);

      // 適當增加距離中心的縮小效果
      double distanceFactor = (distanceFromCenter / 350).clamp(0.0, 0.25);

      depthFactor = baseSize - distanceFactor;

      // 確保最小值和最大值在合理範圍
      depthFactor = depthFactor.clamp(0.6, 2);

      // 計算動畫延遲 - 根據行數計算，讓越靠近底部的行越先出現
      double baseDelay = (finalPos.dy + 150) / 300 * 0.4; // 將Y值範圍轉換為0-0.4的延遲範圍
      double randomOffset = (i % 5) * 0.02; // 增加一些隨機性
      double delayTime = (baseDelay + randomOffset).clamp(0.0, 0.5);

      // 確定人物所在行
      int personRow = -1;
      for (int rowIndex = 0; rowIndex < _rowGrids.length; rowIndex++) {
        if (rowIndex == 0 && finalPos.dy <= _rowStartY[0] + _rowHeights[0]) {
          personRow = 0;
          break;
        } else if (rowIndex > 0 &&
            finalPos.dy >
                _rowStartY[rowIndex - 1] + _rowHeights[rowIndex - 1] &&
            finalPos.dy <= _rowStartY[rowIndex] + _rowHeights[rowIndex]) {
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
      double baseOpacity = finalPos.dy < -50 ? 0.7 : 1.0;

      characterData.add({
        'index': i,
        'path': _figuresPaths[figureIndex], // 確保索引不會超出範圍
        'initialPos': _figureInitialPositions[i],
        'finalPos': finalPos,
        'depth': depthFactor,
        'delay': delayTime,
        'distance': distanceFromCenter,
        'yPos': finalPos.dy, // 記錄Y座標，用於Z軸排序
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

      // 計算當前位置
      final currentPos = Offset.lerp(data['initialPos'], data['finalPos'], t)!;

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

      // 計算尺寸 - 讓大小變化更合理
      final baseSize = size * 0.21; // 縮小基礎大小
      final imageSize = baseSize * data['depth'];

      // 定位人物，根據排序後的位置
      return Positioned(
        left: currentPos.dx + size / 2 - (imageSize / 2),
        top: currentPos.dy + size / 2 - (imageSize / 2),
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

    // 預先加載所有食物圖片以獲取其尺寸，用於正規化
    final assetBundle = DefaultAssetBundle.of(context);

    for (int index = 0; index < math.min(16, _dishPaths.length); index++) {
      String dishPath = _dishPaths[index];
      final random = math.Random(index + 100);

      // 計算網格位置
      final gridSize = 4; // 4x4網格
      final cellSize = size / gridSize;
      final row = index ~/ gridSize; // 0, 1, 2, 3
      final col = index % gridSize; // 0, 1, 2, 3

      // 計算網格中心坐標，加入小幅隨機偏移
      final offsetX = random.nextDouble() * 15 - 7.5;
      final offsetY = random.nextDouble() * 15 - 7.5;

      // 計算相對於中心的坐標
      final halfGrid = (gridSize - 1) / 2;
      final relativeX = (col - halfGrid) * cellSize + offsetX;
      final relativeY = (row - halfGrid) * (cellSize - 8) + offsetY;

      // 起始位置設置在四個方向之外
      double startX, startY;
      int direction = index % 4; // 0:上, 1:右, 2:下, 3:左
      switch (direction) {
        case 0: // 上方
          startX = relativeX * 0.5;
          startY = -size / 2 - 50;
          break;
        case 1: // 右方
          startX = size / 2 + 50;
          startY = relativeY * 0.5;
          break;
        case 2: // 下方
          startX = relativeX * 0.5;
          startY = size / 2 + 50;
          break;
        case 3: // 左方
        default:
          startX = -size / 2 - 50;
          startY = relativeY * 0.5;
          break;
      }

      // 隨機分配Z軸位置 (用於決定渲染順序和大小)
      final zPosition = random.nextDouble();

      // 添加到數據集合
      foodData.add({
        'index': index,
        'path': dishPath,
        'startPos': Offset(startX, startY),
        'finalPos': Offset(relativeX, relativeY),
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

        // 計算當前位置
        final currentPos =
            Offset.lerp(
              data['startPos'] as Offset,
              data['finalPos'] as Offset,
              t,
            )!;

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
        final zSizeFactor = 0.8 + zPosition * 0.4; // 調小範圍，避免過大 (0.8-1.2)

        // 根據Z位置調整基礎大小，前方食物略小一些以避免被截斷
        final baseSizeMultiplier =
            zPosition > 0.7 ? 1.0 : (1.0 + (index % 4) * 0.05);
        final sizeMultiplier = baseSizeMultiplier * zSizeFactor;

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
        final shadowOffset = 5.0;
        final shadowOpacity = 0.4 + (zPosition * 0.1); // 前面的食物陰影更明顯

        // 基於Z位置調整食物位置，避免前方食物被截斷
        final centeringOffset = zPosition > 0.7 ? size * 0.02 : 0.0;

        // 調整的基礎尺寸，較大範圍確保不被截斷
        final baseSize = size * 0.3;
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
