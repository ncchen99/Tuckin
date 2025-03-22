import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tuckin/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 導入頁面
import 'screens/welcome_screen.dart';
import 'screens/login_page.dart';
import 'screens/profile_setup_page.dart';
import 'screens/food_preference_page.dart';
import 'screens/personality_test_page.dart';
import 'screens/home_page.dart';

import 'utils/index.dart'; // 導入工具類

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
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginPage(),
        '/profile_setup': (context) => const ProfileSetupPage(),
        '/food_preference': (context) => const FoodPreferencePage(),
        '/personality_test': (context) => const PersonalityTestPage(),
        '/home': (context) => const HomePage(),
      },
      debugShowCheckedModeBanner: false, // 移除調試標記
    );
  }
}
