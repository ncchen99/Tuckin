import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:tuckin/services/database_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tuckin/utils/route_observer.dart'; // 導入路由觀察器
import 'package:tuckin/utils/route_transitions.dart'; // 導入路由轉場效果

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
// TODO: 導入其他頁面，包括出席確認頁面、餐廳選擇頁面、晚餐資訊頁面和評分頁面

import 'utils/index.dart'; // 導入工具類

// 創建路由觀察器實例
final TuckinRouteObserver routeObserver = TuckinRouteObserver();

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 獲取認證和資料庫服務實例
    final authService = AuthService();
    final databaseService = DatabaseService();

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
          child: child!,
        );
      },
      // 添加路由觀察器
      navigatorObservers: [routeObserver],
      initialRoute: '/',
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

        // TODO: 添加以下頁面的路由
        // '/attendance_confirmation': (context) => const AttendanceConfirmationPage(),
        // '/restaurant_selection': (context) => const RestaurantSelectionPage(),
        // '/dinner_info': (context) => const DinnerInfoPage(),
        // '/dinner_rating': (context) => const DinnerRatingPage(),

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
            // TODO: 返回帶有ID參數的晚餐資訊頁面
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
