import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tuckin/utils/route_observer.dart'; // 導入路由觀察器
import 'package:tuckin/components/components.dart'; // 導入共用組件
import 'package:connectivity_plus/connectivity_plus.dart'; // 導入網絡狀態檢測
import 'package:tuckin/components/common/error_screen.dart'; // 導入錯誤畫面組件
import 'package:tuckin/services/error_handler.dart';
import 'package:tuckin/services/api_service.dart'; // 添加導入 API 服務
import 'package:flutter_native_splash/flutter_native_splash.dart'; // 導入原生啟動畫面
// 添加導入通知服務
import 'package:tuckin/services/notification_service.dart';

// 導入頁面
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/login_page.dart';
import 'screens/onboarding/profile_setup_page.dart';
import 'screens/onboarding/food_preference_page.dart';
import 'screens/onboarding/personality_test_page.dart';
import 'screens/home_page.dart';
// 導入晚餐相關頁面
import 'screens/dinner/dinner_reservation_page.dart';
import 'screens/dinner/matching_status_page.dart';
import 'screens/dinner/attendance_confirmation_page.dart';
import 'screens/dinner/restaurant_selection_page.dart';
import 'screens/dinner/dinner_info_page.dart';
import 'screens/dinner/rating_page.dart';

import 'utils/index.dart'; // 導入工具類

// 創建路由觀察器實例
final TuckinRouteObserver routeObserver = TuckinRouteObserver();

// 創建全局導航鍵，用於通知點擊時導航
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 全局變數，存儲初始路由
String initialRoute = '/';

void main() async {
  // 保留原生啟動畫面直到 Flutter 完全初始化
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 設置固定方向，防止方向改變導致佈局變化
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 這個標誌用於追蹤初始化是否成功
  bool initSuccess = false;

  // 創建 ErrorHandler 實例
  final errorHandler = ErrorHandler();

  try {
    // 加載環境變數
    await dotenv.load(fileName: '.env');
    debugPrint('環境變數加載成功。變數數量: ${dotenv.env.length}');
    initSuccess = true;
  } catch (e) {
    debugPrint('環境變數加載錯誤: $e');
    // 繼續執行，但使用默認值
  }

  // 初始化 AuthService
  try {
    await AuthService().initialize();
  } catch (e) {
    debugPrint('AuthService 初始化錯誤: $e');

    // 使用 ErrorHandler 顯示錯誤訊息
    if (e is ApiError) {
      errorHandler.handleApiError(e, () async {
        try {
          await AuthService().initialize();
        } catch (retryError) {
          debugPrint('重試初始化 AuthService 錯誤: $retryError');
        }
      });
    } else {
      errorHandler.showError(
        message: '網絡連接錯誤，請檢查您的網絡設置',
        isServerError: false,
        onRetry: () async {
          try {
            await AuthService().initialize();
          } catch (retryError) {
            debugPrint('重試初始化 AuthService 錯誤: $retryError');
          }
        },
      );
    }

    // 嘗試強制登出以重置狀態
    try {
      await AuthService().signOut();
    } catch (signOutError) {
      debugPrint('強制登出錯誤: $signOutError');
    }
  }

  // 只有在前面步驟成功的情況下才嘗試確定初始路由
  if (initSuccess) {
    try {
      // 使用全局變量，而不是重新宣告
      initialRoute = await NavigationService().determineInitialRoute();
      debugPrint('設置初始路由為: $initialRoute');

      // 初始化通知服務
      try {
        await NotificationService().initialize(navigatorKey);
        debugPrint('通知服務初始化成功');
      } catch (e) {
        debugPrint('通知服務初始化錯誤: $e');
        // 通知服務初始化失敗不阻止應用程序啟動
      }
    } catch (e) {
      debugPrint('確定初始路由出錯: $e');
      // 出錯時使用默認初始路由，但不重新宣告變量
      initialRoute = '/';
    }
  } else {
    debugPrint('初始化未成功，使用默認路由: /');
    initialRoute = '/';
  }

  runApp(MyApp(errorHandler: errorHandler));

  // 移除原生啟動畫面
  FlutterNativeSplash.remove();
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

  @override
  void initState() {
    super.initState();
    _errorHandler = widget.errorHandler;
    _checkConnectivity();
    _setupConnectivityListener();
    _setupErrorListener();
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _errorHandler.dispose();
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

  @override
  Widget build(BuildContext context) {
    debugPrint('MyApp: 構建主應用，初始路由為: $initialRoute');

    return ErrorHandlerProvider(
      errorHandler: _errorHandler,
      child: MaterialApp(
        navigatorKey: navigatorKey, // 添加全局導航鍵
        title: 'Tuckin',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
                SplashScreen(
                  child: child ?? const SizedBox(),
                  statusCheckDelay: 300,
                ),
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
                      onRetry: () async {
                        if (_isOffline) {
                          await _checkConnectivity();
                          if (!_isOffline) {
                            // 避免使用 Navigator，而是通過狀態更新來隱藏錯誤畫面
                            setState(() {});
                          }
                        } else {
                          _errorHandler.clearError();
                          // 避免使用 Navigator，而是通過狀態更新來隱藏錯誤畫面
                          setState(() {});
                        }
                      },
                      isServerError: false,
                      showButton: !_isOffline, // 離線狀態下不顯示按鈕
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
          '/profile_setup': (context) => const ProfileSetupPage(),
          '/food_preference': (context) => const FoodPreferencePage(),
          '/personality_test': (context) => const PersonalityTestPage(),

          // 主流程頁面
          '/home': (context) => const HomePage(),
          '/dinner_reservation': (context) => const DinnerReservationPage(),
          '/matching_status': (context) => const MatchingStatusPage(),
          '/attendance_confirmation':
              (context) => const AttendanceConfirmationPage(),
          '/restaurant_selection': (context) => const RestaurantSelectionPage(),
          '/dinner_info': (context) => const DinnerInfoPage(),
          '/dinner_rating': (context) => const RatingPage(),

          // 輔助頁面路由
          // '/notifications': (context) => const NotificationsPage(),
          // '/user_settings': (context) => const UserSettingsPage(),
          // '/user_profile': (context) => const UserProfilePage(),
          // '/help_faq': (context) => const HelpFaqPage(),
        },
        onGenerateRoute: (settings) {
          debugPrint('正在產生路由: ${settings.name}');

          final uri = Uri.parse(settings.name ?? '/');

          if (uri.pathSegments.length >= 2) {
            if (uri.pathSegments[0] == 'dinner_info') {
              final id = uri.pathSegments[1];
              // 返回帶有ID參數的晚餐資訊頁面
              // return MaterialPageRoute(
              //   builder: (context) => DinnerInfoPage(dinnerId: id),
              // );
            }
          }

          return MaterialPageRoute(
            builder:
                (context) =>
                    const Scaffold(body: Center(child: Text('404 - 頁面不存在'))),
          );
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
