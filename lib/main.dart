import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/welcome_screen.dart';
import 'utils/index.dart'; // 導入工具類

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 設置固定方向，防止方向改變導致佈局變化
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false, // 移除調試標記
    );
  }
}
