import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuckin/services/services.dart'; // 統一導入所有服務
import 'package:tuckin/utils/route_observer.dart'; // 導入路由觀察器
import 'package:tuckin/components/components.dart'; // 導入共用組件
import 'package:connectivity_plus/connectivity_plus.dart'; // 導入網絡狀態檢測
import 'package:tuckin/components/common/error_screen.dart'; // 導入錯誤畫面組件
import 'package:flutter_native_splash/flutter_native_splash.dart'; // 導入原生啟動畫面
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; // 導入 Provider 套件

// 導入頁面
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/login_page.dart';
import 'screens/onboarding/profile_setup_page.dart';
import 'screens/onboarding/food_preference_page.dart';
import 'screens/onboarding/personality_test_page.dart';
import 'screens/home_page.dart';
// 導入晚餐相關頁面
import 'screens/dinner/dinner_reservation_page.dart';
import 'screens/status/matching_status_page.dart';
import 'screens/dinner/attendance_confirmation_page.dart';
import 'screens/restaurant/restaurant_selection_page.dart';
import 'screens/restaurant/restaurant_reservation_page.dart';
import 'screens/dinner/dinner_info_page.dart';
import 'screens/dinner/dinner_info_waiting_page.dart';
import 'screens/dinner/rating_page.dart';
// 導入個人資料頁面
import 'screens/profile/profile_page.dart';
// 導入新增狀態頁面
import 'screens/status/confirmation_timeout_page.dart';
import 'screens/status/low_attendance_page.dart';
// 導入聊天頁面
import 'screens/chat/chat_page.dart';

import 'utils/index.dart'; // 導入工具類

// 創建路由觀察器實例
final TuckinRouteObserver routeObserver = TuckinRouteObserver();

// 創建全局導航鍵，用於通知點擊時導航
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 全局變數，存儲初始路由
String initialRoute = '/';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 初始化時區
  await AppInitializerService().initializeTimeZone();

  // 一開始先顯示 LoadingScreen，包裹在 MaterialApp 中確保有正確的 Directionality
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoadingScreen(
        status: '',
        statusTextStyle: TextStyle(
          fontSize: 12,
          color: const Color(0xFF23456B),
          fontFamily: 'OtsutomeFont',
          fontWeight: FontWeight.bold,
        ),
        displayDuration: 500, // 延長顯示時間為 0.5 秒
        onLoadingComplete: () async {
          // 在 LoadingScreen 顯示時，進行所有初始化操作
          await _initializeApp();
        },
      ),
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
    ),
  );

  // 立即移除原生啟動畫面，這樣就能看到 LoadingScreen
  FlutterNativeSplash.remove();

  // 設置固定方向
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
}

// 將應用初始化邏輯提取到單獨函數中
Future<void> _initializeApp() async {
  final errorHandler = ErrorHandler();
  final appInitializer = AppInitializerService();

  // 執行完整初始化流程
  initialRoute = await appInitializer.performFullInitialization(
    errorHandler: errorHandler,
    navigatorKey: navigatorKey,
    onNetworkError: () async {
      // 網絡重試邏輯
      debugPrint('用戶點擊重試按鈕，重新測試網絡連接...');
      bool retryNetworkConnected = await appInitializer.testNetworkConnection();
      if (retryNetworkConnected) {
        debugPrint('網絡連接已恢復，繼續應用流程');

        // 確保 Firebase 已初始化
        try {
          await Firebase.initializeApp();
          debugPrint('Firebase 重新初始化成功');
        } catch (e) {
          debugPrint('Firebase 重新初始化錯誤（可能已經初始化）: $e');
        }

        errorHandler.clearError();
        bool servicesInitialized = await appInitializer.initializeServices(
          errorHandler,
          navigatorKey,
        );
        if (servicesInitialized) {
          initialRoute = await appInitializer.determineInitialRoute();
          await appInitializer.initializeNotificationService(navigatorKey);
          runApp(MyApp(errorHandler: errorHandler));
        }
      } else {
        debugPrint('網絡連接仍然不可用');
      }
    },
  );

  debugPrint('所有初始化完成，開始運行主應用 - 初始路由為: $initialRoute');

  // 運行主應用
  runApp(MyApp(errorHandler: errorHandler));

  // 在背景執行系統檢查（不阻塞主流程）
  SystemCheckHandler().performSystemCheckInBackground(
    navigatorKey: navigatorKey,
    initialRoute: initialRoute,
  );
}

class MyApp extends StatefulWidget {
  final ErrorHandler errorHandler;

