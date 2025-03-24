import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tuckin/utils/route_observer.dart'; // 導入路由觀察器
import 'package:tuckin/utils/route_transitions.dart'; // 導入路由轉場效果
import 'package:tuckin/components/components.dart'; // 導入共用組件
import 'package:connectivity_plus/connectivity_plus.dart'; // 導入網絡狀態檢測

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

// 全局變數，存儲初始路由
String initialRoute = '/';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 設置固定方向，防止方向改變導致佈局變化
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    // 加載環境變數
    await dotenv.load(fileName: '.env');
    debugPrint('環境變數加載成功。變數數量: ${dotenv.env.length}');
  } catch (e) {
    debugPrint('環境變數加載錯誤: $e');
  }

  // 初始化 AuthService
  try {
    await AuthService().initialize();
  } catch (e) {
    debugPrint('AuthService 初始化錯誤: $e');
  }

  // 檢查用戶登入狀態和用戶狀態
  final authService = AuthService();
  final databaseService = DatabaseService();

  if (authService.isLoggedIn()) {
    final currentUser = authService.getCurrentUser();
    if (currentUser != null) {
      try {
        final userStatus = await databaseService.getUserStatus(currentUser.id);

        // 調試輸出
        debugPrint('當前用戶狀態: $userStatus');
        debugPrint('當前用戶ID: ${currentUser.id}');
        debugPrint('當前用戶郵箱: ${currentUser.email}');

        // 如果狀態不是 initial，直接導航到主頁
        if (userStatus != 'initial') {
          initialRoute = '/home';
          debugPrint('設置初始路由為: $initialRoute');
        } else {
          debugPrint('用戶狀態為initial，保持初始路由: $initialRoute');
        }
      } catch (e) {
        debugPrint('檢查用戶狀態出錯: $e');
      }
    } else {
      debugPrint('用戶已登入但無法獲取用戶資訊');
    }
  } else {
    debugPrint('用戶未登入，使用默認初始路由: $initialRoute');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isOffline = false;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final isOffline =
          !results.contains(ConnectivityResult.wifi) &&
          !results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.ethernet);
      setState(() {
        _isOffline = isOffline;
      });
      debugPrint('初始網絡狀態: ${_isOffline ? '離線' : '在線'}, 結果: $results');
    } catch (e) {
      debugPrint('檢查網絡連接錯誤: $e');
    }
  }

  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (mounted) {
        final isOffline =
            !results.contains(ConnectivityResult.wifi) &&
            !results.contains(ConnectivityResult.mobile) &&
            !results.contains(ConnectivityResult.ethernet);
        setState(() {
          _isOffline = isOffline;
        });
        debugPrint('網絡狀態變更: ${_isOffline ? '離線' : '在線'}, 結果: $results');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tuckin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      // 添加 builder 忽略系統文字縮放設置
      builder: (context, child) {
        // 初始化 SizeConfig
        sizeConfig.init(context);

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0), // 固定文字縮放比例
            devicePixelRatio: 1.0, // 可選：統一像素比例
          ),
          // 顯示離線狀態或正常內容
          child: Stack(
            children: [
              SplashScreen(child: child!),
              if (_isOffline)
                Positioned(
                  bottom:
                      MediaQuery.of(context).padding.bottom, // 放在底部，避開底部安全區域
                  left: 0,
                  right: 0,
                  child: Material(
                    elevation: 4,
                    color: const Color(0xFFB33D1C), // 使用主題橘色 #B33D1C
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.signal_wifi_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '網路不給力',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      // 添加路由觀察器
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
      // 處理未命名路由的情況
      onGenerateRoute: (settings) {
        // 這裡可以處理動態路由，例如帶參數的路由
        debugPrint('正在產生路由: ${settings.name}');

        // 例如: /dinner_info/123 可以解析為晚餐ID為123的晚餐資訊頁面
        final uri = Uri.parse(settings.name ?? '/');

        // 處理動態路由邏輯
        if (uri.pathSegments.length >= 2) {
          if (uri.pathSegments[0] == 'dinner_info') {
            final id = uri.pathSegments[1];
            // 返回帶有ID參數的晚餐資訊頁面
            // return MaterialPageRoute(
            //   builder: (context) => DinnerInfoPage(dinnerId: id),
            // );
          }
        }

        // 如果沒有匹配的路由，返回錯誤頁面或主頁
        return MaterialPageRoute(
          builder:
              (context) =>
                  const Scaffold(body: Center(child: Text('404 - 頁面不存在'))),
        );
      },
      debugShowCheckedModeBanner: false, // 移除調試標記
    );
  }
}
