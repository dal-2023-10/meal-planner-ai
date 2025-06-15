import 'package:flutter/material.dart';
import 'dart:async';

class LoadingPage extends StatefulWidget {
  final Future<dynamic> Function() onProcess;
  final void Function(dynamic result) onComplete;

  const LoadingPage({super.key, required this.onProcess, required this.onComplete});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  int _frame = 0;
  late Timer _timer;

  // シンプルな2フレームドット絵
  final List<String> chefFrames = [
  '''
  (｀･ω･)っ🍳🔥
  ''',
  '''
  (｀･ω･)つ🍳🔥
  ''',
  '''
  (｀･ω･)っ🍳🔥
  ''',
  '''
  (｀･ω･)つ🍳🔥
  ''',
  '''
  (｀･ω･)っ🍳🔥
  ''',
  '''
  (｀･ω･)つ🍳🔥
  ''',
  '''
  (｀･ω･)っ🍳🔥
  ''',
  '''
  (｀･ω･)つ🍳🔥
  ''',
  '''
  (｀･ω･)っ🍳🔥
  ''',
  '''
  (｀･ω･)つ🍳🔥
  ''',
  '''
  ヽ(･∀･)ﾉ🍳✨
  ''',
  '''
  ヽ(･∀･)ﾉ🍳✨
  '''
  ];

  @override
  void initState() {
    super.initState();

    // アニメーション
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      setState(() {
        _frame = (_frame + 1) % chefFrames.length;
      });
    });

    // 非同期処理開始
    widget.onProcess().then((result) {
      _timer.cancel();
      widget.onComplete(result);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              chefFrames[_frame],
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 32,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "調理中・・・",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