  const MyApp({super.key, required this.errorHandler});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isOffline = false;
  final Connectivity _connectivity = Connectivity();
  late final ErrorHandler _errorHandler;
  StreamSubscription<bool>? _errorSubscription;
  // 添加狀態標記，表示正在測試網絡
  bool _isTestingNetwork = false;
  // 添加標記，表示是否是首次構建
  bool _isFirstBuild = true;

  // 生命週期觀察者
  final _lifecycleHandler = LifecycleHandler();

  @override
  void initState() {
    super.initState();
    _errorHandler = widget.errorHandler;
    _checkConnectivity();
    _setupConnectivityListener();
    _setupErrorListener();

    // 添加生命週期監聽，在應用程式恢復前台時清除通知
    WidgetsBinding.instance.addObserver(_lifecycleHandler);

    // 在應用啟動時清除通知
    _clearNotificationsOnLaunch();
  }

  // 清除啟動時的通知並處理待處理的聊天導航
  Future<void> _clearNotificationsOnLaunch() async {
    try {
      await NotificationService().clearDisplayedNotifications();
    } catch (e) {
      debugPrint('清除啟動時通知錯誤: $e');
    }

    // 延遲檢查待處理的聊天導航（確保 Navigator 已經準備好）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingChatNavigation();
    });
  }

  // 檢查並處理待處理的聊天導航
  void _checkPendingChatNavigation() {
    final pendingChatId = NotificationService().consumePendingChatNavigation();
    if (pendingChatId != null) {
      debugPrint('處理待處理的聊天導航: $pendingChatId');

      // 確保 Navigator 已經準備好
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushNamed(
          '/chat',
          arguments: {'diningEventId': pendingChatId},
        );
      } else {
        debugPrint('Navigator 尚未準備好，稍後重試');
        // 如果 Navigator 還沒準備好，稍後重試
        Future.delayed(const Duration(milliseconds: 500), () {
          _checkPendingChatNavigation();
        });
      }
    }
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _errorHandler.dispose();
    // 在應用關閉時銷毀 RealtimeService
    RealtimeService().dispose();

    // 移除生命週期觀察者
    WidgetsBinding.instance.removeObserver(_lifecycleHandler);

    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final isOffline =
          !results.contains(ConnectivityResult.wifi) &&
          !results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.ethernet);

      // 如果連接測試顯示我們已連接，再次進行超時測試
      if (!isOffline) {
        final bool connectionWorks = await _testRealConnection();

        setState(() {
          _isOffline = !connectionWorks;
        });
        debugPrint('網絡連通性測試結果: ${connectionWorks ? '連接成功' : '連接失敗'}');
      } else {
        setState(() {
          _isOffline = isOffline;
        });
      }

      debugPrint('初始網絡狀態: ${_isOffline ? '離線' : '在線'}, 結果: $results');
    } catch (e) {
      debugPrint('檢查網絡連接錯誤: $e');
      setState(() {
        _isOffline = true; // 發生錯誤時，假設離線
      });
    }
  }

  // 測試實際網絡連接
  Future<bool> _testRealConnection() async {
    try {
      // 使用 ApiService 嘗試簡單請求，測試實際連接
      await ApiService().handleRequest(
        request: () async {
          // 這裡僅用於測試連接，可以替換為實際的簡單API調用
          await Future.delayed(const Duration(seconds: 2));
          return true;
        },
        timeout: const Duration(seconds: 5),
      );
      return true;
    } catch (e) {
      debugPrint('實際連接測試失敗: $e');
      return false;
    }
  }

  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      if (mounted) {
        final isOffline =
            !results.contains(ConnectivityResult.wifi) &&
            !results.contains(ConnectivityResult.mobile) &&
            !results.contains(ConnectivityResult.ethernet);

        if (!isOffline) {
          // 進行實際連接測試
          final bool connectionWorks = await _testRealConnection();
          if (mounted) {
            // 如果之前是離線狀態，現在恢復了，則更新UI
            bool wasOffline = _isOffline;
            setState(() {
              _isOffline = !connectionWorks;
            });

            // 如果網絡已恢復，則嘗試重新初始化需要的服務
            if (wasOffline && !_isOffline) {
              debugPrint('網絡已恢復，嘗試重新初始化服務');
              try {
                // 這裡可以放置重新初始化代碼，例如重新初始化 AuthService
                // await AuthService().initialize();
              } catch (e) {
                debugPrint('網絡恢復後重新初始化服務失敗: $e');
              }
            }
          }
          debugPrint('網絡狀態變更後的連通性測試: ${connectionWorks ? '連接成功' : '連接失敗'}');
        } else {
          if (mounted) {
            setState(() {
              _isOffline = isOffline;
            });
          }
        }

        debugPrint('網絡狀態變更: ${_isOffline ? '離線' : '在線'}, 結果: $results');
      }
    });
  }

  void _setupErrorListener() {
    _errorSubscription = _errorHandler.errorStream.listen((hasError) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // 測試網絡連接並處理UI更新
  Future<void> _handleNetworkRetry(BuildContext context) async {
    // 防止重複點擊
    if (_isTestingNetwork) {
      debugPrint('正在測試網絡中，忽略重複點擊');
      return;
    }

    setState(() {
      _isTestingNetwork = true;
    });

    final appInitializer = AppInitializerService();

    try {
      // 顯示測試中提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在測試網絡連接...'),
          duration: Duration(seconds: 1),
        ),
      );

      debugPrint('嘗試重新測試網絡連接...');
      bool networkConnected = await appInitializer.testNetworkConnection();
      debugPrint('網絡重新測試結果: ${networkConnected ? '成功' : '失敗'}');

      if (!networkConnected) {
        // 網絡仍然不可用
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('網絡仍然不可用，請檢查您的網絡設置'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _isTestingNetwork = false;
        });
        return;
      }

      // 再進行實際連接測試
      debugPrint('進行實際連接測試...');
      bool realConnectionWorks = await _testRealConnection();
      debugPrint('實際網絡測試結果: ${realConnectionWorks ? '成功' : '失敗'}');

      if (!realConnectionWorks) {
        // 網絡測試通過但實際連接測試失敗
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('網絡連接不穩定，請稍後再試'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _isTestingNetwork = false;
        });
        return;
      }

      // 網絡恢復，確保 Firebase 已初始化，然後初始化服務
      debugPrint('確保 Firebase 已初始化...');
      try {
        await Firebase.initializeApp();
        debugPrint('Firebase 重新初始化成功');
      } catch (e) {
        debugPrint('Firebase 重新初始化錯誤（可能已經初始化）: $e');
      }

      debugPrint('開始初始化服務...');
      try {
        bool success = await appInitializer.initializeServices(
          _errorHandler,
          navigatorKey,
        );

        if (success) {
          // 只有在服務初始化成功時才更新UI
          debugPrint('服務初始化成功，更新UI狀態');

          if (_errorHandler.hasError) {
            _errorHandler.clearError();
          }

          setState(() {
            _isOffline = false;
            _isTestingNetwork = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('網絡已恢復連接'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          debugPrint('服務初始化返回失敗');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('服務初始化失敗，請稍後再試'),
              duration: Duration(seconds: 2),
            ),
          );
          setState(() {
            _isTestingNetwork = false;
          });
        }
      } catch (e) {
        debugPrint('服務初始化出現異常: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('初始化服務時出錯: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          _isTestingNetwork = false;
        });
      }
    } catch (e) {
      debugPrint('網絡測試過程中出現異常: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('測試網絡時發生錯誤: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        _isTestingNetwork = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFirstBuild) {
      debugPrint('MyApp.build: 首次構建，使用已設置的初始路由: $initialRoute');
      _isFirstBuild = false;
    } else {
      debugPrint('MyApp.build: 非首次構建，保持當前狀態');
    }

    debugPrint('MyApp.build: 構建主應用，全局初始路由為: $initialRoute');
    debugPrint(
      'MyApp.build: 是否為離線狀態: $_isOffline, 是否有錯誤: ${_errorHandler.hasError}',
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final service = UserStatusService();
            // 在服務創建後，延遲檢查數據完整性
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                // 等待服務初始化完成
                while (!service.isInitialized) {
                  await Future.delayed(const Duration(milliseconds: 50));
                }
                // 執行數據完整性檢查和修復
                await service.checkAndRepairDinnerTimeData();
              } catch (e) {
                debugPrint('UserStatusService 數據完整性檢查失敗: $e');
              }
            });
            return service;
          },
          lazy: false, // 立即創建，不等到第一次訪問時才創建
        ),
      ],
      child: ErrorHandlerProvider(
        errorHandler: _errorHandler,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Tuckin',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF23456B)),
            scaffoldBackgroundColor: Colors.transparent,
          ),
          builder: (context, child) {
            sizeConfig.init(context);

            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
                devicePixelRatio: 1.0,
              ),
              child: Stack(
                children: [
                  // 直接顯示 child，不再包 SplashScreen
                  child ?? const SizedBox(),
                  // 利用 Overlay 來顯示錯誤畫面，確保完全覆蓋
                  if (_isOffline ||
                      (_errorHandler.hasError && _errorHandler.isNetworkError))
                    ModalBarrier(
                      dismissible: false,
                      color: const Color.fromARGB(255, 222, 222, 222),
                    ),
                  if (_isOffline ||
                      (_errorHandler.hasError && _errorHandler.isNetworkError))
                    Material(
                      type: MaterialType.transparency,
                      child: ErrorScreen(
                        message:
                            _isOffline
                                ? '請檢查您的網路連線並重試'
                                : (_errorHandler.errorMessage ?? '網絡連接錯誤'),
                        onRetry: () {
                          // 使用新的處理函數處理網絡重試邏輯
                          _handleNetworkRetry(context);
                        },
                        isServerError: false,
                        showButton: false, // 不顯示按鈕
                      ),
                    ),
                  // 顯示其他錯誤
                  if (_errorHandler.hasError &&
                      !_errorHandler.isNetworkError &&
                      !_isOffline)
                    ModalBarrier(
                      dismissible: false,
                      color: const Color.fromARGB(255, 222, 222, 222),
                    ),
                  if (_errorHandler.hasError &&
                      !_errorHandler.isNetworkError &&
                      !_isOffline)
                    Material(
                      type: MaterialType.transparency,
                      child: ErrorScreen(
                        message: _errorHandler.errorMessage ?? '發生未知錯誤',
                        onRetry: () {
                          _errorHandler.clearError();
                          // 避免使用 Navigator，而是通過狀態更新來隱藏錯誤畫面
                          setState(() {});
                        },
                        isServerError: _errorHandler.isServerError,
                      ),
                    ),
                ],
              ),
            );
          },
          navigatorObservers: [routeObserver],
          initialRoute: initialRoute,
          routes: {
            // 初始頁面
            '/': (context) => const WelcomeScreen(),

            // 用戶引導頁面
            '/login': (context) => const LoginPage(),
            // '/profile_setup' 移至 onGenerateRoute 以支持參數傳遞
            '/food_preference': (context) => const FoodPreferencePage(),
            '/personality_test': (context) => const PersonalityTestPage(),

            // 主流程頁面
            '/home': (context) => const HomePage(),
            '/dinner_reservation': (context) => const DinnerReservationPage(),
            '/matching_status': (context) => const MatchingStatusPage(),
            '/attendance_confirmation':
                (context) => const AttendanceConfirmationPage(),
            '/restaurant_selection':
                (context) => const RestaurantSelectionPage(),
            '/restaurant_reservation':
                (context) => const RestaurantReservationPage(),
            '/dinner_info': (context) => const DinnerInfoPage(),
            '/dinner_info_waiting': (context) => const DinnerInfoWaitingPage(),
            '/dinner_rating': (context) => const RatingPage(),

            // 個人資料與設定頁面
            '/profile': (context) => const ProfilePage(),

            // 狀態提示頁面
            '/confirmation_timeout':
                (context) => const ConfirmationTimeoutPage(),
            '/low_attendance': (context) => const LowAttendancePage(),

            // 輔助頁面路由
            // '/notifications': (context) => const NotificationsPage(),
            // '/user_settings': (context) => const UserSettingsPage(),
            // '/user_profile': (context) => const UserProfilePage(),
            // '/help_faq': (context) => const HelpFaqPage(),
          },
          onGenerateRoute: (settings) {
            debugPrint('正在產生路由: ${settings.name}');

            // 處理 profile_setup 路由（帶參數）
            if (settings.name == '/profile_setup') {
              final args = settings.arguments as Map<String, dynamic>?;
              final isFromProfile = args?['isFromProfile'] as bool? ?? false;

              return MaterialPageRoute(
                builder:
                    (context) => ProfileSetupPage(isFromProfile: isFromProfile),
                settings: settings,
              );
            }

            // 處理聊天室路由（帶參數）
            if (settings.name == '/chat') {
              final args = settings.arguments as Map<String, dynamic>?;
              final diningEventId = args?['diningEventId'] as String?;

              if (diningEventId != null) {
                return MaterialPageRoute(
                  builder: (context) => ChatPage(diningEventId: diningEventId),
                  settings: settings,
                );
              }

              // 如果沒有 diningEventId，返回 404 頁面
              return MaterialPageRoute(
                builder:
                    (context) =>
                        const Scaffold(body: Center(child: Text('無效的聊天室參數'))),
              );
            }

            // 其他未定義的路由返回 404
            return MaterialPageRoute(
              builder:
                  (context) =>
                      const Scaffold(body: Center(child: Text('404 - 頁面不存在'))),
            );
          },
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
