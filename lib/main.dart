import 'package:flutter/material.dart';
import 'package:stroke_text/stroke_text.dart';

void main() {
  runApp(const MyApp());
}

class ImageButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String text;
  final String imagePath;
  final double width;
  final double height;
  final TextStyle textStyle;

  const ImageButton({
    Key? key,
    required this.onPressed,
    required this.text,
    required this.imagePath,
    this.width = 200,
    this.height = 100,
    this.textStyle = const TextStyle(
      fontSize: 24,
      color: Colors.white,
      fontFamily: 'OtsutomeFont',
      fontWeight: FontWeight.bold,
    ),
  }) : super(key: key);

  @override
  _ImageButtonState createState() => _ImageButtonState();
}

class _ImageButtonState extends State<ImageButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        height: widget.height,
        child: Stack(
          children: [
            // 底部陰影圖片 - 使用相同的圖片但僅向下偏移
            if (!_isPressed)
              Positioned(
                left: 0,
                top: 5,
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(color: Colors.transparent),
                  child: Image.asset(
                    widget.imagePath,
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.contain,
                    color: Colors.black.withOpacity(0.4),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),

            // 按鈕主圖層
            Transform.translate(
              offset: _isPressed ? const Offset(0, 6) : Offset.zero,
              child: Container(
                decoration: const BoxDecoration(color: Colors.transparent),
                child: Image.asset(
                  widget.imagePath,
                  width: widget.width,
                  height: widget.height,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // 按鈕文字 - 使用 StrokeText 組件
            Positioned.fill(
              child: Center(
                child: Transform.translate(
                  offset: _isPressed ? const Offset(0, 6) : Offset.zero,
                  child: StrokeText(
                    text: widget.text,
                    textStyle: widget.textStyle.copyWith(letterSpacing: 1.0),
                    strokeColor: Colors.black,
                    strokeWidth: 4,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: '圖片按鈕示範'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey.shade200],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('點擊按鈕來增加計數：'),
              const SizedBox(height: 30),
              ImageButton(
                imagePath: 'assets/images/ui/button/red_l.png',
                text: '開始',
                width: 150,
                height: 90,
                onPressed: _incrementCounter,
              ),
              const SizedBox(height: 30),
              const Text('圖片按鈕具有陰影和點擊壓扁效果'),
            ],
          ),
        ),
      ),
    );
  }
}
